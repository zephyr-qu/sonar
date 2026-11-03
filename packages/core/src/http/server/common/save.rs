use crate::crypto;
use bytes::Bytes;
use http_body_util::BodyExt;
use hyper::body::Incoming;
use hyper::Request;
use std::ffi::OsString;
use std::future::Future;
use std::path::{Path, PathBuf};
use tokio::sync::{mpsc, oneshot};

/// Channel capacity for file upload chunks (provides backpressure).
const UPLOAD_CHANNEL_CAPACITY: usize = 16;

/// Size of the write buffer that coalesces incoming body chunks (typically one
/// TLS record, ~16 KiB) into larger file writes.
const WRITE_BUFFER_SIZE: usize = 512 * 1024;

/// Where the content of an uploaded file should go, decided by the application.
#[derive(Debug)]
pub enum FileUploadTarget {
    /// The application consumes the binary chunks itself.
    ///
    /// The server forwards chunks into `binary_tx` and closes it at end of file.
    /// The application should compare the number of received bytes with `file.size`
    /// and report the result on the sender side of `result_rx` which determines
    /// the HTTP response (200 on `Ok`, 500 on `Err` or when the sender is dropped).
    ///
    /// Note: the checksum is only verified after the application reported its
    /// result, so a checksum mismatch is not observable by the application here
    /// (unlike [FileUploadTarget::Path] and [FileUploadTarget::Fd]).
    Stream {
        /// Channel the server sends the binary chunks of the file into.
        binary_tx: mpsc::Sender<Bytes>,

        /// Channel on which the application reports whether the file was
        /// processed successfully.
        result_rx: oneshot::Receiver<Result<(), String>>,
    },

    /// The server writes the file to this path and reports the result on
    /// `result_tx`.
    ///
    /// The content is written to a temporary file next to `path` and moved to
    /// `path` (replacing an existing file of that name) only once it is
    /// complete, so a failed or aborted transfer leaves no file behind.
    ///
    /// Timestamps provided in the sender's file metadata are applied to the
    /// written file, so the application does not need to set them itself.
    Path {
        /// The path to write the file to.
        path: PathBuf,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },

    /// The server writes the file to this raw file descriptor (Android only)
    /// and reports the result on `result_tx`.
    ///
    /// Timestamps provided in the sender's file metadata are applied through
    /// the descriptor, which also covers SAF documents that have no path.
    #[cfg(target_os = "android")]
    Fd {
        /// The raw file descriptor to write the file to.
        /// Ownership is transferred; the descriptor is closed after writing.
        fd: std::os::fd::RawFd,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },
}

/// The sender-provided timestamps of an uploaded file, applied to the written
/// file for [FileUploadTarget::Path] and [FileUploadTarget::Fd].
#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct FileTimestamps {
    pub modified: Option<std::time::SystemTime>,
    pub accessed: Option<std::time::SystemTime>,
}

impl FileTimestamps {
    fn is_empty(&self) -> bool {
        self.modified.is_none() && self.accessed.is_none()
    }
}

/// The temporary file an upload to [FileUploadTarget::Path] is written to
/// before it is moved to its final name.
///
/// Writing straight to the final name leaves a partial file behind whenever a
/// transfer fails or is aborted (sender disconnect, user cancel, a full disk),
/// and such a file cannot be told apart from a completely received one.
/// Writing next to the destination and renaming afterwards keeps the final
/// name unoccupied until the content is complete; the rename stays within one
/// directory, so it is atomic.
struct PendingFile {
    /// The file the upload is written to.
    temp: PathBuf,

    /// The name [Self::persist] moves the file to.
    final_path: PathBuf,

    /// Whether the temporary file has already been moved or removed.
    finished: bool,
}

impl PendingFile {
    /// Creates the temporary path for an upload that belongs at `final_path`.
    ///
    /// The name is hidden, ends in `.part` and carries a random component, so
    /// that it cannot collide with a file the user has.
    fn new(final_path: PathBuf) -> Self {
        let mut name = OsString::from(".");
        name.push(final_path.file_name().unwrap_or_default());
        let suffix = format!(".{:08x}.part", uuid::Uuid::new_v4().as_u128() as u32);
        name.push(suffix);

        Self {
            temp: final_path.with_file_name(name),
            final_path,
            finished: false,
        }
    }

    /// Moves the completely received file to its final name, replacing a file
    /// of that name (a retry of the same upload overwrites its target).
    async fn persist(&mut self) -> Result<(), String> {
        tokio::fs::rename(&self.temp, &self.final_path)
            .await
            .map_err(|e| {
                format!(
                    "Failed to move {} to {}: {e}",
                    self.temp.display(),
                    self.final_path.display()
                )
            })?;
        self.finished = true;
        Ok(())
    }

    /// Removes the incomplete file, so that no partial upload is left behind.
    async fn discard(mut self) {
        self.finished = true;
        remove_temporary_file(&self.temp).await;
    }
}

