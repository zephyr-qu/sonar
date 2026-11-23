/// The head and tail of a certificate fingerprint, which is what the UI shows
/// instead of all 64 hex characters.
String shortFingerprint(String fingerprint) {
  return fingerprint.length > 12 ? '${fingerprint.substring(0, 6)}…${fingerprint.substring(fingerprint.length - 4)}' : fingerprint;
}
