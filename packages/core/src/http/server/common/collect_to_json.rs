use crate::http::server::common::error::AppError;
use bytes::Bytes;
use http_body_util::{BodyExt, LengthLimitError, Limited};
use hyper::body::Incoming;
use hyper::StatusCode;
use serde::de::DeserializeOwned;

/// Upper bound for a JSON request body (`register`, `prepare-upload`, `show`).
///
/// The largest body the protocol sends is a `prepare-upload` manifest, which
/// stays far below this even for thousands of files. Anything beyond the limit
/// is not a real transfer and must not be buffered into memory, so it is
/// answered with `413` instead.
pub const MAX_JSON_BODY_SIZE: u64 = 4 * 1024 * 1024;

pub(crate) trait CollectToJson {
    /// Reads the body, failing with `413` once it exceeds
    /// [`MAX_JSON_BODY_SIZE`].
    ///
    /// Everything past the limit is left unread, so hyper closes the
    /// connection instead of the server draining the rest of the request.
    async fn collect_json_bytes(self) -> Result<Bytes, AppError>;

    /// Reads the body and parses it as JSON.
    async fn collect_to_json<T: DeserializeOwned>(self) -> Result<T, AppError>;
}

impl CollectToJson for Incoming {
    async fn collect_json_bytes(self) -> Result<Bytes, AppError> {
        match Limited::new(self, MAX_JSON_BODY_SIZE as usize)
            .collect()
            .await
        {
            Ok(collected) => Ok(collected.to_bytes()),
            // A body is only limited here, so this is the oversized case: a
            // declared `Content-Length` is not pre-checked, the frames are.
            Err(err) if err.downcast_ref::<LengthLimitError>().is_some() => Err(body_too_large()),
            Err(err) => {
                tracing::warn!("Failed to read the request body: {err:#}");
                Err(AppError::Message(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Internal server error".to_string(),
                ))
            }
        }
    }

    async fn collect_to_json<T: DeserializeOwned>(self) -> Result<T, AppError> {
        let bytes = self.collect_json_bytes().await?;
        serde_json::from_slice::<T>(&bytes).map_err(|err| {
            tracing::warn!("Failed to parse JSON body: {err:#}");
            AppError::BadRequest("Invalid JSON body".to_string())
        })
    }
}

fn body_too_large() -> AppError {
    AppError::Message(
        StatusCode::PAYLOAD_TOO_LARGE,
        "Request body too large".to_string(),
    )
}

/// Reads and discards the request body, up to [`MAX_JSON_BODY_SIZE`].
///
/// Answering before the body has been read forces hyper to close the connection,
/// and the operating system resets it instead of finishing the exchange, so the
/// sender can see a network error instead of the answer. Use this on the paths
/// that decide on the request before its body matters (the PIN check).
pub(crate) async fn drain_body(body: Incoming) {
    // Bounded: a body past the limit is left unread, so hyper closes the
    // connection rather than the server draining an arbitrarily large one.
    let _ = Limited::new(body, MAX_JSON_BODY_SIZE as usize)
        .collect()
        .await;
}