impl Drop for PendingFile {
    fn drop(&mut self) {
        if self.finished {
            return;
        }

        // The request was dropped before the outcome was known (e.g. the
        // connection closed), so the writer task may still be writing. The
        // temporary file is removed either way; its handle being open only
        // delays the deletion on some platforms, it does not keep the partial
        // data under the final name.
        let temp = std::mem::take(&mut self.temp);
        match tokio::runtime::Handle::try_current() {
            Ok(handle) => {
                handle.spawn(async move { remove_temporary_file(&temp).await });
            }
            Err(_) => {
                let _ = std::fs::remove_file(&temp);
            }
        }
    }
}

/// Removes a temporary file of an upload, if it still exists.
async fn remove_temporary_file(path: &Path) {
    if let Err(e) = tokio::fs::remove_file(path).await {
        if e.kind() != std::io::ErrorKind::NotFound {
            tracing::warn!("Could not remove incomplete upload {}: {e}", path.display());
        }
    }
}

/// Outcome of receiving an uploaded file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SaveResult {
    /// The file has been received and, if a checksum was given, it matched.
    Success,

    /// The body could not be read or the target failed to process it.
    Failed,

    /// The received bytes do not match the expected SHA-256 checksum.
    HashMismatch,
}

/// Forwards the body of `req` to `target`.
pub(crate) async fn save_req_to_target(
    req: Request<Incoming>,
    target: FileUploadTarget,
    file_size: u64,
    expected_sha256: Option<&str>,
    timestamps: FileTimestamps,
) -> SaveResult {
    use sha2::{Digest, Sha256};

    // Resolve the target into a chunk sender and a result receiver.
    // For [FileUploadTarget::Path] and [FileUploadTarget::Fd], the application's
    // result channel is answered by this function once the complete outcome
    // (including the checksum verification) is known.
    let (binary_tx, result_rx, app_result_tx, pending_file) = match target {
        FileUploadTarget::Stream {
            binary_tx,
            result_rx,
        } => (binary_tx, result_rx, None, None),
        FileUploadTarget::Path {
            path,
            result_tx,
            progress_tx,
        } => {
            // The upload is written next to its destination and moved to
            // `path` only once it is known to be complete, so a failed or
            // aborted transfer cannot leave a file under the final name.
            let pending_file = PendingFile::new(path);
            let open = {
                let temp = pending_file.temp.clone();
                async move {
                    tokio::fs::File::create(&temp)
                        .await
                        .map_err(|e| format!("Failed to create {}: {e}", temp.display()))
                }
            };
            let (binary_tx, result_rx) =
                spawn_file_writer(open, file_size, progress_tx, timestamps);
            (binary_tx, result_rx, Some(result_tx), Some(pending_file))
        }
        #[cfg(target_os = "android")]
        FileUploadTarget::Fd {
            fd,
            result_tx,
            progress_tx,
        } => {
            let (binary_tx, result_rx) = spawn_file_writer(
                async move {
                    use std::os::fd::FromRawFd;

                    // SAFETY: the descriptor is owned by this transfer; wrapping it in
                    // a File transfers that ownership so it is closed once writing finishes.
                    let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
                    Ok(tokio::fs::File::from_std(std_file))
                },
                file_size,
                progress_tx,
                timestamps,
            );
            (binary_tx, result_rx, Some(result_tx), None)
        }
    };

    // Forward the request body to the target, hashing it on the way if requested.
    let mut hasher = expected_sha256.map(|_| Sha256::new());
    let mut body = req.into_body();
    let mut stream_error = false;
    while let Some(frame) = body.frame().await {
        match frame {
            Ok(frame) => {
                let Ok(data) = frame.into_data() else {
                    continue; // ignore non-data frames (e.g. trailers)
                };
                if data.is_empty() {
                    continue;
                }
                if let Some(hasher) = &mut hasher {
                    hasher.update(&data);
                }
                if binary_tx.send(data).await.is_err() {
                    // The receiver is gone (dropped by the application or
                    // closed by the file writer after an error).
                    stream_error = true;
                    break;
                }
            }
            Err(err) => {
                tracing::warn!("Error reading upload body of file: {err:#}");
                stream_error = true;
                break;
            }
        }
    }

    // Signal end of file to the receiving side.
    drop(binary_tx);

    // Determine the outcome; `error` carries the reason for the application.
    let (mut result, mut error): (SaveResult, Option<String>) = 'outcome: {
        if stream_error {
            // The file writer (if any) fails with a size mismatch or its own
            // write error once the channel is closed; collect that reason.
            let error = match app_result_tx.is_some() {
                true => match result_rx.await {
                    Ok(Err(err)) => Some(err),
                    _ => None,
                },
                false => None,
            };
            break 'outcome (
                SaveResult::Failed,
                error.or(Some("Upload aborted".to_string())),
            );
        }

        match result_rx.await {
            Ok(Ok(())) => (),
            Ok(Err(err)) => {
                tracing::warn!("Failed to process file: {err}");
                break 'outcome (SaveResult::Failed, Some(err));
            }
            Err(_) => break 'outcome (SaveResult::Failed, Some("Upload aborted".to_string())),
        }

        if let (Some(hasher), Some(expected)) = (hasher, expected_sha256) {
            let actual = crypto::hash::to_hex(&hasher.finalize());
            if !actual.eq_ignore_ascii_case(expected) {
                tracing::warn!("Checksum mismatch: expected {expected}, got {actual}");
                break 'outcome (
                    SaveResult::HashMismatch,
                    Some("Checksum mismatch".to_string()),
                );
            }
        }

        (SaveResult::Success, None)
    };

    // Publish the file only once it is known to be complete: a failed or
    // aborted transfer has to leave nothing under its final name.
    if let Some(mut pending_file) = pending_file {
        match result {
            SaveResult::Success => {
                if let Err(err) = pending_file.persist().await {
                    tracing::warn!("{err}");
                    error = Some(err);
                    result = SaveResult::Failed;
                }
            }
            SaveResult::Failed | SaveResult::HashMismatch => pending_file.discard().await,
        }
    }

    if let Some(app_result_tx) = app_result_tx {
        let _ = app_result_tx.send(match error {
            None => Ok(()),
            Some(err) => Err(err),
        });
    }

    result
}

