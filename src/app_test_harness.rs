// SPDX-License-Identifier: GPL-3.0-or-later

//! Headless test harness for the `App` state model (T02; architecture.md
//! §3.4–§3.5). Included from `app.rs` via `#[cfg(test)] #[path]`, so private
//! fields, `App::with_config` and private methods are all in scope.
//!
//! Ground rules proven by the Phase-1 spike (/tmp/cosmic-headless-spike, 8/8):
//! `Core::default()` needs no display, `Task`s are lazy and inert when
//! dropped, and `Content` editing is CPU-only. Config handlers here are
//! either `None` or `Config::with_custom_path` tempdirs — never the real
//! `~/.config` (R4).

use super::*;
use cosmic::Application; // trait methods/consts don't propagate through `use super::*` globs
use std::sync::atomic::{AtomicU64, Ordering};

/// Tempdir with a `Drop` guard (runs on panic-unwind too). Names are
/// race-free under parallel `cargo test`: pid + thread id + process-wide
/// counter. No `tempfile` dev-dep — lead-approved design of record
/// (architecture.md §3.4: keeps ~5–8 crates out of Cargo.lock and the D9
/// vendor tarball).
pub(crate) struct TempDir(PathBuf);

impl TempDir {
    pub(crate) fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

pub(crate) fn test_tempdir(tag: &str) -> TempDir {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let dir = std::env::temp_dir().join(format!(
        "notepad-test-{tag}-{}-{:?}-{}",
        std::process::id(),
        std::thread::current().id(),
        COUNTER.fetch_add(1, Ordering::Relaxed)
    ));
    std::fs::create_dir_all(&dir).expect("create tempdir");
    TempDir(dir)
}

/// App with a `ColorScheme::Light`-pinned config and **no** config handler:
/// `persist_config` is a no-op, so nothing is ever written to a real config
/// dir. The Light pin is §3.4's design of record (architecture.md :394–397):
/// headless THEME defaults to Dark and `Config::default()`'s scheme is
/// `System` (config.rs:10–11), which would make theme assertions
/// environment-dependent for every T09–T14 reuser — T12's scheme matrix
/// especially. Harness rule: never assert on System-scheme darkness.
pub(crate) fn test_app() -> App {
    let config = Config {
        color_scheme: ColorScheme::Light,
        ..Default::default()
    };
    let (app, task) = App::with_config(cosmic::Core::default(), Flags::default(), config, None);
    drop(task); // init tasks are lazy and never polled in unit tests
    app
}

/// App pre-loaded with document text; `saved_text` synced so it starts clean.
pub(crate) fn app_with_text(text: &str) -> App {
    let mut app = test_app();
    app.content = Content::with_text(text);
    app.saved_text = app.content.text();
    app
}

/// App whose config handler persists per-key RON files under a fresh tempdir
/// (env-free `Config::with_custom_path` seam —
/// `libcosmic:cosmic-config/src/lib.rs:253`). Returns the app plus the dir
/// guard; on-disk layout is `<dir>/cosmic/<APP_ID>/v<version>/<key>` (RON),
/// spike-proven. `get_entry` on the empty tempdir yields defaults, so the
/// §3.4 `ColorScheme::Light` pin is applied in-memory before assembly — same
/// determinism guarantee as `test_app`; the persistence mechanism itself is
/// untouched.
pub(crate) fn app_with_tempdir_config(tag: &str) -> (App, TempDir) {
    let dir = test_tempdir(tag);
    let handler = cosmic_config::Config::with_custom_path(
        App::APP_ID,
        Config::VERSION,
        dir.path().to_path_buf(),
    )
    .expect("custom-path handler");
    let mut config = Config::get_entry(&handler).unwrap_or_else(|(_, config)| config);
    config.color_scheme = ColorScheme::Light;
    let (app, task) = App::with_config(
        cosmic::Core::default(),
        Flags::default(),
        config,
        Some(handler),
    );
    drop(task);
    (app, dir)
}

/// R5 settlement: `fl!` works without `i18n::init` — `LANGUAGE_LOADER` is a
/// `LazyLock` that loads the embedded en fallback on first use
/// (`src/i18n.rs:30–38`); `init` only *selects* additional languages
/// (`i18n.rs:14–18`). Construction exercises `fl!` through the About block
/// (`app.rs:311–316`).
#[test]
fn harness_app_constructs_headless_with_fl() {
    let app = test_app();
    assert_eq!(app.content.text(), "");
    assert_eq!(app.saved_text, "");
    assert!(!app.is_dirty());
    assert_eq!(
        app.config,
        Config {
            color_scheme: ColorScheme::Light,
            ..Default::default()
        }
    );
    assert!(app.config_handler.is_none());
    // The fallback (en) bundle is loaded lazily; no init call needed:
    assert!(!fl!("app-title").is_empty());
    assert!(!fl!("untitled").is_empty());
}

/// Message driving with a `None` handler: state flips in memory and
/// `persist_config` no-ops without panic or disk access.
#[test]
fn update_drives_state_without_config_handler() {
    let mut app = test_app();
    assert!(!app.config.word_wrap);
    drop(app.update(Message::ToggleWrap));
    assert!(app.config.word_wrap);
    drop(app.update(Message::ToggleWrap));
    assert!(!app.config.word_wrap);
    assert!(!app.is_dirty(), "wrap toggle must not dirty the document");
}

/// `app_with_text` round-trip: the document holds the text, starts clean,
/// and an edit makes it dirty.
#[test]
fn app_with_text_starts_clean_and_tracks_dirt() {
    let mut app = app_with_text("hello\nworld");
    assert_eq!(app.content.text(), "hello\nworld");
    assert_eq!(app.saved_text, "hello\nworld");
    assert!(!app.is_dirty());
    app.content
        .perform(Action::Edit(Edit::Paste(Arc::new(" x".to_string()))));
    assert!(app.is_dirty());
}

/// Seam + `with_custom_path` end-to-end: driving `ToggleWrap` writes the
/// per-key RON file under the tempdir — the mechanism T12's persistence and
/// invalid-config tests build on.
#[test]
fn toggle_wrap_persists_to_tempdir_ron() {
    let (mut app, dir) = app_with_tempdir_config("persist");
    drop(app.update(Message::ToggleWrap));
    assert!(app.config.word_wrap);
    let key = dir
        .path()
        .join("cosmic")
        .join(App::APP_ID)
        .join(format!("v{}", Config::VERSION))
        .join("word_wrap");
    assert!(key.is_file(), "key file {key:?} should exist");
    assert_eq!(std::fs::read_to_string(&key).unwrap().trim(), "true");
}

/// R15 settlement: the synthetic main-window id is `window::Id::RESERVED` —
/// the framework's own choice for the main window
/// (`libcosmic:src/app/mod.rs:112,117`, `iced/core/src/window/id.rs:15`).
/// `Core::set_main_window_id` is a public pure swap
/// (`libcosmic:src/core.rs:459–462`) and `main_window_id()` filters
/// `Id::NONE` (`core.rs:453–455`), so default-`Core` tests take
/// `update_title`'s `Task::none()` branch (`app.rs:1033–1037`) while this one
/// exercises the `set_window_title` branch — task constructed lazily and
/// dropped, header title assertable via `core.window.header_title`
/// (`libcosmic:src/core.rs:31,99`).
#[test]
fn update_title_sets_header_title_with_reserved_window_id() {
    let mut app = test_app();
    let expected = format!("{} — {}", fl!("untitled"), fl!("app-title"));

    // Default Core: no window id — the title task short-circuits, but the
    // header title is still set.
    assert!(app.core.main_window_id().is_none());
    drop(app.update_title());
    assert_eq!(app.core.window.header_title, expected);

    // Synthetic id: set_window_title branch constructs + drops headlessly.
    assert_eq!(
        app.core.set_main_window_id(Some(window::Id::RESERVED)),
        None,
        "previous id was unset"
    );
    assert_eq!(app.core.main_window_id(), Some(window::Id::RESERVED));
    drop(app.update_title());
    assert_eq!(app.core.window.header_title, expected);
}
