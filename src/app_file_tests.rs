// SPDX-License-Identifier: GPL-3.0-or-later

//! File-lifecycle tests (T03; extended by T11 per PLAN — early creation
//! approved by the reviewer in the T03 window). Covers the D8 strict-UTF-8
//! load contract (DECISIONS.md; v2 parity `v2.0.4:src/window.py:618–628`)
//! and the D14 byte-fidelity locks (CRLF and mixed endings must round-trip
//! load→save byte-identically).
//!
//! Drives `load_path`/`write_to` directly (private methods, §3.4
//! child-module pattern); message-level flows (Open/Save dialogs, AfterSave
//! routing) belong to T11. Per the reviewer's T03 sign-off conditions: both
//! error arms share ux's single ruled composition, and failed loads seed
//! undo AND redo non-empty through the real `update` arms so the
//! state-untouched asserts prove the absence of a `clear()`, not merely
//! emptiness; the success arm proves both stacks cleared.

use super::app_test_harness::{app_with_text, test_app, test_tempdir};
use super::*;
use cosmic::Application; // trait methods don't propagate through `use super::*` globs

/// Seeds both stacks non-empty through the real update arms
/// (Paste → Paste → Undo): undo keeps the first snapshot, redo the undone
/// state (`app.rs:566–583`, `:624–632`).
fn seed_undo_redo(app: &mut App) {
    let paste = |s: &str| Message::Editor(Action::Edit(Edit::Paste(Arc::new(s.to_string()))));
    drop(app.update(paste(" one")));
    drop(app.update(paste(" two")));
    drop(app.update(Message::Undo));
    assert_eq!(app.undo_stack.len(), 1, "seed: one undo entry");
    assert_eq!(app.redo_stack.len(), 1, "seed: one redo entry");
}

/// D8 spec test: `[0x66, 0x6f, 0x6f, 0xff, 0xfe]` ("foo" + invalid byte) is
/// rejected with the could-not-open dialog naming the file and the decode
/// problem; document, `saved_text`, `file_path`, title, undo and redo are all
/// untouched (v2's early-return parity, `window.py:618–628`).
#[test]
fn d8_invalid_utf8_rejects_with_dialog_and_untouched_state() {
    let dir = test_tempdir("d8");
    let bad = dir.path().join("bad.txt");
    std::fs::write(&bad, [0x66, 0x6f, 0x6f, 0xff, 0xfe]).unwrap();

    let mut app = app_with_text("existing doc");
    seed_undo_redo(&mut app);
    let prefix = fl!("could-not-open").to_string();
    let content = app.content.text();
    let saved = app.saved_text.clone();
    let title = app.core.window.header_title.clone();
    let undo_top = app.undo_stack.last().map(|(t, _)| t.clone());
    let redo_top = app.redo_stack.last().map(|(t, _)| t.clone());
    assert!(app.pending.is_none(), "seeded app has no dialog");

    drop(app.load_path(bad.clone()));

    match &app.pending {
        Some(PendingDialog::Error { message }) => {
            assert!(
                message.starts_with(prefix.as_str()),
                "dialog uses the could-not-open copy: {message:?}"
            );
            assert!(
                message.contains(bad.display().to_string().as_str()),
                "dialog names the file: {message:?}"
            );
            // ux's variant check: both `Utf8Error` renderings ("invalid
            // utf-8 sequence…" / "incomplete utf-8 byte sequence…") contain
            // lowercase "utf-8"; the spec bytes produce the former.
            assert!(
                message.to_lowercase().contains("utf-8"),
                "dialog names the decode problem: {message:?}"
            );
        }
        other => panic!("expected Error dialog, got {other:?}"),
    }
    assert_eq!(app.content.text(), content, "document untouched");
    assert_eq!(app.saved_text, saved, "saved_text untouched");
    assert!(app.file_path.is_none(), "file_path untouched");
    assert_eq!(app.core.window.header_title, title, "title untouched");
    assert_eq!(app.undo_stack.len(), 1, "undo stack untouched");
    assert_eq!(app.undo_stack.last().map(|(t, _)| t.clone()), undo_top);
    assert_eq!(app.redo_stack.len(), 1, "redo stack untouched");
    assert_eq!(app.redo_stack.last().map(|(t, _)| t.clone()), redo_top);
}

