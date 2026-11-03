use crate::http::server::common::error::AppError;
use hyper::StatusCode;
use lru::LruCache;
use std::collections::HashMap;
use std::net::IpAddr;
use std::num::NonZeroUsize;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;

/// Maximum failed PIN attempts per IP within [`PIN_ATTEMPT_WINDOW`].
const MAX_PIN_ATTEMPTS: u32 = 3;

/// How long failed PIN attempts are remembered.
///
/// The attempts have to expire: without a window, a peer that mistyped the PIN
/// three times would be answered with 429 until the server restarts, even when
/// it enters the correct PIN afterwards.
const PIN_ATTEMPT_WINDOW: Duration = Duration::from_secs(60);

/// Failed PIN attempts of one client IP.
#[derive(Debug, Clone, Copy)]
struct Attempts {
    count: u32,

    /// When the first of the counted attempts happened.
    since: Instant,
}

/// Failed PIN attempts per client IP, shared by all requests of a server.
pub(crate) struct PinAttempts {
    attempts: Mutex<LruCache<IpAddr, Attempts>>,

    /// How long an attempt is remembered, see [`PIN_ATTEMPT_WINDOW`].
    window: Duration,
}

impl PinAttempts {
    pub(crate) fn new() -> Self {
        Self::with_window(PIN_ATTEMPT_WINDOW)
    }

    fn with_window(window: Duration) -> Self {
        Self {
            attempts: Mutex::new(LruCache::new(NonZeroUsize::new(200).unwrap())),
            window,
        }
    }
}

/// Checks the `pin` query parameter against the required PIN (if any).
pub(crate) async fn check_pin(
    required_pin: Option<&str>,
    pin_attempts: &PinAttempts,
    query: &HashMap<String, String>,
    ip: IpAddr,
) -> Result<(), AppError> {
    let Some(required_pin) = required_pin else {
        return Ok(());
    };

    let mut attempts = pin_attempts.attempts.lock().await;
    let now = Instant::now();
    let recorded = attempts
        .get(&ip)
        .copied()
        .filter(|attempts| now.duration_since(attempts.since) < pin_attempts.window);
    let count = recorded.map_or(0, |attempts| attempts.count);

    if count >= MAX_PIN_ATTEMPTS {
        return Err(AppError::Message(
            StatusCode::TOO_MANY_REQUESTS,
            "Too many requests".to_string(),
        ));
    }

    match query.get("pin") {
        Some(pin) if pin == required_pin => {
            attempts.pop(&ip);
            Ok(())
        }
        Some(_) => {
            // A window that already expired starts over, so the block above is
            // the only way to reach 429 and it ends with the window.
            attempts.put(
                ip,
                Attempts {
                    count: count + 1,
                    since: recorded.map_or(now, |attempts| attempts.since),
                },
            );
            Err(AppError::Message(
                StatusCode::UNAUTHORIZED,
                "Invalid PIN".to_string(),
            ))
        }
        None => Err(AppError::Message(
            StatusCode::UNAUTHORIZED,
            "PIN required".to_string(),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pin(pin: &str) -> HashMap<String, String> {
        HashMap::from([("pin".to_string(), pin.to_string())])
    }

    fn ip() -> IpAddr {
        "127.0.0.1".parse().unwrap()
    }

    async fn fail(pin_attempts: &PinAttempts) {
        let err = check_pin(Some("1234"), pin_attempts, &pin("0000"), ip())
            .await
            .unwrap_err();
        assert!(matches!(
            err,
            AppError::Message(StatusCode::UNAUTHORIZED, _)
        ));
    }

    #[tokio::test]
    async fn test_pin_attempts_are_counted() {
        let pin_attempts = PinAttempts::new();

        for _ in 0..MAX_PIN_ATTEMPTS {
            fail(&pin_attempts).await;
        }

        let err = check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .unwrap_err();
        assert!(matches!(
            err,
            AppError::Message(StatusCode::TOO_MANY_REQUESTS, _)
        ));
    }

    #[tokio::test]
    async fn test_pin_attempts_expire() {
        let pin_attempts = PinAttempts::with_window(Duration::from_millis(50));

        for _ in 0..MAX_PIN_ATTEMPTS {
            fail(&pin_attempts).await;
        }
        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .is_err());

        tokio::time::sleep(Duration::from_millis(60)).await;
        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .is_ok());
    }

    #[tokio::test]
    async fn test_pin_attempts_are_per_ip() {
        let pin_attempts = PinAttempts::new();
        let other: IpAddr = "127.0.0.2".parse().unwrap();

        for _ in 0..MAX_PIN_ATTEMPTS {
            fail(&pin_attempts).await;
        }

        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), other)
            .await
            .is_ok());
    }

    #[tokio::test]
    async fn test_correct_pin_resets_attempts() {
        let pin_attempts = PinAttempts::new();

        fail(&pin_attempts).await;
        fail(&pin_attempts).await;
        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .is_ok());

        // The two earlier attempts are forgotten, so two more are allowed.
        fail(&pin_attempts).await;
        fail(&pin_attempts).await;
        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .is_ok());
    }

    #[tokio::test]
    async fn test_missing_pin_is_not_counted() {
        let pin_attempts = PinAttempts::new();

        for _ in 0..MAX_PIN_ATTEMPTS + 1 {
            let err = check_pin(Some("1234"), &pin_attempts, &HashMap::new(), ip())
                .await
                .unwrap_err();
            assert!(matches!(
                err,
                AppError::Message(StatusCode::UNAUTHORIZED, _)
            ));
        }

        assert!(check_pin(Some("1234"), &pin_attempts, &pin("1234"), ip())
            .await
            .is_ok());
    }
}
