// SPDX-License-Identifier: GPL-3.0-or-later

//! Unix-socket single-instance handling.
//!
//! A second launch forwards its file arguments to the running instance over a
//! Unix domain socket, matching the previous Qt application's protocol:
//! newline-separated paths, then a one-byte ack.

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::{env, fs, time::Duration};

use cosmic::iced::Subscription;
use cosmic::iced::futures::SinkExt;
use cosmic::iced::futures::channel::mpsc::Sender;
use cosmic::iced::stream;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;

const APP_ID: &str = "com.goshapps.Notepad";

/// Socket path under `$XDG_RUNTIME_DIR` (or the temp dir).
#[must_use]
pub fn socket_path() -> PathBuf {
    let runtime_dir = env::var("XDG_RUNTIME_DIR")
        .unwrap_or_else(|_| env::temp_dir().to_string_lossy().into_owned());
    PathBuf::from(runtime_dir).join(format!("{APP_ID}.sock"))
}

/// Send `files` to an already-running instance. Returns true if one was found
/// and the payload was delivered.
#[must_use]
pub fn forward(files: &[PathBuf]) -> bool {
    let path = socket_path();
    if !path.exists() {
        return false;
    }
    forward_to(&path, files)
}

fn parse_payload(buf: &[u8]) -> Vec<PathBuf> {
    String::from_utf8_lossy(buf)
        .split('\n')
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .collect()
}

fn forward_to(path: &Path, files: &[PathBuf]) -> bool {
    match UnixStream::connect(path) {
        Ok(mut client) => {
            let _ = client.set_read_timeout(Some(Duration::from_secs(2)));
            let _ = client.set_write_timeout(Some(Duration::from_secs(2)));
            let payload = files
                .iter()
                .map(|p| p.to_string_lossy().into_owned())
                .collect::<Vec<_>>()
                .join("\n");
            if client.write_all(payload.as_bytes()).is_err() {
                return false;
            }
            let _ = client.shutdown(std::net::Shutdown::Write);
            let mut ack = [0u8; 1];
            client.read_exact(&mut ack).is_ok()
        }
        Err(_) => false,
    }
}

/// If `path` exists but nobody is listening, unlink the stale socket.
pub fn unlink_if_stale(path: &Path) {
    if !path.exists() {
        return;
    }
    match UnixStream::connect(path) {
        Ok(_) => {}
        Err(_) => {
            let _ = fs::remove_file(path);
        }
    }
}

struct SocketGuard(PathBuf);

impl Drop for SocketGuard {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}

/// Subscription that accepts connections and yields forwarded file lists.
///
/// An empty payload (second launch with no files) still yields an empty
/// `Vec` so the running window can present itself.
pub fn subscription() -> Subscription<Vec<PathBuf>> {
    subscription_at(socket_path())
}

/// `subscription` bound to an explicit socket path (T13 test seam;
/// architecture.md T8).
fn subscription_at(path: PathBuf) -> Subscription<Vec<PathBuf>> {
    // `Subscription::run` takes a bare fn pointer, so the path travels as
    // `run_with` data instead of a capture
    // (`libcosmic:iced/futures/src/subscription.rs:182,198`).
    Subscription::run_with(path, |path| {
        let path = path.clone();
        stream::channel(4, move |output| server(path, output))
    })
}