/// The extended IO arm (ux flag → OBJ-T03-1 option A → lead ruling →
/// reviewer acceptance): io-error dialogs must name the file, as v2's
/// `OSError` display did — Rust's `io::Error` Display alone omits it. Arm
/// behavior unchanged: pending-only, `Task::none()`.
#[test]
fn load_path_io_error_names_file() {
    let dir = test_tempdir("io-err");
    let missing = dir.path().join("missing.txt");

    let mut app = app_with_text("existing doc");
    seed_undo_redo(&mut app);
    let prefix = fl!("could-not-open").to_string();
    let content = app.content.text();
    let saved = app.saved_text.clone();
    let title = app.core.window.header_title.clone();
    let undo_len = app.undo_stack.len();
    let redo_len = app.redo_stack.len();
    let undo_top = app.undo_stack.last().map(|(t, _)| t.clone());
    let redo_top = app.redo_stack.last().map(|(t, _)| t.clone());

    drop(app.load_path(missing.clone()));

    match &app.pending {
        Some(PendingDialog::Error { message }) => {
            assert!(
                message.starts_with(prefix.as_str()),
                "dialog uses the could-not-open copy: {message:?}"
            );
            assert!(
                message.contains(missing.display().to_string().as_str()),
                "dialog names the file: {message:?}"
            );
            assert!(
                message.contains("No such file or directory"),
                "dialog carries the io error detail: {message:?}"
            );
        }
        other => panic!("expected Error dialog, got {other:?}"),
    }
    assert_eq!(app.content.text(), content, "document untouched");
    assert_eq!(app.saved_text, saved, "saved_text untouched");
    assert!(app.file_path.is_none(), "file_path untouched");
    assert_eq!(app.core.window.header_title, title, "title untouched");
    assert_eq!(app.undo_stack.len(), undo_len, "undo stack untouched");
    assert_eq!(app.undo_stack.last().map(|(t, _)| t.clone()), undo_top);
    assert_eq!(app.redo_stack.len(), redo_len, "redo stack untouched");
    assert_eq!(app.redo_stack.last().map(|(t, _)| t.clone()), redo_top);
}

/// D14 lock: CRLF content round-trips load→save byte-identically. iced maps
/// per-line `LineEnding`s and rejoins without normalizing
/// (`libcosmic:graphics/src/text/editor.rs:120–131`,
/// `libcosmic:widget/src/text_editor.rs` — hand-traced against these exact
/// bytes in the T03 window); this test is the definitive lock.
#[test]
fn load_save_round_trip_preserves_crlf_bytes() {
    let dir = test_tempdir("crlf");
    let path = dir.path().join("crlf.txt");
    let bytes = b"a\r\nb\r\n";
    std::fs::write(&path, bytes).unwrap();

    let mut app = test_app();
    drop(app.load_path(path.clone()));
    assert_eq!(app.content.text(), "a\r\nb\r\n", "CRLF survives load");
    assert_eq!(app.saved_text, "a\r\nb\r\n");
    assert_eq!(app.file_path.as_deref(), Some(path.as_path()));
    assert!(!app.is_dirty());

    drop(app.write_to(path.clone()));
    assert_eq!(std::fs::read(&path).unwrap(), bytes, "CRLF survives save");
    assert!(!app.is_dirty(), "save leaves the document clean");
}

/// D14 lock, mixed endings: per-line endings survive individually
/// (CrLf then Lf; the last line carries no trailing separator).
#[test]
fn load_save_round_trip_preserves_mixed_endings() {
    let dir = test_tempdir("mixed");
    let path = dir.path().join("mixed.txt");
    let bytes = b"a\r\nb\nc";
    std::fs::write(&path, bytes).unwrap();

    let mut app = test_app();
    drop(app.load_path(path.clone()));
    assert_eq!(
        app.content.text(),
        "a\r\nb\nc",
        "mixed endings survive load"
    );

    drop(app.write_to(path.clone()));
    assert_eq!(
        std::fs::read(&path).unwrap(),
        bytes,
        "mixed endings survive save"
    );
    assert!(!app.is_dirty());
}

/// Success-arm regression guard (the arm is byte-identical through T03):
/// document/saved/path/title set, both stacks cleared, no dialog.
#[test]
fn load_path_success_sets_document_and_title() {
    let dir = test_tempdir("load-ok");
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "hello world").unwrap();

    let mut app = app_with_text("stale content");
    drop(
        app.update(Message::Editor(Action::Edit(Edit::Paste(Arc::new(
            " x".to_string(),
        ))))),
    );
    assert!(!app.undo_stack.is_empty(), "seeded");

    drop(app.load_path(path.clone()));

    assert_eq!(app.content.text(), "hello world");
    assert_eq!(app.saved_text, "hello world");
    assert_eq!(app.file_path.as_deref(), Some(path.as_path()));
    assert!(!app.is_dirty());
    assert!(
        app.undo_stack.is_empty() && app.redo_stack.is_empty(),
        "success clears both stacks"
    );
    assert!(app.pending.is_none());
    assert!(
        app.core.window.header_title.contains("note.txt"),
        "title names the file: {}",
        app.core.window.header_title
    );
}
