# NotePad application inventory

Verified against the working tree on 2026-09-13 (HEAD fc30f76). Sources of
truth: `src/` code read in full, `cargo test --locked` (49 tests, all green,
run in a Fedora 44 container with cargo 1.98), the release binary run on the
live COSMIC/Wayland session, and the vendored libcosmic sources under
`vendor/`.

Status legend: **works** = implemented and verified; **limited** = implemented
with a narrower scope than the label suggests; **absent** = not implemented.

## Identity and packaging

| Item | Value | Verified |
|---|---|---|
| Name | NotePad | metainfo, desktop file, About drawer |
| App ID | `com.goshapps.Notepad` | `src/app.rs` `APP_ID`, `src/single_instance.rs`, manifest, desktop/metainfo |
| Binary | `notepad` | Cargo.toml package name, manifest `command`, desktop `Exec` |
| Version | 3.0.0 | Cargo.toml, metainfo `<release>`, About drawer |
| License | GPL-3.0-or-later | LICENSE (full text), COPYRIGHT, Cargo.toml |
| Repository | https://github.com/goshitsarch-eng/notepad | Cargo.toml `repository`, About link |
| Upstream toolkit | libcosmic pinned to `d4d71fd` | Cargo.toml `rev`, Cargo.lock, `tests/packaging.rs` pin |

## Window and shell

