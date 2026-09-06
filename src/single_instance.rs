// SPDX-License-Identifier: GPL-3.0-or-later

//! Unix-socket single-instance handling.
//!
//! A second launch forwards its file arguments to the running instance over a
//! Unix domain socket, matching the previous Qt application's protocol:
//! newline-separated paths, then a one-byte ack.

use std::io::{Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::{env, fs, thread, time::Duration};

use cosmic::iced::Subscription;
use cosmic::iced::futures::SinkExt;
use cosmic::iced::stream;

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
    match UnixStream::connect(&path) {
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

/// Subscription that accepts connections and yields forwarded file lists.
pub fn subscription() -> Subscription<Vec<PathBuf>> {
    Subscription::run(|| {
        stream::channel(4, async |mut output| {
            let path = socket_path();
            unlink_if_stale(&path);

            let listener = match UnixListener::bind(&path) {
                Ok(listener) => listener,
                Err(_) => return,
            };
            let _ = listener.set_nonblocking(true);

            loop {
                match listener.accept() {
                    Ok((mut connection, _)) => {
                        let mut buf = Vec::new();
                        if connection.read_to_end(&mut buf).is_ok() {
                            let _ = connection.write_all(&[0]);
                            let payload = String::from_utf8_lossy(&buf);
                            let files: Vec<PathBuf> = payload
                                .split('\n')
                                .filter(|s| !s.is_empty())
                                .map(PathBuf::from)
                                .collect();
                            let _ = output.send(files).await;
                        }
                    }
                    Err(err) if err.kind() == std::io::ErrorKind::WouldBlock => {
                        tokio::time::sleep(Duration::from_millis(100)).await;
                    }
                    Err(_) => {
                        thread::sleep(Duration::from_millis(100));
                    }
                }
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
}