/// Accept loop: unlink a stale socket, bind, then forward each connection's
/// payload after writing the ack byte. Runs until the stream is dropped;
/// `SocketGuard` unlinks the socket on shutdown.
async fn server(path: PathBuf, mut output: Sender<Vec<PathBuf>>) {
    unlink_if_stale(&path);

    let listener = match UnixListener::bind(&path) {
        Ok(listener) => listener,
        Err(why) => {
            // R9 (optional logging, PLAN T13): a failed bind means forwards
            // are silently missed; make it diagnosable instead.
            eprintln!(
                "notepad: single-instance socket {} unavailable: {why}",
                path.display()
            );
            return;
        }
    };
    let _guard = SocketGuard(path);

    loop {
        let Ok((mut connection, _)) = listener.accept().await else {
            continue;
        };
        let mut buf = Vec::new();
        let _ = connection.read_to_end(&mut buf).await;
        let _ = connection.write_all(&[0]).await;
        let files = parse_payload(&buf);
        let _ = output.send(files).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn socket_path_uses_app_id() {
        let path = socket_path();
        assert!(
            path.file_name()
                .and_then(|n| n.to_str())
                .is_some_and(|n| n.contains("com.goshapps.Notepad"))
        );
    }

    #[test]
    fn parse_payload_splits_paths_and_drops_empties() {
        assert!(parse_payload(b"").is_empty());
        assert!(parse_payload(b"\n").is_empty());
        assert_eq!(
            parse_payload(b"/tmp/a.txt\n/tmp/b.txt\n"),
            vec![PathBuf::from("/tmp/a.txt"), PathBuf::from("/tmp/b.txt")]
        );
    }

    #[test]
    fn forward_round_trips_paths_and_empty_payload() {
        use std::os::unix::net::UnixListener;
        use std::sync::mpsc;
        use std::thread;

        let dir = std::env::temp_dir().join(format!(
            "notepad-si-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        let sock = dir.join("notepad.sock");
        let _ = fs::remove_file(&sock);
        let listener = UnixListener::bind(&sock).unwrap();

        let (tx, rx) = mpsc::channel::<Vec<PathBuf>>();
        let server = thread::spawn(move || {
            for _ in 0..2 {
                let (mut connection, _) = listener.accept().unwrap();
                let mut buf = Vec::new();
                connection.read_to_end(&mut buf).unwrap();
                connection.write_all(&[0]).unwrap();
                tx.send(parse_payload(&buf)).unwrap();
            }
        });

        assert!(forward_to(&sock, &[PathBuf::from("/tmp/note.txt")]));
        assert_eq!(rx.recv().unwrap(), vec![PathBuf::from("/tmp/note.txt")]);
        assert!(forward_to(&sock, &[]));
        assert!(rx.recv().unwrap().is_empty());

        server.join().unwrap();
        let _ = fs::remove_file(&sock);
        let _ = fs::remove_dir(&dir);
    }

    /// T13: the real `server` loop on a tokio current-thread runtime —
    /// binds a temp socket, forwards via the production client `forward_to`,
    /// acks, and still yields an empty `Vec` for an empty payload.
    #[test]
    fn server_round_trips_payloads_with_ack() {
        use cosmic::iced::futures::StreamExt;

        let dir = std::env::temp_dir().join(format!(
            "notepad-si-srv-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        let sock = dir.join("notepad.sock");

        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_io()
            .build()
            .unwrap();
        rt.block_on(async {
            let (tx, mut rx) = cosmic::iced::futures::channel::mpsc::channel::<Vec<PathBuf>>(4);
            let handle = tokio::spawn(server(sock.clone(), tx));

            // Client leg uses the production `forward_to`; retry briefly to
            // cover the window before the server has bound the socket.
            let client_sock = sock.clone();
            let sent = tokio::task::spawn_blocking(move || {
                for _ in 0..100 {
                    if forward_to(
                        &client_sock,
                        &[PathBuf::from("/tmp/a.txt"), PathBuf::from("/tmp/b.txt")],
                    ) {
                        return true;
                    }
                    std::thread::sleep(Duration::from_millis(10));
                }
                false
            });

            let files = rx.next().await.expect("server should forward the payload");
            assert_eq!(
                files,
                vec![PathBuf::from("/tmp/a.txt"), PathBuf::from("/tmp/b.txt")]
            );
            assert!(sent.await.unwrap(), "client should receive the ack byte");

            // Empty payload still yields an empty Vec (window-present case).
            let client_sock = sock.clone();
            let sent = tokio::task::spawn_blocking(move || forward_to(&client_sock, &[]));
            let files = rx.next().await.expect("empty payload should still yield");
            assert!(files.is_empty());
            assert!(sent.await.unwrap());

            handle.abort();
        });
        let _ = fs::remove_file(&sock);
        let _ = fs::remove_dir(&dir);
    }

    /// T13: a stale socket file (listener gone) is unlinked by `server`
    /// itself before binding — the `unlink_if_stale` leg end-to-end.
    #[test]
    fn server_unlinks_stale_socket_then_serves() {
        use cosmic::iced::futures::StreamExt;

        let dir = std::env::temp_dir().join(format!(
            "notepad-si-stale-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        let sock = dir.join("notepad.sock");

        // std's UnixListener does not unlink on drop: the file lingers with
        // nobody listening, so connects fail — the definition of stale here.
        {
            let stale = std::os::unix::net::UnixListener::bind(&sock).unwrap();
            drop(stale);
        }
        assert!(sock.exists(), "stale socket file should linger");

        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_io()
            .build()
            .unwrap();
        rt.block_on(async {
            let (tx, mut rx) = cosmic::iced::futures::channel::mpsc::channel::<Vec<PathBuf>>(4);
            let handle = tokio::spawn(server(sock.clone(), tx));

            let client_sock = sock.clone();
            let sent = tokio::task::spawn_blocking(move || {
                for _ in 0..100 {
                    if forward_to(&client_sock, &[PathBuf::from("/tmp/after-stale.txt")]) {
                        return true;
                    }
                    std::thread::sleep(Duration::from_millis(10));
                }
                false
            });

            let files = rx
                .next()
                .await
                .expect("server should bind after unlinking the stale socket");
            assert_eq!(files, vec![PathBuf::from("/tmp/after-stale.txt")]);
            assert!(sent.await.unwrap());

            handle.abort();
        });
        let _ = fs::remove_file(&sock);
        let _ = fs::remove_dir(&dir);
    }
}
