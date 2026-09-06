# Fix NotePad 3.0.0 bugs

## Context

NotePad 3.0.0 is a libcosmic rewrite (`src/app.rs`, `src/commands.rs`, `src/single_instance.rs`, Flatpak manifest). A full read of the app found several correctness bugs: unsaved work can be discarded on window close, Save-then-New/Open/Exit is dropped for untitled documents, the second-instance socket can fail open, and find/status/undo helpers mishandle UTF-8 and editor state.

This plan only covers real defects. Toolkit limits (no native edit-blocks, COSMIC look rather than XP) stay out of scope.

## Approach

Fix in dependency order so later changes can reuse earlier helpers:

1. Make document text and dirty-state round-trip through `Content` (so close/save/undo see the same string the editor stores).
2. Make close and “save changes?” actually complete the intended follow-up action.
3. Stop the Unix-socket listener from dropping the second launch.
4. Correct find/go-to/status offsets and the remaining UI/config/packaging bugs.

Keep find/replace/go-to logic in `commands.rs` so `cargo test` can cover the UTF-8 cases without a GUI.

## Bugs to fix

### P0 — data loss / broken document workflow

1. **Window close ignores unsaved changes.** `on_close_requested` runs on `SurfaceClosed` *after* the window is gone, and `main.rs` leaves `Settings.exit_on_close` at the default `true`, so libcosmic then calls `iced::exit()`. The COSMIC header close path is `Action::Close` → `on_app_exit()` (currently the default `None`) → close immediately. File → Exit is guarded; the window close button is not. README claims unsaved-change protection on close.

2. **Save in the unsaved dialog does not continue New/Open/Exit for untitled files.** `Message::DialogSave` calls `save(false)`, which returns a *future* Save As task. `is_dirty()` is still true, so `after` is stuffed back into `pending`. After `SaveSelected`/`write_to` succeeds, `after` is never run. The user saves, then stays in the same document instead of new/open/close.

3. **Save errors are swallowed by that same path.** `write_to` sets `PendingDialog::Error`, then `DialogSave` overwrites `pending` with `SaveChanges` again.

4. **New/empty documents can look dirty immediately.** Dirty is `content.text() != saved_text`. `reset_document` sets `saved_text` to `""` and `load_path` stores the raw file bytes. iced’s `Content::text()` historically normalizes trailing newlines / CRLF. If the editor’s string differs from the file bytes, opening or even an empty Untitled prompts to save. After load/new, `saved_text` must be `content.text()`.

### P1 — second instance, undo, search/status

5. **Single-instance ack is racy.** The listener is non-blocking, then `read_to_end` on the accepted `UnixStream`. That returns `WouldBlock` if the payload is not already complete, so no ack is written, `forward()` fails after 2s, and a second window starts. Empty second launches also never raise the first window.

6. **Undo/Redo wipe caret and selection.** `Content::with_text` rebuilds the buffer at offset 0. Snapshots also copy the whole document on every `Action` with `is_edit()`, which is harsh on large files but the user-visible bug is the lost caret.

7. **`line_col_at` on a mid-character offset uses the whole string.** `commands.rs` falls back to `text` instead of snapping to a char boundary, so Ln/Col and find ranges can jump to the end of the file on UTF-8 text.

8. **`offset_at_line_col` does not clamp to the requested line.** A column past the line length walks into later lines and can return `text.len()`. Status bar and find-from-cursor then disagree with the caret.

9. **`find_from` returns `None` when `start` is not a char boundary** instead of snapping forward, so Find Next can miss matches after a UTF-8 caret.

### P2 — correctness / packaging

10. **Menu Delete is a no-op without a selection.** Classic Notepad deletes the next character. Use the editor `Edit::Delete` action either way.

11. **`font_from_family` leaks** via `Box::leak` on every Apply Font / `UpdateConfig`. Intern names (static `OnceLock`/`HashSet`) and only leak each unique family once.

12. **`UpdateConfig` does not apply a scheme change** (no `command::set_theme`). External/cosmic-config updates leave Light/Dark/System stale.

13. **Flatpak config is read-only on the host cosmic dir.** `--filesystem=xdg-config/cosmic:ro` lets the app read the desktop theme but `persist_config()` writes into that tree and is ignored (`let _ = write_entry`). Word wrap, font, status bar, and scheme will not stick in Flatpak. Use `:rw` (same pattern as other COSMIC apps).

14. **Save As default name is hardcoded `Untitled.txt`**, not the localized untitled label.

15. **Go To out-of-range replaces the Go To dialog with a generic error**, so the user loses the line field. Keep `PendingDialog::GoTo` and set `error` (same as invalid number).

16. **AppStream release date for 3.0.0 is `2026-04-13`, before 2.0.x dates.** Sort/date 3.0.0 after 2.0.4.

17. **Format and View menu labels do not line up.** libcosmic only reserves a 16px check column on `Item::CheckBox`. Format mixes Word Wrap (checkbox) with Font (button); View mixes Status Bar (checkbox) with Color Scheme (folder). Command, disabled, and folder rows must use the same gutter so every menu shares one label column.

## Files to modify

