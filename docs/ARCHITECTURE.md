# Architecture

NotePad is a single-window [libcosmic](https://github.com/pop-os/libcosmic)
(iced) application — `cosmic::Application` with one `Message` enum and one
`update` match. It is deliberately a monolith: `src/app.rs` holds the model,
the view, and all message handling (~1,500 lines).

```
src/main.rs            argv → Flags.files; single-instance forward-or-run;
                       window size/theme settings; cosmic::app::run
src/app.rs             App model + Message enum + update; menu bar, find bar,
                       dialogs, footer, context drawer; file load/save
src/commands.rs        pure text helpers: find_next (wrap/case), replace one/
                       all, goto_line, line/col ↔ byte-offset math
src/config.rs          cosmic-config entry: color_scheme, word_wrap,
                       show_status_bar, font_family, font_size
src/key_bind.rs        menu shortcut table (labels; dispatch is in app.rs)
src/single_instance.rs Unix-socket forward/accept (tokio listener as an iced
                       subscription); stale-socket cleanup
src/i18n.rs            Fluent loader (i18n-embed + rust-embed), fl! macro
```

## How the pieces fit

- **Editing state.** The document is `text_editor::Content`; dirtiness is
  `content.text() != saved_text`. Undo/redo are snapshot stacks of
  `(String, Cursor)` capped at 100 entries — iced's editor `Action`s have no
  native undo, so snapshots are the mechanism, not a workaround.
- **Unsaved-changes flow.** `guard_unsaved(after)` raises
  `PendingDialog::SaveChanges { after }`. `DialogSave` stores `after` in
  `pending_after`, then saves; `write_to` proceeds with it on success. This
  is what makes "Save" from the close prompt continue into New/Open/Exit.
- **Close path.** `main.rs` sets `exit_on_close(false)`; window-close and
  File ▸ Exit both become `Message::Exit` → `guard_unsaved(AfterSave::Close)`.
- **Shortcuts.** `key_bind.rs` builds the `KeyBind → MenuAction` map — but
  this libcosmic rev only uses it to *render* shortcut labels; there is no
  menu-level dispatcher. Real dispatch is `editor_key_binding`, which the
  editor widget consults on every `KeyPressed` event it sees — iced
  broadcasts events to the whole widget tree, so the app's custom arms
  (which don't check `press.status`) fire app-wide, including inside the
  Find/Replace fields. Modal dialogs swallow keyboard events before they
  reach the editor, so shortcuts go quiet while a dialog is open. The
  unmapped keys fall through to iced's `Binding::from_key_press`, which does
  require focus — Ctrl+X/C/V/A, Delete, and motion keys therefore act on
  whichever widget is focused.
- **Config.** `cosmic-config` writes one RON file per key under
  `~/.config/cosmic/com.goshapps.Notepad/v1/`; `watch_config` live-reloads
  external edits. In the Flatpak, `--filesystem=xdg-config/cosmic:rw` maps the
  same host directory, so native and sandboxed installs share settings.
- **Theme.** `theme_for` maps System → `system_preference`, Light/Dark →
  pinned palettes (`ThemeType::Custom`) so the desktop can't overwrite them.
- **Single instance.** First process binds
  `$XDG_RUNTIME_DIR/com.goshapps.Notepad.sock`; later launches write
  newline-separated paths, wait for a 1-byte ack, and exit. The running
  instance focuses its window and opens the first path (empty payload = just
  focus).
- **File IO.** Load is strict `String::from_utf8` — invalid bytes show an
  error dialog and leave the document untouched (re-saving a lossy decode
  would corrupt the file). Line endings are never normalized: the editor's
  per-line `LineEnding`s round-trip CRLF and mixed endings byte-identically.
- **Dialogs.** File open/save use `cosmic::dialog::file_chooser` (XDG portal),
  so they work inside the Flatpak without filesystem permissions; file
  arguments passed to the Flatpak arrive via the document portal.
- **i18n.** `fl!` resolves keys from `i18n/en/notepad.ftl`, embedded at
  compile time; the fallback bundle loads lazily, so `fl!` works in tests
  without `i18n::init`.

## Testing approach

`commands.rs` and the `App` model are testable without a display:
`App::with_config` is the seam that lets tests inject a config (or a
tempdir-backed handler) instead of touching `~/.config`. iced `Task`s are
lazy, so tests drive `update()` directly and assert on state. Packaging
invariants (manifest finish-args, version consistency, license install lines,
the libcosmic rev pin) are locked by `tests/packaging.rs`.

## Packaging

The Flatpak (`com.goshapps.Notepad.json`) builds fully offline:
`cargo build --release --frozen --offline` inside the sandbox against
`vendor/` + `.cargo/config.toml` produced by `scripts/vendor.sh` (a `dir`
source carries the materialized tree into the build). libcosmic is pinned by
`rev` in `Cargo.toml` so a lockfile regen can't drift to a new master.
`vendor.tar` is a gitignored local cache keyed on `Cargo.lock` freshness.