/// Spawns a task that writes incoming chunks to a file provided by `open`.
///
/// Returns the sender for the binary chunks and a receiver for the final result.
fn spawn_file_writer(
    open: impl Future<Output = Result<tokio::fs::File, String>> + Send + 'static,
    expected_size: u64,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> (mpsc::Sender<Bytes>, oneshot::Receiver<Result<(), String>>) {
    let (binary_tx, mut binary_rx) = mpsc::channel::<Bytes>(UPLOAD_CHANNEL_CAPACITY);
    let (internal_tx, internal_rx) = oneshot::channel::<Result<(), String>>();

    tokio::spawn(async move {
        let result =
            write_file_from_receiver(open, expected_size, &mut binary_rx, progress_tx, timestamps)
                .await;
        // Unblock the request handler if it is still sending chunks.
        binary_rx.close();
        let _ = internal_tx.send(result);
    });

    (binary_tx, internal_rx)
}

/// Writes all chunks received on `rx` to the file provided by `open`.
///
/// Fails if the total number of written bytes does not match `expected_size`
/// (e.g. the sender disconnected mid-transfer).
///
/// The file is truncated to the written size, so that a target that pointed at
/// a longer, pre-existing file cannot keep a tail of the old content.
///
/// The sender-provided `timestamps` are applied to the completely written
/// file. This happens on the still-open handle: an Android file descriptor has
/// no path to address the file by afterwards.
async fn write_file_from_receiver(
    open: impl Future<Output = Result<tokio::fs::File, String>>,
    expected_size: u64,
    rx: &mut mpsc::Receiver<Bytes>,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> Result<(), String> {
    use tokio::io::AsyncWriteExt;

    let mut file = tokio::io::BufWriter::with_capacity(WRITE_BUFFER_SIZE, open.await?);
    let mut written: u64 = 0;
    while let Some(chunk) = rx.recv().await {
        written += chunk.len() as u64;
        if written > expected_size {
            return Err(format!(
                "Expected {expected_size} bytes, received at least {written}"
            ));
        }
        file.write_all(&chunk)
            .await
            .map_err(|e| format!("Failed to write file: {e}"))?;
        if let Some(progress_tx) = &progress_tx {
            // Progress is best-effort: drop the event when the consumer lags.
            let _ = progress_tx.try_send(written);
        }
    }
    file.flush()
        .await
        .map_err(|e| format!("Failed to flush file: {e}"))?;
    let file = file.into_inner();

    if written != expected_size {
        return Err(format!(
            "Expected {expected_size} bytes, received {written}"
        ));
    }

    // Drops content beyond the file that was just written, in case the target
    // pointed at a longer, pre-existing file: opening truncates for paths and
    // for descriptors opened with the SAF "wt" mode, but a document provider is
    // free to ignore that mode. Retries of the same upload are covered by the
    // exact size check above either way.
    //
    // Best-effort: a provider may back the descriptor by something that cannot
    // be truncated (e.g. a pipe), which must not fail the completed transfer.
    if let Err(e) = file.set_len(written).await {
        tracing::warn!("Could not truncate file to {written} bytes: {e}");
    }

    // The timestamps are applied last because the writes and the truncation
    // above update the modification time themselves.
    //
    // The handle is closed before the result is reported: the caller moves the
    // file to its final name, which a still open file would block (Windows).
    let file = file.into_std().await;
    if !timestamps.is_empty() {
        let mut times = std::fs::FileTimes::new();
        if let Some(modified) = timestamps.modified {
            times = times.set_modified(modified);
        }
        if let Some(accessed) = timestamps.accessed {
            times = times.set_accessed(accessed);
        }
        // Also closes the file, off the async runtime like tokio::fs does.
        //
        // Best-effort: the provider backing an Android file descriptor may not
        // support changing timestamps, which must not fail the completed
        // transfer.
        let result = tokio::task::spawn_blocking(move || file.set_times(times)).await;
        if let Ok(Err(e)) = result {
            tracing::warn!("Could not set file timestamps: {e}");
        }
    }

    Ok(())
}