| Feature | Where | Implementation | Status |
|---|---|---|---|
| Single document window, 820×600 default | startup | `main.rs` `Settings::size` | works |
| Minimum window size 360×180 | always | `main.rs` `size_limits` | works |
| Menu bar: File / Edit / Format / View / Help | header start | `app.rs` `header_start` | works |
| Check column on every menu row | all menus | `Item::CheckBox` + `menu_check_gutter`/`aligned_folder`/`aligned_disabled_item` | works — command, toggle, and submenu labels share one indent |
| Light/Dark header button | header end | `header_end` → `Message::ToggleScheme`; label shows the target mode ("Dark" or "Light") with icon + tooltip | works |
| About context drawer | Help ▸ About NotePad | `context_drawer` → `context_drawer::about`: name, icon, version, Repository link (opens in browser via `open` crate), license | works; no author/comments fields populated |
| Title bar text | always | `update_title`: `"{name} — NotePad"`, `"•  "` prefix when dirty, `Untitled` when unnamed | works |
| Escape priority | keyboard | `on_escape`: open dialog → About drawer → find bar | works. With the editor focused, one Esc both unfocuses the editor **and** runs the chain (`Binding::Unfocus` deliberately doesn't capture the event, so `keyboard_nav` still fires). With a text field focused (find/replace/Go To inputs), Esc only unfocuses the field — a second Esc closes the bar/dialog |

## Menus

File: New (Ctrl+N), Open… (Ctrl+O), Save (Ctrl+S), Save As… (Ctrl+Shift+S),
Exit (Ctrl+Q).

Edit: Undo (Ctrl+Z), Redo (Ctrl+Y), divider, Cut (Ctrl+X), Copy (Ctrl+C),
Paste (Ctrl+V), Delete (Del), divider, Find… (Ctrl+F), Find Next (F3),
Replace… (Ctrl+H), Go To… (Ctrl+G) — greyed out while Word Wrap is on,
Select All (Ctrl+A), Time/Date (F5).

Format: Word Wrap (check, persisted), Font… (dialog).

View: Status Bar (check, persisted), Color Scheme ▸ System / Light / Dark
(radio checks, persisted).

Help: About NotePad.

## Editing and document behavior

| Feature | Implementation | Status / limits |
|---|---|---|
| Undo / Redo | whole-document snapshot stacks `(String, Cursor)` | works; **capped at 100 entries**; restores caret+selection; any edit clears redo |
| Cut / Copy | `content.selection()` + `iced::clipboard` | works; no-op with empty selection |
| Paste | `clipboard::read` → `Edit::Paste` | works |
| Delete | `Edit::Delete` | works; deletes selection, else the next character. Menu Delete pushes an undo snapshot even when nothing was deleted (a no-op entry) |
| Select All | `Action::SelectAll` | works |
| Dirty tracking | `content.text() != saved_text` | works; drives the `•` title marker and the unsaved-changes guard |
| Line endings | per-line endings kept by the cosmic-text buffer | works; CRLF and mixed endings round-trip **byte-identically** through load→save (locked by tests) |
| Charset | `String::from_utf8` strict | **UTF-8 only.** Invalid bytes (e.g. Latin-1/CP1252 files) → "Could not open file" error dialog naming the file; document untouched |
| Drag-and-drop of files | none | absent |
| Editor right-click menu | libcosmic `text_editor` default (`has_context_menu: true`; app never disables it) | works — Cut / Copy / Paste / Select All, fed through the app's undo stack. Strings are hardcoded English inside libcosmic |

## Find / Replace / Go To

| Feature | Implementation | Status / limits |
|---|---|---|
| Find bar | `find_bar()` — close ✕ button, text field, "Match case" checkbox, "Find Next" button | works; Enter in the field = Find Next |
| Find Next | `commands::find_next`, case-insensitive by default, **wraps around** | works; F3 / button / Enter |
| Match case | `match_case` flag → case-sensitive byte compare | works |
| Not found | `PendingDialog::Error` "Cannot find …" | works |
| Prefill | selected single-line text seeds the find field on Ctrl+F / Ctrl+H | works |
| Replace | `replace_and_find_next`: replaces only if the current selection matches, then selects the next match; otherwise just selects the next match | works; Enter in the Replace field = Replace; no direction toggle |
| Replace All | `commands::replace_all` → one `Content::with_text`, one undo step | works |
| Go To | `PendingDialog::GoTo` line-number dialog, prefilled with the caret's line; inline errors for non-numeric input and out-of-range | works; **disabled while Word Wrap is on** (menu item greyed, Ctrl+G unbound) — deliberate Windows-Notepad parity |
| Case folding | `char::to_lowercase` compare | limited: not full Unicode `casefold`; only affects exotic case pairs |

## Files and dialogs

| Feature | Implementation | Status / limits |
|---|---|---|
| Open / Save As dialogs | `cosmic::dialog::file_chooser` (XDG portal) | works; filters "Text files" `*.txt` and "All files" `*`; Open starts in the current file's directory; Save As prefills the file name (or `Untitled.txt`) |
| Unsaved-changes guard | `guard_unsaved` + `PendingDialog::SaveChanges` | works on New, Open, Exit, window ✕, and second-instance file opens. Save → may open Save As, then **continues the original action**; Discard proceeds; Cancel aborts. Clicking the window ✕ while the prompt is already open retargets it to Close; a failed save re-raises the prompt when its error dialog is dismissed |
| Error dialogs | `PendingDialog::Error` | works; load errors name the file; save errors show the OS error (but do **not** name the file — `write_to` arm) |
| Multiple files on the command line | `Flags.files.first()` only | **only the first file opens**; extra paths are ignored |
| CLI flags | none — `std::env::args` entries starting with `-` are skipped | `notepad --help` launches the GUI on a cold start, or focuses the running window (it forwards an empty payload); it never prints help |

## Keyboard shortcuts

`key_bind.rs` maps `KeyBind → MenuAction`; the menu uses it **only to render
shortcut labels** (`menu_items` → `find_key` → `KeyBind::to_string`) — this
libcosmic rev has no menu-level dispatcher.

Actual dispatch is `editor_key_binding` in `app.rs`, installed on the editor
via `.key_binding(...)`. The editor widget calls it on **every** `KeyPressed`
event that reaches it, with no focus gate of its own — and iced broadcasts
key events to the whole widget tree. Consequences:

- The app's custom-bound shortcuts — Ctrl+N/O/S/Shift+S/Q, Ctrl+Z/Y/Shift+Z,
  Ctrl+F, F3, Ctrl+H, Ctrl+G, F5 — fire **app-wide**, including while typing
  in the Find/Replace fields (F5 will insert a timestamp into the document
  mid-search). `editor_key_binding` ignores `press.status`.
- The arms not claimed by the app fall through to iced's
  `Binding::from_key_press`, which requires `Status::Focused` — so
  Ctrl+X/C/V/A, Delete, Shift+Insert/Delete, Ctrl+Insert, and all
  movement/selection keys act on whichever widget has focus (editor or a
  text field).
- While a modal dialog is open (Save changes, Go To, Font, Error), the
  popover swallows keyboard events before they reach the editor — no menu
  shortcuts fire; Esc still closes the dialog via the app-level
  `keyboard_nav` subscription.
- Ctrl+letter binds match `press.key` (layout-dependent), not the physical
  key — on non-Latin keyboard layouts the Ctrl+letter shortcuts don't fire.
- The old migration plan's "G-1: shortcuts fire only with editor focus" gap
  (fix task T21) was a misdiagnosis — the custom binds were already global.

| Shortcut | Action |
|---|---|
| Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S / Ctrl+Q | New / Open / Save / Save As / Exit |
| Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z | Undo / Redo / Redo |
| Ctrl+X / Ctrl+C / Ctrl+V | Cut / Copy / Paste |
| Shift+Delete, Ctrl+Insert, Shift+Insert | Cut, Copy, Paste (editor defaults) |
| Delete | Delete selection or next char |
| Ctrl+F / F3 / Ctrl+H / Ctrl+G | Find / Find Next / Replace / Go To |
| Ctrl+A | Select All |
| F5 | Insert time/date (`h:MM AM/PM M/D/YYYY`) |
| Esc | close dialog / drawer / find bar; unfocus editor |
| Ctrl+arrows, Home/End, Shift+motions | standard iced editor movement/selection |

## Settings and persistence

Config is a `cosmic-config` entry (`Config` v1). Each key is stored as its own
RON file under `~/.config/cosmic/com.goshapps.Notepad/v1/` — the same
`cosmic/` config tree the COSMIC desktop uses, including inside the Flatpak
(the `--filesystem=xdg-config/cosmic:rw` finish-arg maps the host directory).
The app **live-reloads** external edits via `watch_config`.

| Key | Type | Default | Set from |
|---|---|---|---|
| `color_scheme` | `system` \| `light` \| `dark` | `system` | View ▸ Color Scheme, header button |
| `word_wrap` | bool | `false` | Format ▸ Word Wrap |
| `show_status_bar` | bool | `true` | View ▸ Status Bar |
| `font_family` | string | `monospace` | Format ▸ Font… |
| `font_size` | u16 | `14` | Format ▸ Font… |

Malformed config values fall back to field defaults.

## Appearance

- System scheme follows the desktop (`cosmic::theme::system_preference`),
  re-evaluated on system theme changes.
- Light/Dark are pinned independent palettes (`pin_independent` converts
  `ThemeType::System` to `Custom`) so they don't get overwritten by the desktop.
- Widgets use libcosmic semantic theme tokens; no hardcoded colors.
- Font: Format ▸ Font… — dropdown of 14 curated families **plus a free-text
  field** (any family name the font system can resolve), size dropdown
  8–36 pt. No live preview; applied on OK. Edge cases: a custom family name
  leaves the family dropdown showing index 0 while the text field shows the
  real name; a persisted `font_size` outside the list snaps to 14 when the
  dialog opens.

## Single instance and session integration

- Unix socket at `$XDG_RUNTIME_DIR/com.goshapps.Notepad.sock`
  (falls back to the temp dir). Wire protocol: newline-separated paths, one
  ack byte.
- Second `notepad file.txt` → forwards the path to the running window (which
  gains focus and runs the unsaved-changes guard before loading) and exits.
  Verified live: forwarded launch returned in ~2 ms.
- Second `notepad` with no args → empty payload, running window is focused.
- Stale socket files are unlinked before binding; the socket is removed on
  exit (drop guard).
- If the socket exists but the listener is unreachable, the forward fails and
  a second window starts — same failure class as the Qt version (accepted).

## Desktop integration

- `.desktop`: `Exec=notepad %F`, `MimeType=text/plain`, categories
  `Utility;TextEditor;X-COSMIC`, so "Open With" works from file managers.
  In the Flatpak, file arguments arrive through the document portal (the app
  has **no** host-filesystem permission).
- i18n: Fluent via `i18n-embed` + `rust-embed`; **English is the only shipped
  locale** (`i18n/en/notepad.ftl`). Desktop language requester picks the
  session language automatically if a translation is added.
- Notifications: none. Background operations: none. Networking: none at
  runtime (the only outbound action is opening the repository URL in a
  browser from the About drawer).

## Flatpak

- Manifest `com.goshapps.Notepad.json`: `org.freedesktop.Platform//25.08` +
  `org.freedesktop.Sdk//25.08`, base `com.system76.Cosmic.BaseApp//stable`,
  SDK extensions `rust-stable` + `llvm21` (lld link via `RUSTFLAGS`).
- `branch: stable`, `command: notepad`.
- finish-args (6, pinned by `tests/packaging.rs`): `--share=ipc`,
  `--socket=fallback-x11`, `--socket=wayland`, `--device=dri`,
  `--talk-name=org.freedesktop.portal.Desktop`,
  `--filesystem=xdg-config/cosmic:rw`.
- Build is fully offline: `cargo build --release --frozen --offline` against
  the `dir` source. **`vendor/` + `.cargo/config.toml` must be materialized
  first by `scripts/vendor.sh`**; both are gitignored, so a clean checkout
  cannot build the Flatpak until they exist. Note `just vendor` is *not*
  equivalent — it ends with `rm -rf vendor`, leaving `.cargo/config.toml`
  pointing at a deleted directory (plain cargo commands then fail until
  `just vendor-extract` restores `vendor/` from the tar).
- `vendor.tar` is a local freshness cache keyed on `Cargo.lock` (gitignored,
  ~943 MB). `just clean-vendor` removes all three artifacts.
- Published package: the `gosh` remote (`flatpak.goshapps.com/repo`) serves
  **2.0.4** — the previous Qt build — as of 2026-09-13. 3.0.0 has no
  published Flatpak yet; building locally is the only way to run it.

## Tests

`cargo test --locked` → **49 tests, all green** (verified 2026-09-13, cargo
1.98 in Fedora 44 container):

- `src/commands.rs` — 21 tests: find/replace/go-to/caret math incl. UTF-8 and
  wrap-around cases.
- `src/single_instance.rs` — 5 tests: socket path, payload parse, client↔server
  round-trip incl. ack and stale-socket recovery.
- `src/app.rs` (+ `app_test_harness.rs`, `app_file_tests.rs`) — 13 tests:
  headless `App` construction, config persistence to a tempdir, title updates,
  strict-UTF-8 and IO-error load paths, CRLF/mixed-ending round-trips.
- `tests/packaging.rs` — 10 tests: license presence/install, version
  consistency across Cargo.toml/metainfo/README, manifest identity and
  finish-args ratchet, libcosmic rev pin.

The libcosmic migration plan (T09–T12, T14) called for additional
message-level suites (`app_edit_tests.rs`, `app_search_tests.rs`,
`app_settings_tests.rs`, `app_flow_tests.rs`) — **never landed**; those files
do not exist.

## Not implemented (was planned or could be assumed)

- Focus-follow into/out of the Find bar (migration tasks T18/T19) — the find
  field is not auto-focused on Ctrl+F (click or Tab into it), and focus is
  not returned to the editor on close.
- Greyed Cut/Copy/Delete/Undo/Redo menu items reflecting state (T20) — menu
  items are always enabled.
- Accessible names on the find-bar close button and scheme button
  (T15/T16) — `.name()` never added; `close-find` and `color-scheme-button`
  ftl keys exist but are unused, as are `app-comment`/`app-keywords`.
- About drawer author/comments/copyright (T17).
- `write_to` save-error dialog naming the file (T22).
- System font enumeration in the Font dialog (T23) — the family list is
  hardcoded.
- `scripts/verify.sh`, `scripts/smoke-test.sh`, `scripts/ci.sh`,
  `.github/workflows/` — none exist; only `scripts/vendor.sh` does.
- Printing, recent-files list, tabs, syntax highlighting — out of scope by
  design.