- `src/main.rs` — `Settings.exit_on_close(false)` so a close request can be intercepted; pair with `on_app_exit` so a clean close still exits.
- `src/app.rs` — close hooks, pending-after-save, dirty snapshot from `Content::text()`, undo caret, Delete, font intern, `UpdateConfig` theme, localized Save As name, Go To error.
- `src/commands.rs` — boundary-safe `line_col_at` / `offset_at_line_col` / `find_from`; unit tests.
- `src/single_instance.rs` — blocking or tokio read on accepted connections; ack; yield a present/focus event when the payload is empty; unlink socket on drop if practical.
- `com.goshapps.Notepad.json` — `xdg-config/cosmic:rw`.
- `data/com.goshapps.Notepad.metainfo.xml` — 3.0.0 release date.
- `tests/packaging.rs` — only if the Flatpak assertion should lock `:rw`.

## Reuse

- Existing `AfterSave` / `PendingDialog::SaveChanges { after }` — keep the enum; add `pending_after: Option<AfterSave>` (or restore `after` only after a successful `write_to`).
- `guard_unsaved` / `proceed` / `write_to` — extend, do not replace.
- `commands` tests — add UTF-8 / clamp cases next to the current find/replace/go-to tests.
- `offset_to_position` in `app.rs` already snaps to a char boundary; mirror that in `line_col_at`.

## Implementation checklist

- [x] Snapshot dirty state from the editor: after `Content::new()` / `with_text()`, set `saved_text = self.content.text()`. Use that in `reset_document` and `load_path`.
- [x] Intercept close: implement `on_app_exit` to return `Some(Message::Exit)` when dirty (and when a save dialog is already up, keep it). Set `exit_on_close(false)` in `main.rs`. `on_close_requested` should not race `iced::exit()`; with exit-on-close off, return `Message::Exit` when dirty so winit close requests are handled the same as File → Exit. After a successful close (`proceed(AfterSave::Close)`), actually close the window.
- [x] Fix DialogSave: remember `after` across the Save As task. On successful `write_to`, if `pending_after` is set, `proceed` it. On save error, show `PendingDialog::Error` and keep `pending_after` so Retry/Save still knows what to do next. Cancel clears `pending_after`.
- [x] Single-instance: after `accept`, read the connection to EOF without treating `WouldBlock` as failure (set the client stream blocking, or `tokio::net::UnixListener`). Always ack. Map an empty payload to a focus/present message (`window::gain_focus` / equivalent) instead of ignoring it. Unlink the socket when the listener ends.
- [x] Undo/Redo: store `(text, cursor)` (position + selection) on the stacks; after `with_text`, `move_to` the saved cursor. Keep whole-buffer snapshots (toolkit has no edit blocks); optional later: skip pushing if the new snapshot equals the last.
- [x] `commands::line_col_at`: clamp offset to `text.len()` and the previous char boundary, never substitute the whole string.
- [x] `commands::offset_at_line_col`: if the column is past the end of `line`, return the byte offset of that line’s newline (or EOF on the last line), not a later line.
- [x] `find_from`: if `start < len` and not a char boundary, advance to the next boundary; only return `None` when `start > len`.
- [x] `Message::Delete`: always `push_undo` + `Action::Edit(Edit::Delete)` (selection or forward char).
- [x] Intern font family strings; stop leaking on every config apply.
- [x] `UpdateConfig`: if `color_scheme` changed, return `command::set_theme(theme_for(...))`; still refresh `editor_font`.
- [x] Save As fallback name from `fl!("untitled")` + `.txt`.
- [x] Out-of-range Go To sets `PendingDialog::GoTo { error: line-beyond-end }` instead of replacing the dialog.
- [x] Flatpak `finish-args`: `--filesystem=xdg-config/cosmic:rw`.
- [x] Metainfo 3.0.0 date after 2.0.4 (use a current/release date, not 2026-04-13).
- [x] Reserve the check column on every menu item (CheckBox(false) for commands, custom gutter for disabled Go To and the Color Scheme folder) so Format/View labels line up with File/Edit/Help.
- [x] Document 3.0.0 in README, AppStream, and the rewrite/bugfix plans: aligned menus, close/save follow-through, second-instance focus, UTF-8 find/status, undo caret, Flatpak config.

## Verification

- `cargo test --locked` — existing command tests plus new cases:
  - `line_col_at` mid-UTF-8 offset does not jump to EOF
  - `offset_at_line_col` past end of line stays on that line
  - `find_next` still wraps; a start offset inside a multibyte char still finds a later match
- `cargo clippy --locked -- -W clippy::pedantic` on touched files
- Manual:
  - Type in Untitled, click window close → Save/Discard/Cancel; Cancel leaves the window open; Discard exits; Save on untitled opens Save As then exits
  - Dirty file, File → New → Save → document actually resets
  - Open a UTF-8 file (`é`, `日本語`); Ln/Col and Find Next stay correct
  - Undo after typing restores caret, not just text
  - Second `notepad path.txt` while running forwards the path; second `notepad` with no args focuses the first window and does not start another process
  - Delete with no selection deletes one character
  - Flatpak: toggle wrap/scheme, restart, settings persist
  - Format: Word Wrap and Font… labels share one left edge; View: Status Bar and Color Scheme do too; File/Edit/Help match that indent
