/// Why a transfer ended with errors, in one line, or null when nothing failed.
///
/// A session-level message names the request itself (no answer, wrong PIN, ...)
/// and is the whole story when it exists: the files never started, so none of
/// them carries a reason of its own.
///
/// A transfer that did run only has per-file reasons, and those are meaningless
/// without the file they belong to, so the first one is reported with its name.
/// [files] is an iterable of `(fileName, errorMessage)` pairs.
String? transferFailureReason({
  String? sessionError,
  Iterable<(String, String?)> files = const [],
}) {
  if (sessionError != null && sessionError.trim().isNotEmpty) {
    return sessionError;
  }
  for (final (fileName, error) in files) {
    if (error != null && error.trim().isNotEmpty) {
      return '$fileName: $error';
    }
  }
  return null;
}
