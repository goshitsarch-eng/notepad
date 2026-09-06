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
    Subscription::run(|| {
        stream::channel(4, async |mut output| {
            let path = socket_path();
            unlink_if_stale(&path);

            let Ok(listener) = UnixListener::bind(&path) else {
                return;
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
        })
    })
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
}
