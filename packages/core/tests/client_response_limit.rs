#![cfg(feature = "http")]

use localsend::http::client::{ClientError, LsHttpClientV2, MAX_RESPONSE_BODY_SIZE};
use localsend::http::dto::RegisterDto;
use localsend::model::discovery::ProtocolType;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

/// How the rogue peer answers the register request.
#[derive(Clone, Copy)]
enum Reply {
    /// Announces a body above the limit and then never sends it.
    AnnouncedTooLarge,

    /// Streams an endless chunked body without announcing a length.
    EndlessChunks,

    /// Answers with an error status, but never stops streaming its body.
    ErrorWithEndlessBody,
}

/// Starts a peer that does not speak the protocol: it reads one request and
/// answers it with [`Reply`], which is all a rogue host on the network has to do
/// to be probed by the subnet scan.
async fn start_rogue_server(reply: Reply) -> u16 {
    let listener = TcpListener::bind("127.0.0.1:0")
        .await
        .expect("Failed to bind the rogue server");
    let port = listener
        .local_addr()
        .expect("Failed to read the rogue server address")
        .port();

    tokio::spawn(async move {
        while let Ok((mut socket, _)) = listener.accept().await {
            tokio::spawn(async move {
                if !read_request(&mut socket).await {
                    return;
                }

                let head = match reply {
                    Reply::AnnouncedTooLarge => format!(
                        "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n",
                        MAX_RESPONSE_BODY_SIZE as u64 + 1
                    ),
                    Reply::EndlessChunks => concat!(
                        "HTTP/1.1 200 OK\r\n",
                        "content-type: application/json\r\n",
                        "transfer-encoding: chunked\r\n\r\n",
                    )
                    .to_string(),
                    Reply::ErrorWithEndlessBody => format!(
                        "HTTP/1.1 403 Forbidden\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n",
                        MAX_RESPONSE_BODY_SIZE as u64 + 1
                    ),
                };

                if socket.write_all(head.as_bytes()).await.is_err() {
                    return;
                }

                if matches!(reply, Reply::AnnouncedTooLarge) {
                    // The announced body never arrives: the client has to reject
                    // the length instead of waiting for it.
                    tokio::time::sleep(Duration::from_secs(30)).await;
                    return;
                }

                // 64 KiB per chunk, forever: only the client's limit ends this.
                let chunk = vec![b'x'; 64 * 1024];
                loop {
                    if socket.write_all(b"10000\r\n").await.is_err()
                        || socket.write_all(&chunk).await.is_err()
                        || socket.write_all(b"\r\n").await.is_err()
                    {
                        return;
                    }
                }
            });
        }
    });

    port
}

/// Reads one request off the socket, so the client can finish sending its body.
///
/// Returns `false` when the connection ended before the request was complete.
async fn read_request(socket: &mut TcpStream) -> bool {
    let mut request = Vec::new();
    let mut chunk = [0_u8; 4096];

    let headers_end = loop {
        match socket.read(&mut chunk).await {
            Ok(0) | Err(_) => return false,
            Ok(read) => request.extend_from_slice(&chunk[..read]),
        }

        if let Some(position) = find_headers_end(&request) {
            break position;
        }
    };

    let content_length = String::from_utf8_lossy(&request[..headers_end])
        .lines()
        .find_map(|line| {
            let (name, value) = line.split_once(':')?;
            name.eq_ignore_ascii_case("content-length")
                .then(|| value.trim().parse::<usize>().ok())
                .flatten()
        })
        .unwrap_or(0);

    while request.len() < headers_end + 4 + content_length {
        match socket.read(&mut chunk).await {
            Ok(0) | Err(_) => return false,
            Ok(read) => request.extend_from_slice(&chunk[..read]),
        }
    }

    true
}

fn find_headers_end(request: &[u8]) -> Option<usize> {
    request.windows(4).position(|window| window == b"\r\n\r\n")
}

fn register_dto() -> RegisterDto {
    RegisterDto {
        alias: "Test Sender".to_string(),
        version: "2.2".to_string(),
        device_model: None,
        device_type: None,
        fingerprint: "TEST-FINGERPRINT".to_string(),
        port: 53317,
        protocol: ProtocolType::Http,
        download: false,
    }
}

#[tokio::test]
async fn test_register_rejects_an_announced_oversized_body() {
    let port = start_rogue_server(Reply::AnnouncedTooLarge).await;
    let client = LsHttpClientV2::try_new_without_cert().expect("Failed to create the client");

    let result = tokio::time::timeout(
        Duration::from_secs(10),
        client.register(ProtocolType::Http, "127.0.0.1", port, register_dto()),
    )
    .await
    .expect("register must not wait for a body it will never accept");

    match result {
        Err(ClientError::BodyTooLarge) => {}
        Err(err) => panic!("Expected BodyTooLarge, got error: {err:?}"),
        Ok(_) => panic!("Expected BodyTooLarge, got a successful response"),
    }
}

#[tokio::test]
async fn test_register_rejects_an_endless_chunked_body() {
    let port = start_rogue_server(Reply::EndlessChunks).await;
    let client = LsHttpClientV2::try_new_without_cert().expect("Failed to create the client");

    let result = tokio::time::timeout(
        Duration::from_secs(10),
        client.register(ProtocolType::Http, "127.0.0.1", port, register_dto()),
    )
    .await
    .expect("register must stop reading at the response body limit");

    match result {
        Err(ClientError::BodyTooLarge) => {}
        Err(err) => panic!("Expected BodyTooLarge, got error: {err:?}"),
        Ok(_) => panic!("Expected BodyTooLarge, got a successful response"),
    }
}

#[tokio::test]
async fn test_error_response_keeps_its_status_when_the_body_is_endless() {
    let port = start_rogue_server(Reply::ErrorWithEndlessBody).await;
    let client = LsHttpClientV2::try_new_without_cert().expect("Failed to create the client");

    let result = tokio::time::timeout(
        Duration::from_secs(10),
        client.register(ProtocolType::Http, "127.0.0.1", port, register_dto()),
    )
    .await
    .expect("an endless error body must not replace the status code");

    match result {
        Err(ClientError::StatusCode(err)) => assert_eq!(err.status, 403),
        Err(err) => panic!("Expected the 403 status, got error: {err:?}"),
        Ok(_) => panic!("Expected the 403 status, got a successful response"),
    }
}
