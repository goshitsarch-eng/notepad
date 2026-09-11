# NotePad 3.0.0 — libcosmic Architecture (Phase 1)

Status: Phase 1 planning document (no source changes made). **Accepted by
lead 2026-09-11**; revised same day to fold in lead rulings: T1 scope +
`line_count` deletion, T2 sequenced before UX edits (no `app.rs` split),
T10 deferred reviewer-gated, tempdir decision (no new dev-dep), CRLF recorded
as DECISIONS D14. **Rev 2 (same day):** applies the Phase-1 review rulings
(`review-phase1.md`, verdict ACCEPT WITH OBJECTIONS): RV-1 (MenuAction map
demoted 🔒→🧪, test folded into T4/PLAN-T09), RV-3 (47-of-48 coverage
wording), RV-4 (F1→T6, F20→T7), RV-5 (invalid-config fallback test → T7 +
§5.6), RV-10 (focus → Phase-3 manual), RV-12 noted on T5. §2.3 is the
normative coverage list for the unit-test mandate.
Author: Architecture teammate. Date: 2026-09-11.
Companion docs: `DECISIONS.md` (D1–D14), `ux.md`, `packaging.md`, `PLAN.md`,
`plans/libcosmic-rewrite.md`, `plans/bugfix-pass.md`.

**Evidence conventions.** Every claim cites `file:line` against one of three
roots:

| Prefix | Root |
|---|---|
| (none) | repo working tree, `/home/gosh/Documents/GitHub/notepad`, branch `cosmic-migration` |
| `libcosmic:` | `~/.cargo/git/checkouts/libcosmic-41009aea1d72760b/d4d71fd/` (rev `d4d71fd53e5ed6bd3a430089114dffa2da3cd498`, verified pristine; vendored `iced/`, `cosmic-config/`, `cosmic-theme/` live inside the same checkout) |
| `v2.0.4:` | `/home/gosh/.cache/notepad-v2.0.4/` (extracted original Python/PySide6 source) |

Items that could not be fully verified by source reading are marked
**needs Phase 2 verification**.

---

## 1. Structure mapping: Qt v2.0.4 → libcosmic v3.0.0

### 1.1 Runtime model (one correction to the Phase-1 brief)

The brief described libcosmic's update entry point as taking a separate core
parameter. At this rev it does not: the `Application` trait
(`libcosmic:src/app/mod.rs:323–488`) declares

```rust
fn update(&mut self, message: Self::Message) -> Task<Self::Message>   // app/mod.rs:465
```

`cosmic::Core` is a **field of the app struct**, exposed through the required
`core()` / `core_mut()` methods (NotePad impl: `src/app.rs:293–299`). This
matters for testing: constructing `App` around `Core::default()` is sufficient
— there is no separate core object to thread into `update`.

Lifecycle: `cosmic::app::run::<App>(settings, flags)` (`src/main.rs:54`) builds
`Core` from `Settings`, calls `App::init(core, flags)`
(`libcosmic:src/app/mod.rs:348`; NotePad impl `src/app.rs:301–359`), and the
runtime (`libcosmic:src/app/cosmic.rs`) owns the event loop: it routes
`Action::App(msg)` to `app.update(msg)` (`cosmic.rs:512`), Escape to
`on_escape` (`cosmic.rs:887`), system theme changes to `system_theme_update`
(`cosmic.rs:922`), header-close to `on_app_exit` (`cosmic.rs:1081–1087`), and
window-surface-closed to `on_close_requested` (`cosmic.rs` dispatch +
`src/app.rs:890–899`). `Settings.exit_on_close(false)` (`src/main.rs:52`)
clears `Core.exit_on_main_window_closed` (set from Settings in
`libcosmic:src/app/mod.rs:62–72`), so a window close does **not** batch
`iced::exit` unconditionally (`libcosmic:src/app/cosmic.rs:1243–1252`) — the
unsaved-changes guard gets to run first. This is the linchpin of the
close/save parity behavior.

Qt's signals/slots are replaced by one `Message` enum (48 variants,
`src/app.rs:113–164`) and one `update` match (`src/app.rs:611–867`). Qt's
"call a method now" becomes "return a `Task`": `Task<M>` is
`iced::Task<crate::Action<M>>` (`libcosmic:src/app/mod.rs:18`), where
`Action<M> = App(M) | Cosmic(app::Action) | DbusActivation | None`
(`libcosmic:src/action.rs:23`). Tasks are **lazy and opaque** — nothing runs
until the runtime polls them (§3, §6-R2).

Qt timers/QSocketNotifier-style background work becomes **Subscriptions**:
`App::subscription()` batches config-watch, single-instance socket, and
window-close-request streams into `Message`s (`src/app.rs:600–608`).

### 1.2 Subsystem mapping table

| Subsystem | v2.0.4 (Qt/PySide6) | v3.0.0 (libcosmic/Rust) | Evidence |
|---|---|---|---|
| App object / entry | `NotepadApplication(QApplication)`; `main.py` | `cosmic::app::run::<App>` + `impl cosmic::Application` | `v2.0.4:src/application.py`, `v2.0.4:src/main.py`; `src/main.rs:29–55`, `src/app.rs:287–912` |
| Main window | `NotepadWindow(QMainWindow)` | `Core.window` + trait hooks `header_start/header_end/view/footer/dialog/context_drawer` | `v2.0.4:src/window.py`; `src/app.rs:361–598` |
| Event model | signals/slots | `Message` enum + `update()` match; runtime dispatch | `src/app.rs:113–164, 611–867`; `libcosmic:src/app/cosmic.rs:512` |
| Editor widget / document | `QPlainTextEdit` + `QTextDocument` | `text_editor::Content` (cosmic-text buffer) | `v2.0.4:src/window.py`; `src/app.rs:93, 331`; `libcosmic:iced/widget/src/text_editor.rs:397–501` |
| Dirty tracking | `modificationChanged` signal → title `•` | `is_dirty() = content.text() != saved_text`; title rebuilt in `update_title` | `src/app.rs:998–1000, 1022–1038` |
| Undo/redo | `QTextDocument` undo stack (`undoAvailable` signals) | snapshot stack `Vec<(String, Cursor)>`, cap 100 | `src/app.rs:107–108, 671–688, 1040–1047, 1444` |
| Settings | `QSettings("goshapps","notepad")`, key `color_scheme` only | cosmic-config `Config` v1, 5 fields, one RON file per key | `v2.0.4:src/theme.py` (`load/save_scheme`); `src/config.rs:16–36`; `libcosmic:cosmic-config/src/lib.rs:215–250` |
| Theme / color scheme | Fusion style + Breeze-like palettes; `system_is_dark` | `cosmic::Theme` via `theme_for` + `pin_independent`; `set_theme` task | `v2.0.4:src/theme.py`; `src/config.rs:44–58`; `libcosmic:src/command.rs:36` |
| File dialogs | `QFileDialog` (native) | xdg-portal `file_chooser` open/save, wrapped in lazy tasks | `src/app.rs:1327–1379`; `libcosmic:src/dialog/file_chooser/mod.rs:123` |
| Message boxes | `QMessageBox` (Save/Discard/Cancel, errors) | `PendingDialog` enum + `dialog()` hook | `src/app.rs:69–83, 457–549` |
| Font dialog | `QFontDialog` | `PendingDialog::Font` with dropdowns + free-text family | `src/app.rs:501–538, 782–803` |
| Go-To dialog | custom `GoToDialog(QDialog)`, modal, int validation | `PendingDialog::GoTo { input, error }`, in-dialog validation | `v2.0.4:src/window.py`; `src/app.rs:476–500, 738–766, 1207–1240` |
| Find / Replace | `FindBar` widget + modeless `ReplaceDialog` | in-view find bar (flex_row) + `commands.rs` pure helpers | `v2.0.4:src/window.py`, `v2.0.4:src/commands.py`; `src/app.rs:1049–1107`, `src/commands.rs` |
| Status bar | `QStatusBar` labels: wrap state + `Ln {l}, Col {c}` | `footer()` + `commands::caret_line_col` | `src/app.rs:551–573`; `src/commands.rs:221–245` |
| Single instance | `QSocketNotifier` + Unix socket, newline paths + 1-byte ack | `single_instance.rs`: tokio `UnixListener` subscription, identical wire protocol | `v2.0.4:src/application.py`; `src/single_instance.rs:20–118` |
| Clipboard | `QApplication.clipboard()` | iced `clipboard::read()/write()` tasks + `ClipboardPaste` message | `src/app.rs:689–712`; `libcosmic:iced/runtime/src/clipboard.rs:64, 84` |
| Menus / shortcuts | `QAction`s + `QMenu` (File/Edit/F&ormat/View/Help) | `menu::bar` + `key_binds` map + `editor_key_binding` | `src/app.rs:361–416, 1391–1411`; `src/key_bind.rs:10–96` (17 binds) |
| Time/Date insert (F5) | `datetime.now().strftime("%-I:%M %p %-m/%-d/%Y")` | `datetime_stamp()` (chrono), same fields | `v2.0.4:src/window.py`; `src/app.rs:768–773, 1446–1459` |
| Open-with argv | `main.py` → `open_paths` | `Flags.files` → synchronous `load_path` in `init` | `src/main.rs:33–37`; `src/app.rs:54–58, 354–356, 1269–1290` |
| Close guard | `closeEvent` → `_guard_unsaved(proceed)` | `Exit` message + `on_close_requested` + `guard_unsaved`/`proceed`/`AfterSave` | `v2.0.4:src/window.py`; `src/app.rs:60–67, 664–670, 890–899, 1242–1258` |
| i18n | Qt `.ts` / `tr()` | rust-embed fluent (`i18n/en/notepad.ftl`), `fl!` macro | `src/i18n.rs`; `i18n/en/notepad.ftl` |
| Packaging | KDE Flatpak, `io.qt.PySide.BaseApp` | `com.system76.Cosmic.BaseApp//25.08`, cargo release build | `com.goshapps.Notepad.json`; `tests/packaging.rs` |
| Tests | pytest: `tests/test_{application,window,commands,theme,packaging}.py` | inline `#[cfg(test)]`: 22 (`commands.rs:272–472`) + 3 (`single_instance.rs:120–183`) + 3 (`app.rs:1495–1527`); 6 packaging (`tests/packaging.rs`) | Appendix B maps old → new |

### 1.3 Notes per subsystem

**Document model.** `Content` is `RefCell<Internal<R>>` over a cosmic-text
buffer (`libcosmic:iced/widget/src/text_editor.rs:397`); in `App` the renderer
parameter defaults to `cosmic::Renderer` via the field type
(`src/app.rs:93`). Text construction/editing is CPU-only — `Editor::with_text`
builds a `cosmic_text::Buffer` against the global font system and shapes
(`libcosmic:iced/graphics/src/text/editor.rs:89–111`); no GPU or display is
involved. The editor `Action` vocabulary (`Move/Select*/Edit/Click/Drag/Scroll`,
`libcosmic:iced/core/src/text/editor.rs:70–94`) has **no native undo** — there
is no `Edit::Undo` (`Edit = Insert/Paste/Enter/Indent/Unindent/Backspace/Delete`,
`iced/core/src/text/editor.rs:105–120`) — which is why the snapshot undo stack
in `App` is not a workaround but a necessity.

**Dialog state machine.** v2.0.4's modal dialogs become a single
`Option<PendingDialog>` field (`src/app.rs:105`) rendered by the `dialog()`
hook (`src/app.rs:457–549`) and resolved by `DialogSave/DialogDiscard/
DialogCancel/CloseError/GoToConfirm/ApplyFont` messages. The
save-then-continue behavior of Qt's `_guard_unsaved(proceed)` is modeled
explicitly by `AfterSave` (`src/app.rs:60–67`) plus `pending_after`
(`src/app.rs:106`): the continuation survives across the asynchronous Save-As
portal round trip (`src/app.rs:830–835, 1299–1325`).

**Single instance.** The wire protocol is byte-for-byte the v2 one:
newline-joined paths, shutdown-write, 1-byte ack
(`src/single_instance.rs:49–68` vs `v2.0.4:src/application.py`
`forward_to_running_instance`/`_on_new_connection`). Stale-socket probing
matches too (`unlink_if_stale`, `src/single_instance.rs:71–81` vs v2's
probe-then-bind). The server side runs as an iced subscription with a tokio
listener (`src/single_instance.rs:95–118`) and maps to
`Message::OpenExternal` (`src/app.rs:605`).

**Theme.** `theme_for` (`src/config.rs:44–50`) maps System →
`cosmic::theme::system_preference()` and Light/Dark → `system_light()/
system_dark()` passed through `pin_independent` (`src/config.rs:52–58`), which
converts `ThemeType::System` to `ThemeType::Custom` so libcosmic does not
overwrite an explicit choice with the desktop palette (documented in the
in-source comment, `src/config.rs:38–42`; this was startup-theme bugfix commit
65a4ae1).

---

## 2. State model (coverage matrix source of truth)

All line numbers are `src/app.rs` unless noted. This section is the normative
coverage matrix for the mandated unit tests: **every `Message` variant that
`update()` handles** appears in §2.3 with its behavior, returned `Task`, and
the state assertions that pin it.

### 2.1 `App` struct fields (24)

| Field | Type | Purpose | Written by |
|---|---|---|---|
| `core` (87) | `cosmic::Core` | window/theme/config-watch state; `core()`/`core_mut()` (293–299) | framework + `ToggleContextPage` (813–820), `update_title` via `set_header_title` (1032) |
| `about` (88) | `About` | About drawer data | `init` only (311–316) |
| `context_page` (89) | `ContextPage` (166–170, only `About`) | which drawer page | `ToggleContextPage` (813–820) |
| `key_binds` (90) | `HashMap<menu::KeyBind, MenuAction>` | menu shortcut map, 17 binds (`src/key_bind.rs:10–96`) | `init` (322) |
| `config` (91) | `Config` (`src/config.rs:16–24`) | persisted settings (5 fields) | toggles/Font/Scheme/`UpdateConfig` (774–812, 850–857) |
| `config_handler` (92) | `Option<cosmic_config::Config>` | write handle; `None` ⇒ persistence no-ops (1010–1014) | `init` (302–309) |
| `content` (93) | `text_editor::Content` | the document | every editing path |
| `file_path` (94) | `Option<PathBuf>` | current file | `load_path` (1278), `write_to` (1303), `reset_document` (1263) |
| `saved_text` (95) | `String` | last-saved snapshot; dirty = `content.text() != saved_text` (998–1000) | `init` (347), `load_path` (1277), `write_to` (1304), `reset_document` (1262), `DialogDiscard` (839) |
| `editor_font` (96) | `Font` | resolved from `config.font_family` | `init` (323), `ApplyFont` (800), `UpdateConfig` (853) |
| `find_visible` (97) / `replace_visible` (98) | `bool` | find-bar visibility | `Find/Replace/CloseFind/on_escape` (718–734, 879–882) |
| `find_text` (99) / `replace_text` (100) / `match_case` (101) | `String`/`bool` | search state | 735–737, prefill (1109–1116) |
| `goto_input` (102) | `String` | Go-To field (init `"1"`, 340) | `GoTo` (748), `GoToInput` (755–765) |
| `font_family_input` (103) / `font_size_index` (104) | `String`/`usize` | Font dialog scratch state | `Font` (782–789), `FontFamily/FontSize/FontFamilyInput` (790–796) |
| `pending` (105) | `Option<PendingDialog>` (69–83) | modal dialog state machine | many (see matrix) |
| `pending_after` (106) | `Option<AfterSave>` (60–67) | deferred continuation across Save-As | `DialogSave` (832), `write_to` (1306), `DialogCancel/Cancelled/DialogDiscard` (828, 838, 862) |
| `undo_stack` / `redo_stack` (107–108) | `Vec<(String, Cursor)>` | snapshot undo, cap `MAX_UNDO_DEPTH = 100` (1444) | 613–630, 671–688, `push_undo` (1040–1047); cleared by load/reset (1264–1265, 1279–1280) |
| `font_family_labels` / `font_size_labels` (109–110) | `Vec<String>` | dropdown labels from `FONT_FAMILIES` (35–50, 14 entries) / `FONT_SIZES` (52, 14 entries) | `init` (344–345) |

### 2.2 Supporting types

- `AfterSave` (60–67): `New | Open | OpenPath(PathBuf) | Close` — the
  continuation queued behind the unsaved-changes guard.
- `PendingDialog` (69–83): `SaveChanges{after} | GoTo{input, error} | Font |
  Error{message}` — inspectable in tests (derives `Debug`; matching on it is
  the primary assertion seam for dialog flows).
- `ContextPage` (166–170): only `About` (single-variant; drawer toggle state
  actually lives in `core.window.show_context`, 813–820).
- `MenuAction` (172–196, 22 variants) → `Message` mapping (198–227); pure data,
  exercised by menu construction only.
- `Config` / `ColorScheme` (`src/config.rs:7–36`): see §5.
- `Flags { files: Vec<PathBuf> }` (54–58): argv handoff from `src/main.rs:33–37`.

### 2.3 Message coverage matrix (48 variants)

"Task" column = what `update()` returns; **none** = `Task::none()` via the
fall-through at 866. `update_title()` (1022–1038) always sets
`core.window.header_title` and returns a `set_window_title` task **only if**
`core.main_window_id()` is `Some` — headless tests get `Task::none()` and can
assert `header_title`. Every returned `Task` is lazy and safe to drop (§3.2).

| # | Variant (line) | update() behavior | Task | Test assertions |
|---|---|---|---|---|
| 1 | `Editor(Action)` (613–630) | if `action.is_edit()`: snapshot (text, cursor) → `perform` → if text changed push undo (cap 100, evict oldest, clear redo); non-edit actions just `perform` | `update_title()` | content text/cursor; undo/redo stack contents + cap; `header_title` dirty marker `•` (1030) |
| 2 | `New` (631) | `guard_unsaved(AfterSave::New)` (1242–1249): dirty ⇒ `pending=SaveChanges{New}`; clean ⇒ `reset_document` (1260–1267) | none / `update_title()` | pending; content empty; `file_path=None`; stacks cleared |
| 3 | `Open` (632) | `guard_unsaved(Open)`; clean ⇒ `open_dialog()` (1327–1346, lazy portal future) | none / dialog task | pending when dirty; nothing observable when clean (task dropped) — drive #4 next |
| 4 | `OpenSelected(Url)` (633–640) | file URL ⇒ `guard_unsaved(OpenPath(path))`; non-file URL ⇒ `pending=Error{could-not-open + url}` | none / per guard | clean: content == file bytes (lossy UTF-8, 1273–1275; strict after D8), `saved_text`, `file_path`, stacks cleared, title; non-file: Error dialog |
| 5 | `OpenExternal(Vec<PathBuf>)` (641–653) | focus task if window id; first file ⇒ `guard_unsaved(OpenPath)`; empty vec ⇒ focus-only/none | batch/none | second-instance parity: dirty ⇒ `SaveChanges{OpenPath(p)}`; clean ⇒ loads p; empty ⇒ no state change |
| 6 | `Save` (654) | `save(false)` (1292–1297): with `file_path` ⇒ `write_to`; without ⇒ `save_as_dialog()` (1348–1379) | write: `update_title()` (+continuation, see #43) / dialog task | file on disk == `content.text()`; `saved_text` synced; clean title; unwritable path ⇒ `pending=Error{could-not-save}` (1318–1323) |
| 7 | `SaveAs` (655) | `save_as_dialog()` — localized `Untitled.txt` default name (1349–1356) | dialog task (lazy) | no state change (task dropped); drive #8 |
| 8 | `SaveSelected(Url)` (656–663) | file URL ⇒ `write_to(path)` (1299–1325); else `pending=Error{could-not-save + url}` | `update_title()` (+continuation) | same as #6 write path |
| 9 | `Exit` (664–670) | if `pending==SaveChanges{after}` ⇒ retarget `after=Close` (re-exit while dialog open); else `guard_unsaved(Close)` ⇒ dirty: `SaveChanges{Close}`; clean: `close_window()` (1381–1388) | none / window-close + `iced::exit` tasks | pending state; retarget behavior; tasks unobservable (smoke test covers real exit) |
| 10 | `Undo` (671–679) | pop undo ⇒ push current to redo, rebuild `Content::with_text(prev)`, restore cursor | `update_title()` / none if empty | text + cursor restored; redo grows; empty stack = no-op |
| 11 | `Redo` (680–688) | mirror of #10 | `update_title()` / none | symmetric |
| 12 | `Cut` (689–695) | if selection: `push_undo`, `perform(Edit::Delete)` | `clipboard::write(selected)` | content loses selection; undo snapshot pushed; clipboard payload itself unobservable (§3.6) |
| 13 | `Copy` (696–700) | if selection: nothing mutates | `clipboard::write(selected)` | no state change; payload unobservable |
| 14 | `Paste` (701–704) | requests clipboard | `clipboard::read().map(→ClipboardPaste)` | no state change; test via #15 |
| 15 | `ClipboardPaste(Option<String>)` (705–712) | `Some(text)`: `push_undo`, `perform(Edit::Paste)` | `update_title()` / none on `None` | text inserted at cursor; undo pushed; dirty marker |
| 16 | `Delete` (713–717) | `push_undo`, `perform(Edit::Delete)` (no selection ⇒ no-op edit but undo still pushed) | `update_title()` | selection removed; stack depth +1 |
| 17 | `Find` (718–722) | `prefill_search_from_selection` (1109–1116: single-line non-empty selection ⇒ `find_text`); `find_visible=true`, `replace_visible=false` | none | flags; prefill rules (multi-line selection ignored) |
| 18 | `FindNext` (723) | `find_next(true)` (1122–1139): empty needle ⇒ none; from `cursor_end` (1473–1481), `commands::find_next` with wrap ⇒ `select_range` (1200–1205); else `pending=Error{cannot-find}` | none | selection == match range (via `content.cursor()`); wrap-around; not-found dialog |
| 19 | `Replace` (724–728) | prefill; both flags true | none | flags |
| 20 | `ReplaceOne` (729) | `replace_one()` (1141–1178) via `commands::replace_and_find_next` (`src/commands.rs:109–147`): `None` ⇒ Error{cannot-find}; `Found{range}` ⇒ select; `Replaced{text,next}` ⇒ push_undo, rebuild content, select next | none / `update_title()` | v2 parity: replace-then-advance; one undo step per replacement |
| 21 | `ReplaceAll` (730) | `replace_all()` (1180–1198) via `commands::replace_all` (`src/commands.rs:150–174`): count 0 ⇒ Error{cannot-find}; else **one** `push_undo` + rebuild | none / `update_title()` | v2 parity: single undo step restores all (`v2.0.4:src/commands.py` single edit block; `v2.0.4:tests/test_commands.py`) |
| 22 | `CloseFind` (731–734) | both find flags false | none | flags |
| 23 | `FindText(String)` (735) | store | none | field |
| 24 | `ReplaceText(String)` (736) | store | none | field |
| 25 | `MatchCase(bool)` (737) | store | none | field; behavior via #18/#20/#21 |
| 26 | `GoTo` (738–754) | only when `!config.word_wrap` (v2 parity: wrap disables Go-To, `v2.0.4:src/window.py` `on_toggle_wrap`): compute current line via `offset_at_line_col`+`line_col_at`, prefill `goto_input`, `pending=GoTo{input, error:None}` | none | pending contents; no-op when wrap on |
| 27 | `GoToInput(String)` (755–765) | store; if GoTo pending, sync `input` and **clear error** | none | in-dialog error clears on typing |
| 28 | `GoToConfirm` (766) | `confirm_goto()` (1207–1240): parse `usize` fail ⇒ `error=invalid-line-number` (in-dialog if GoTo pending); `commands::goto_line` (`src/commands.rs:184–198`) `Some(offset)` ⇒ close dialog + `move_to`; `None` ⇒ `error=line-beyond-end` | none | cursor line; dialog error strings; dialog stays open on error |
| 29 | `SelectAll` (767) | `perform(Action::SelectAll)` | none | `content.selection() == Some(full text)` |
| 30 | `InsertDateTime` (768–773) | `push_undo`, `perform(Edit::Paste(datetime_stamp()))` (1446–1459: `h:MM AM/PM M/D/YYYY`, v2 format parity) | `update_title()` | inserted text matches shape (regex-free: hour/min/AM-PM parts); undo pushed |
| 31 | `ToggleWrap` (774–777) | flip `config.word_wrap`; `persist_config()` (1010–1014) | none | config field; on-disk key file when handler injected (§5) |
| 32 | `ToggleStatusBar` (778–781) | flip `config.show_status_bar`; persist | none | same |
| 33 | `Font` (782–789) | seed `font_family_input`/`font_size_index` from config (unknown size ⇒ index 5 = 14pt, `FONT_SIZES` 52); `pending=Font` | none | dialog scratch state seeded |
| 34 | `FontFamily(usize)` (790–794) | in-range ⇒ `font_family_input = FONT_FAMILIES[i]` | none | field; out-of-range ignored |
| 35 | `FontSize(usize)` (795) | `font_size_index = min(i, 13)` | none | clamp |
| 36 | `FontFamilyInput(String)` (796) | free-text family (v2 `QFontDialog` parity: arbitrary families allowed) | none | field |
| 37 | `ApplyFont` (797–803) | commit to `config.font_family/font_size`; `editor_font = font_from_family` (1427–1440); close dialog; persist | none | config + font family resolution (generic aliases vs `Family::Name`, interning 1413–1425) |
| 38 | `Scheme(ColorScheme)` (804) | `apply_scheme` (1016–1020): set + persist + theme | `command::set_theme(theme_for(scheme))` | config field; persisted bytes; theme task lazy-dropped |
| 39 | `ToggleScheme` (805–812) | target = opposite of `effective_is_dark()` (1002–1008; System ⇒ `cosmic::theme::is_dark()`) | `set_theme` | header button parity (`v2.0.4:src/window.py` toolbar toggle); tests pin Light/Dark (§3.4) |
| 40 | `LaunchUrl(String)` (821–825) | **immediate side effect**: `open::that_detached(url)`, errors to stderr | none | **excluded from unit tests** (§3.6) |
| 41 | `ToggleContextPage(About)` (813–820) | same page ⇒ toggle `core.window.show_context`; else set page + show | none | `core.window.show_context` |
| 42 | `DialogCancel` (826–829) | `pending=None`, `pending_after=None` | none | both cleared (v2 Cancel parity) |
| 43 | `DialogSave` (830–835) | take `SaveChanges{after}` ⇒ `pending_after=Some(after)`; `save(false)` | write or dialog task | **continuation chain**: with `file_path` ⇒ immediate write ⇒ `write_to` consumes `pending_after`, clears a stale second `SaveChanges` prompt (1306–1313), returns `proceed(after)` (1251–1258); without ⇒ pending_after survives the lazy Save-As until #8 |
| 44 | `DialogDiscard` (836–842) | take `SaveChanges{after}` ⇒ `pending_after=None`; `saved_text = content.text()` (force-clean); `proceed(after)` | per `proceed` | document preserved in memory but treated as saved; continuation runs immediately |
| 45 | `CloseError` (843–849) | `pending_after` present ⇒ re-raise `SaveChanges{after}` (failed-save retry loop, bugfix-pass P0); else close dialog | none | the Error→SaveChanges ping-pong |
| 46 | `UpdateConfig(Config)` (850–857) | replace config; re-derive `editor_font`; `set_theme` **only if** `color_scheme` changed | `set_theme` / none | external-edit sync (`watch_config`, 602–604); font family applied; no theme churn on unrelated changes |
| 47 | `Error(String)` (858–860) | `pending=Error{message}` | none | dialog message passthrough (portal errors land here, 1343/1376) |
| 48 | `Cancelled` (861–863) | `pending_after=None` only — `pending` untouched | none | portal-cancel parity: a cancelled Save-As aborts the continuation but leaves any dialog state intact |

### 2.4 Lifecycle hooks and subscriptions (non-Message surface)

| Hook (line) | Behavior | Test approach |
|---|---|---|
| `init` (301–359) | config load (302–309), About (311–316), field defaults (318–346), `saved_text` sync (347), tasks: `update_title` + `set_theme` + **synchronous** `load_path` for `flags.files[0]` (349–356 — note `load_path` runs during `init`, not lazily) | via `with_config` seam (§3.5); argv-open flow assertable right after init |
| `on_escape` (869–884) | precedence: dialog (`pending`+`pending_after` cleared) > context drawer > find bar | direct call, state asserts |
| `on_app_exit` (886–888) | always `Some(Message::Exit)` — header close enters the guard | direct call |
| `on_close_requested` (890–899) | `SaveChanges` pending ⇒ `Some(Exit)` (retargets to Close via #9); dirty ⇒ `Some(Exit)`; clean ⇒ `None` (window closes) | direct call, all three branches |
| `system_theme_update` (901–911) | System scheme ⇒ `set_theme(system_preference())`; explicit scheme ⇒ none | direct call; task dropped |
| `subscription` (600–608) | `watch_config→UpdateConfig`, `single_instance→OpenExternal`, `window::close_requests→Exit` (`libcosmic:iced/runtime/src/window.rs:291`) | streams not unit-testable; the Messages they produce are (#5, #9, #46) — that is the seam |

### 2.5 Helper purity map

**Pure / CPU-only (directly unit-testable):** `is_dirty` (998), `needle`
(1118), `select_range` (1200), `offset_to_position` (1461–1471), `cursor_end`
(1473–1481), `cursor_selection` (1483–1493), `datetime_stamp` (1446–1459,
clock-dependent but side-effect-free), `editor_key_binding` (1391–1411),
`intern_family` (1413–1425), `font_from_family` (1427–1440), all of
`src/commands.rs` (20–270; 22 existing tests at 272–472).

**Stateful but display-free (testable through `App`):** `push_undo` (1040),
`find_next` (1122), `replace_one` (1141), `replace_all` (1180), `confirm_goto`
(1207), `guard_unsaved` (1242), `proceed` (1251), `reset_document` (1260),
`update_title` (1022), `apply_scheme` (1016), `effective_is_dark` (1002),
`persist_config` (1010), `prefill_search_from_selection` (1109).

**Synchronous filesystem (tempdir-testable, both success and error paths):**
`load_path` (1269–1290, `std::fs::read` + lossy UTF-8 — **strict reject after
D8 lands**, see §7-T3), `write_to` (1299–1325, `std::fs::write`).

**Lazy-task producers (drop in tests; drive via reply messages):**
`open_dialog` (1327), `save_as_dialog` (1348), `close_window` (1381),
clipboard read/write (693–704), `command::set_theme`
(`libcosmic:src/command.rs:36`).

**Immediate external side effect (never drive in tests):** `LaunchUrl` →
`open::that_detached` (821–825).

---

## 3. Testability analysis (critical section)

### 3.1 Verdict

**Yes — `App` can be constructed headlessly and driven at the Message level**
(empirically confirmed: every building block `App::init`/`update` touches was
exercised in a headless spike that passes 8/8 in 0.01 s, §3.3).
The harness is `App::init(cosmic::Core::default(), Flags::default())` (after
the §3.5 seam refactor: `App::with_config(...)`) followed by
`let task = app.update(message); drop(task); assert!(...)` — with **one
recommended refactor** (config-handler injection) and **no other structural
change**. Everything `update()` touches is CPU-only or lazy; the two genuine
external effects (portal dialogs, `LaunchUrl`) sit behind message boundaries
that tests drive directly.

### 3.2 Evidence chain (why headless construction is safe)

1. **`Core::default()` is display-free.** Const-friendly `Default`
   (`libcosmic:src/core.rs:133`); `main_window: None` ⇒ `main_window_id()`
   returns `None` (`libcosmic:src/core.rs:453`) ⇒ NotePad's `update_title`
   short-circuits to `Task::none()` (`src/app.rs:1033–1037`) and
   `close_window`/`OpenExternal` skip window tasks (`src/app.rs:642,
   1383–1387`). No code path in `update()` dereferences a real window.
2. **The global theme is a const-initialized `Mutex`**, default
   `ThemeType::Dark` (`libcosmic:src/theme/mod.rs:47–52`); `theme::active()` /
   `is_dark()` only lock it (`theme/mod.rs:57–79`). Consequence: headless
   `effective_is_dark()` for `ColorScheme::System` is **Dark by default** —
   tests must pin Light/Dark (§3.4).
3. **`Content` editing never touches a GPU/display.** `Editor::with_text`
   builds a `cosmic_text::Buffer` with the global font system and shapes
   (`libcosmic:iced/graphics/src/text/editor.rs:89–111`); `perform` is the same
   stack (`graphics/src/text/editor.rs:237+`). `Content::text()` rejoins lines
   with each line's own `LineEnding` (`libcosmic:iced/widget/src/
   text_editor.rs:468–485`; endings mapped per line at
   `graphics/src/text/editor.rs:120–131`).
4. **All `Task`s are lazy.** `Task<M> = iced::Task<Action<M>>`
   (`libcosmic:src/app/mod.rs:18`); `set_theme` (`libcosmic:src/command.rs:36`),
   `clipboard::read/write` (`libcosmic:iced/runtime/src/clipboard.rs:64, 84`),
   `cosmic::task::future` (portal dialogs, `src/app.rs:1332, 1361`),
   `iced::exit` (`src/app.rs:1382`) construct thunks that only run when the
   runtime polls them. Dropping them in tests is inert — including the
   `async` portal futures, whose bodies never start.
5. **`fl!` strings come from embedded assets** (`src/i18n.rs`, rust-embed
   `i18n/`), not the filesystem/locale. Whether `fl!` works *without* calling
   `i18n::init` in a test binary: **needs Phase 2 verification** — first
   harness test settles it; fallback is calling `i18n::init(&[en])` in the
   test constructor.
6. **Filesystem work in `update()` is synchronous `std::fs`** (`load_path`
   1273, `write_to` 1301) — fully testable with tempdirs, including error
   branches (`PendingDialog::Error`).
7. **No subscription/stream needs polling**: the three subscriptions
   (`src/app.rs:600–608`) only *produce* Messages (`UpdateConfig`,
   `OpenExternal`, `Exit`), each independently drivable.

### 3.3 Empirical spike (outside the repo, per ground rules)

Crate: `/tmp/cosmic-headless-spike/` — libcosmic pinned to the same rev +
feature set as `Cargo.toml`. Eight `#[test]`s mirroring exactly what
`App::init`/`update` touch: `Core::default` + `theme::active/is_dark`;
`Config::new` under redirected `XDG_CONFIG_HOME`; `Content` edit/select/delete
via `perform`; snapshot-undo rebuild (`with_text` + `move_to`);
`About::default` + `icon::from_svg_bytes`; CRLF round-trip through
`Content::text()`; construction-and-drop of every Task kind `update()` returns
(`set_theme`, clipboard read/write, `task::future`, `iced::exit`, batch);
`Config::with_custom_path` write→read→on-disk RON key-file assertion.

Results so far (compilation is itself evidence):

- **E0283 pitfall (confirmed, fixed):** bare `Content::new()` in expression
  position cannot infer the renderer parameter — default type params don't
  drive inference (candidates: `fallback::Renderer`, `()`, tiny_skia, wgpu;
  bound at `libcosmic:iced/widget/src/text_editor.rs:397–399`). In-crate tests
  are immune when assigning to `app.content` (type pinned by the field); free
  constructions need `Content::<cosmic::Renderer>::with_text(..)` or a type
  alias. Documented for the harness.
- **Clipboard signatures at this rev (confirmed via E0308/E0107):**
  `clipboard::write<T>(contents: String)` and non-generic `clipboard::read()
  -> Task<Option<String>>` (`libcosmic:iced/runtime/src/clipboard.rs:84, 64`).
- **Task constructor inference (confirmed via E0282/E0283, spike-only
  pitfall):** free-standing `task::future(async { 1u8 })` and `Task::none()`
  need the message type pinned (`libcosmic:src/task.rs:17`); in app code both
  are inferred from the enclosing `-> Task<Message>` signature, so harness
  tests that just `drop(app.update(msg))` never hit this.
- **RESULT: all 8 tests pass, headless, in 0.01 s** (no display server, no
  GPU, no portal, no dbus session — plain `cargo test` on this host). This
  empirically confirms §3.1/§3.2: `Core::default`, `Content` edit/select/
  delete, snapshot-undo rebuild, `About`+SVG icon, every Task kind `update()`
  returns (constructed and dropped unpolled), `Config::new` under a redirected
  `XDG_CONFIG_HOME`, and `Config::with_custom_path` write→read→on-disk RON
  key-file round trip all work inside a test binary.
- **CRLF verdict (R10 settled):** `Content::with_text("a\r\nb").text()`
  returns `"a\r\nb"` — **Windows line endings round-trip byte-faithfully**
  (per-line `LineEnding` preservation, `libcosmic:iced/graphics/src/text/
  editor.rs:120–131`). v3.0.0 is therefore *better* than v2.0.4 parity here:
  Python universal-newlines **normalized** CRLF→LF on load and wrote LF back
  on save (`v2.0.4:src/window.py` text-mode open). T3 locks this with a
  load→save byte-equality test so a future cosmic-text bump can't silently
  regress it.

### 3.4 Harness design

```rust
// In a child module of `app` (see placement below) — child modules see
// App's private fields.
#[cfg(test)]
fn test_app() -> App {
    // Pin an explicit scheme: headless THEME defaults to Dark
    // (libcosmic theme/mod.rs:47–52); System would make assertions
    // environment-dependent.
    let config = Config { color_scheme: ColorScheme::Light, ..Default::default() };
    let (app, task) = App::with_config(          // §3.5 seam
        cosmic::Core::default(),
        Flags::default(),
        config,
        None,                                    // no persistence by default
    );
    drop(task);                                  // all tasks are lazy (§3.2-4)
    app
}

#[cfg(test)]
fn app_with_text(text: &str) -> App {
    let mut app = test_app();
    app.update(Message::ClipboardPaste(Some(text.to_string())));
    app.undo_stack.clear();                      // start from a clean history
    app
}
```

Driving pattern: `let task = app.update(msg); drop(task);` then assert on
`content.text()/cursor()/selection()`, `file_path`, `saved_text`, `pending`
(match on `PendingDialog`), `pending_after` (match on `AfterSave`),
`undo_stack/redo_stack`, find/replace/goto/font fields, `config`, and
`core.window.header_title` / `core.window.show_context`.

**Placement.** The crate is a **binary** (`src/main.rs:3–8`; no `[lib]` in
`Cargo.toml`), so `tests/*.rs` cannot import `App` — `tests/packaging.rs`
works only because it reads files as data. Mandated state tests therefore live
in `#[cfg(test)]` **child modules of `app`**, kept in separate files to
minimize the contested `app.rs` surface (D5):

```rust
// one line inside src/app.rs:
#[cfg(test)]
#[path = "app_state_tests.rs"]
mod app_state_tests;
```

A `#[path]`-included module is still a child of `app` for visibility purposes,
so it can read private fields. (Alternative: add a `lib` target — larger
change, flagged for the lead; not needed for the mandate.)

**Rules encoded in the harness:** never send `LaunchUrl` (§3.6); never assert
on `System`-scheme darkness; construct `Content` values with an explicit
renderer param when free-standing (§3.3 pitfall).

**Tempdirs — decision (lead delegated, 2026-09-11): no `tempfile` dev-dep.**
The in-tree pid+nanos pattern (`src/single_instance.rs:150–158`) is close but
nanos can theoretically collide between parallel test threads. The harness
helper hardens it to guaranteed-unique with zero dependencies:

```rust
fn test_tempdir(tag: &str) -> TempDir {          // TempDir: Drop ⇒ remove_dir_all
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let dir = std::env::temp_dir().join(format!(
        "notepad-test-{tag}-{}-{:?}-{}",
        std::process::id(), std::thread::current().id(),
        COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed)));
    std::fs::create_dir_all(&dir).unwrap();
    TempDir(dir)
}
```

pid + thread-id + per-process atomic counter is race-free under parallel
`cargo test`; the `Drop` guard cleans up even on panics (test harness
unwinds). Rationale for declining `tempfile`: it would add ~5–8 transitive
crates to `Cargo.lock` — growing the D9 vendored tarball and churn for every
consumer — to replace a ~15-line helper (priority 4: simplicity).

### 3.5 Required refactor (the only one)

`App::init` hardcodes `cosmic_config::Config::new(Self::APP_ID,
Config::VERSION)` (`src/app.rs:302–303`), which resolves to the **real**
`~/.config/cosmic/com.goshapps.Notepad/v1/` and `create_dir_all`s it
(`libcosmic:cosmic-config/src/lib.rs:215–250`). Unrefactored, every test would
read (and via `persist_config`, write) the developer's live settings, and the
obvious alternative — `XDG_CONFIG_HOME` redirection — needs `unsafe
env::set_var` under edition 2024 (`Cargo.toml`) and races between parallel
tests.

**Fix:** split `init` into a thin public entry plus an injectable constructor
— behavior-identical, ~10-line diff in the Architecture-owned region (D5):

```rust
fn init(core: cosmic::Core, flags: Self::Flags) -> (Self, Task<Self::Message>) {
    let (handler, config) = match cosmic_config::Config::new(Self::APP_ID, Config::VERSION) {
        Ok(h) => (Some(h), Config::get_entry(&h).unwrap_or_else(|(_, c)| c)),
        Err(_) => (None, Config::default()),
    };
    Self::with_config(core, flags, config, handler)
}

fn with_config(core: cosmic::Core, flags: Self::Flags,
               config: Config, config_handler: Option<cosmic_config::Config>)
    -> (Self, Task<Self::Message>) { /* existing body, src/app.rs:311–358 */ }
```

Tests then choose: `None` (persistence no-ops via `persist_config`'s existing
`if let`, `src/app.rs:1010–1014`) or
`Config::with_custom_path(APP_ID, 1, tempdir)` — the env-free seam cosmic-config
provides (`libcosmic:cosmic-config/src/lib.rs:253`) — for persistence tests
(§5, §7-T7).

Nothing else needs refactoring for testability. Optional (not blocking):
§3.6 clipboard helper, §7-T8 single-instance server extraction.

### 3.6 Testing the hard areas

| Area | Approach | Status / gaps |
|---|---|---|
| **File dialogs (xdg-portal)** | The seam is the message boundary: drop the lazy dialog task, then drive `OpenSelected(Url)` / `SaveSelected(Url)` / `Cancelled` / `Error(String)` — exactly the four outcomes the dialog future would produce (`src/app.rs:1340–1344, 1370–1377`; `Error` enum incl. `Cancelled` at `libcosmic:src/dialog/file_chooser/mod.rs:123`). `Url::from_file_path(p)` builds valid inputs; `Url::parse("https://…")` exercises the non-file error branches (633–640, 656–663). | Complete; no portal needed in unit tests. Real portal exercised only by the Flatpak smoke test (D11/D13). |
| **Filesystem (load/save)** | Tempdirs; success + `Error` dialog branches; after-save continuation and stale-prompt clearing (1306–1313). D8 adds the strict-UTF-8 reject test (invalid bytes ⇒ error dialog, document untouched). | Complete via §3.5 seam. |
| **Clipboard** | Inbound: drive `ClipboardPaste(Some/None)` (#15). Outbound (`Cut`/`Copy` return `clipboard::write`): the written string is inside an opaque task — assert the *state* effects (selection removed, undo pushed) and, if the reviewer wants payload assertions, extract a pure `fn selection_text(&self) -> Option<String>` used by both arms (689–700) and test that (§7-T10, optional). | Gap: payload not observable without the optional extraction. |
| **Window title / close / exit** | `header_title` always assertable (`set_header_title`, 1032). The `set_window_title` task path needs `core.main_window_id() == Some(..)`: `Core::set_main_window_id` is public (`libcosmic:src/core.rs:~458`) — tests can set a synthetic id; exact `window::Id` constant to use **needs Phase 2 verification**. `close_window`/`iced::exit` tasks are unobservable ⇒ guard *logic* is unit-tested (#9, `on_close_requested`), actual exit is the smoke test's pass criteria (D11). | Small verification item; no blocker. |
| **Config persistence** | `with_custom_path` handler + tempdir; assert in-memory `config` **and** on-disk key files (`<dir>/cosmic/com.goshapps.Notepad/v1/word_wrap` containing RON `true` — layout per `libcosmic:cosmic-config/src/lib.rs:215–250, 319–476`; spike asserts this mechanism). `UpdateConfig` driven directly (#46); the watch stream itself (dbus/inotify) is runtime plumbing, out of unit scope (§5). | Complete; replaces v2's `SettingsTests` QSettings roundtrip (`v2.0.4:tests/test_theme.py`). |
| **single_instance** | Client side already tested env-free at an explicit socket path (`forward_round_trips_paths_and_empty_payload`, `src/single_instance.rs:144–182`). Server side: `subscription()` hardcodes `socket_path()` (98) and needs a tokio runtime — extract `subscription_at(path)` (the `stream::channel` body, 96–117) so a test can bind a temp socket, spawn the accept loop on a current-thread runtime, `forward_to` it, and assert the yielded `Vec<PathBuf>` + ack. App-side behavior is covered by `OpenExternal` (#5). | Gap: server loop untested today ⇒ §7-T8. |
| **commands.rs** | All nine public fns have tests (22, `src/commands.rs:272–472`), incl. UTF-8/CJK boundary and wrap cases; `caret_line_col` proven equivalent to the two-step conversion over a corpus (432–460). Missing: nothing function-level. Oddity: `line_count` is `#[allow(dead_code)]` (177–181) — unused by the app (footer uses `caret_line_col`). **Lead ruling 2026-09-11: deletion folded into T1** (together with its sole caller, the test at 364–368). | Complete. |
| **Theme application** | `set_theme` is a lazy task; assert the *decision* inputs instead: `config.color_scheme`, `effective_is_dark()` (1002–1008), `theme_for` mapping incl. `pin_independent` (`src/config.rs:44–58` — pure, directly testable). Actual palette rendering = smoke test / manual. | Complete for unit scope. |

---

## 4. Integration test strategy

### 4.1 Principles

- **Message sequences → state assertions.** Each major flow is one `#[test]`
  that scripts a realistic user journey through `app.update(msg)` calls and
  asserts observable state after each step (given/when/then comments). No
  pixel matching, no widget-tree inspection, no runtime/window needed — per
  the project charter and the seams in §3.6.
- **Same placement as unit tests** (§3.4): `#[path]`-included child modules of
  `app` (proposed file: `src/app_flow_tests.rs`), Architecture-owned.
- **Async boundaries are cut at their message seams** (§4.2); the lazy task
  returned at each cut is dropped.
- **Every flow ends in a fully-specified state** (document text, cursor,
  `file_path`, `saved_text`, `pending`, `pending_after`, dirty flag) so
  regressions localize to a step.

### 4.2 Seam table (what stands in for real I/O)

| Real boundary | In tests, drive | Assert |
|---|---|---|
| Open portal dialog (`open_dialog`, 1327) | `OpenSelected(Url::from_file_path(p))`, `Cancelled`, `Error(s)` | loaded doc / cleared continuation / Error dialog |
| Save portal dialog (`save_as_dialog`, 1348) | `SaveSelected(url)`, `Cancelled`, `Error(s)` | written bytes + continuation / abort / Error dialog |
| Clipboard read (`Paste`, 701) | `ClipboardPaste(Some(s))` / `None` | insertion + undo / no-op |
| Clipboard write (`Cut`/`Copy`) | — (task dropped) | state effects only (+ optional §7-T10 payload helper) |
| Window close / `iced::exit` | — (tasks dropped) | guard state (`pending`, `on_close_requested` results) |
| Theme application (`set_theme`) | — (task dropped) | `config.color_scheme`, `effective_is_dark()` |
| Config watch stream | `UpdateConfig(cfg)` | config/font/theme-decision state |
| Single-instance socket | `OpenExternal(vec![p])` (+ §7-T8 server-loop test) | guard/load behavior |
| Filesystem | tempdirs (real `std::fs`) | bytes on disk, Error dialogs |
| `LaunchUrl` (`open::that_detached`) | **never driven** | excluded (§3.6); manual smoke only |

### 4.3 Flow scripts (F1–F22)

Each row: flow name — message script — key assertions. Variant numbers refer
to §2.3.

1. **F1 new-clean**: `New` ⇒ empty doc, `file_path=None`, stacks empty,
   `header_title` = untitled form (`update_title`, 1022–1038; exact `fl!`
   strings from `i18n/en/notepad.ftl` — **needs Phase 2 verification** of
   `fl!` without `i18n::init`, §3.2-5).
2. **F2 new-dirty-cancel**: paste text; `New` ⇒ `SaveChanges{New}`;
   `DialogCancel` ⇒ pending/pending_after cleared, **text preserved** (v2
   `_guard_unsaved` Cancel parity).
3. **F3 new-dirty-discard**: … `DialogDiscard` ⇒ `reset_document` ran: empty
   doc, clean, title untitled (continuation `AfterSave::New` consumed).
4. **F4 new-dirty-save (has path)**: load temp file, edit, `New`,
   `DialogSave` ⇒ write happens synchronously (`write_to`), bytes on disk
   updated, `pending_after` consumed, continuation runs ⇒ doc reset. This is
   the **after-save continuation chain** (bugfix-pass P0 regression lock).
5. **F5 new-dirty-save (no path)**: edit untitled, `New`, `DialogSave` ⇒
   `pending_after=Some(New)`, dialog task dropped; `SaveSelected(temp url)` ⇒
   file written with edited text, then continuation ⇒ doc reset, clean.
6. **F6 save-as-cancel aborts continuation**: as F5 up to dialog;
   `Cancelled` ⇒ `pending_after=None`; a later plain `Save` (no path) must
   **not** auto-run any continuation (48/43 interplay).
7. **F7 save-failure retry loop**: `file_path` = unwritable location; edit;
   `Exit` ⇒ `SaveChanges{Close}`; `DialogSave` ⇒ write fails ⇒
   `Error{could-not-save…}` **and** `pending_after=Some(Close)` retained;
   `CloseError` ⇒ `SaveChanges{Close}` re-raised (843–849); `DialogDiscard` ⇒
   close path runs (tasks dropped), doc memory intact.
8. **F8 stale-prompt clearing**: engineer `pending=SaveChanges{..}` +
   `pending_after=Some(..)` simultaneously (sequence: dirty, `New`,
   `DialogSave` with no path, then `SaveSelected` to a bad url ⇒ Error; adjust
   per 1306–1313) ⇒ on successful `write_to` any lingering `SaveChanges`
   prompt is cleared before `proceed`.
9. **F9 open-clean**: `Open` (task dropped) → `OpenSelected(file url)` ⇒
   content == file bytes (UTF-8), `saved_text` synced, `file_path` set,
   stacks cleared, title = file name, clean (no `•`).
10. **F10 open-dirty-save-then-open**: edit doc A; `Open`; `DialogSave`
    (path exists) ⇒ A written **and** continuation `AfterSave::Open` ⇒ open
    dialog task (dropped); `OpenSelected(B)` ⇒ B loaded. Two-hop chain.
11. **F11 open-invalid-url**: `OpenSelected(Url::parse("https://x").unwrap())`
    ⇒ `Error{could-not-open…}` dialog, document untouched.
12. **F12 argv-open at init**: `with_config(.., Flags{files:[p]}, ..)` ⇒
    `load_path` ran **during init** (354–356): content == p, title = name.
13. **F13 open-read-error / D8 invalid-UTF-8**: missing file ⇒
    `Error{could-not-open…}`; after §7-T3: invalid bytes ⇒ strict reject,
    `content`/`saved_text`/title unchanged (DECISIONS D8 test spec).
14. **F14 find chain**: `Find` (prefill from selection rules, 1109–1116) →
    `FindText("o")` → `FindNext` ⇒ selection == first match after cursor;
    repeat ⇒ next; past last ⇒ wraps to first (`commands::find_next` wrap,
    `src/commands.rs:98–105`); absent needle ⇒ `Error{cannot-find}`;
    `MatchCase(true)` changes hit set; `CloseFind` / `on_escape` hide bar.
15. **F15 replace chain**: `Replace` → texts → `ReplaceOne` (no selection ⇒
    `Found` selects) → `ReplaceOne` (selection matches ⇒ `Replaced`, one undo
    step, next match selected) → `ReplaceAll` (count, single undo step) →
    `Undo` restores the whole replace-all in one step (v2 parity,
    `v2.0.4:tests/test_commands.py`).
16. **F16 go-to**: `GoTo` (wrap off) ⇒ dialog prefilled with current line;
    `GoToInput("3")` + `GoToConfirm` ⇒ cursor at line 3 col 1, dialog closed;
    `"abc"` ⇒ in-dialog `invalid-line-number`, dialog stays; `"9999"` ⇒
    `line-beyond-end`; `ToggleWrap` on ⇒ `GoTo` no-op (v2 parity).
17. **F17 font apply**: `Font` ⇒ dialog seeded from config;
    `FontFamily(i)`/`FontFamilyInput("Comic Sans")`/`FontSize(j)`;
    `ApplyFont` ⇒ config + `editor_font` updated (alias mapping vs interned
    `Family::Name`, 1427–1440), dialog closed, persisted (handler variant).
18. **F18 scheme switch**: `Scheme(Dark)` ⇒ config + persisted;
    `ToggleScheme` ⇒ Light; `effective_is_dark` tracks; `UpdateConfig` with
    changed scheme vs unchanged (set_theme decision, 850–857).
19. **F19 wrap/status toggles**: `ToggleWrap`/`ToggleStatusBar` ⇒ config
    flips + on-disk RON key files updated (with_custom_path handler);
    `UpdateConfig` echo applies external changes (font re-derivation).
20. **F20 status bar Ln/Col**: position cursor via `Editor(Move)`/paste;
    assert `commands::caret_line_col(text, cursor…)` equals expected
    `Ln/Col` values (the footer's exact computation, 555–558; equivalence
    corpus already at `src/commands.rs:432–460`).
21. **F21 second-instance forward**: dirty doc; `OpenExternal([p])` ⇒
    `SaveChanges{OpenPath(p)}` (focus task absent headless); `DialogDiscard`
    ⇒ p loaded. Clean variant loads immediately. `OpenExternal([])` ⇒ no state
    change (641–653) — v2 "present window with no files" parity
    (`v2.0.4:src/application.py` `_on_new_connection`/`ensure_window`).
22. **F22 exit guards**: clean `Exit` ⇒ close tasks (dropped), no pending;
    dirty `Exit` ⇒ `SaveChanges{Close}`; second `Exit` while dialog open ⇒
    `after` retargeted to `Close` (664–668); `on_close_requested` three
    branches (890–899); `on_app_exit` ⇒ `Some(Exit)`; `on_escape` precedence
    (dialog > drawer > find bar, 869–884).

Undo/redo is woven through F4/F5/F15 plus dedicated unit tests (§7-T4):
edit → undo → redo → edit-clears-redo → 101 edits ⇒ depth capped at 100 with
oldest evicted (1040–1047).

---

## 5. Settings & persistence

### 5.1 Schema

`Config` (`src/config.rs:16–24`), `#[derive(CosmicConfigEntry)]` with
`#[version = 1]` (line 17) ⇒ generated `Config::VERSION = 1`, `write_entry`
(transaction over all fields), `get_entry` (per-field with defaults)
(`libcosmic:cosmic-config-derive/src/lib.rs:183–215`):

| Field | Type | Default (`src/config.rs:26–36`) | v2.0.4 counterpart |
|---|---|---|---|
| `color_scheme` | `ColorScheme` (serde `lowercase`: `system`/`light`/`dark`, `System` default; `src/config.rs:7–14`) | `System` | QSettings key `color_scheme` (`v2.0.4:src/theme.py` `load/save_scheme`) |
| `word_wrap` | `bool` | `false` | per-session only (v2 had no persistence) |
| `show_status_bar` | `bool` | `true` | per-session only |
| `font_family` | `String` | `"monospace"` | per-session only |
| `font_size` | `u16` | `14` | per-session only |

v3.0.0 persists strictly more than v2.0.4 did (which stored only the color
scheme). No migration is needed: the stores are disjoint (QSettings
`goshapps/notepad` vs cosmic-config `com.goshapps.Notepad/v1`).

### 5.2 Where it lives on disk

`Config::new(APP_ID, 1)` resolves `<config_dir>/cosmic/com.goshapps.Notepad/v1/`
and creates it (`libcosmic:cosmic-config/src/lib.rs:215–250`). `<config_dir>`:

- **Host:** `dirs::config_dir()` ⇒ `$XDG_CONFIG_HOME` or `~/.config`
  (`cosmic-config/src/lib.rs:15–36`).
- **Flatpak** (`FLATPAK_ID` set): `$HOST_XDG_CONFIG_HOME` if present, else
  `$HOME/.config` (same lines). With the manifest's
  `--filesystem=xdg-config/cosmic:rw` (`com.goshapps.Notepad.json:19`), the
  host's `~/.config/cosmic` is bind-mounted read-write into the sandbox, so
  both branches land inside the permitted mount.

Storage is **one file per key**, RON-serialized values (e.g.
`…/v1/word_wrap` containing `true`), written through a `ConfigTransaction` +
`atomicwrites` temp-file rename (`cosmic-config/src/lib.rs:319–476`); the
watcher explicitly ignores `.atomicwrite` temps (332–385). The spike asserts
this layout end-to-end via `with_custom_path` (§3.3).

**The `:rw` finish-arg is load-bearing** (bugfix-pass item 13): without it the
bind is read-only, `Config::new`/`write_entry` fail, and settings silently
don't persist (`persist_config` ignores write errors by design,
`src/app.rs:1010–1014`). `tests/packaging.rs` pins `xdg-config/cosmic:rw`
present and `:ro` absent — keep that assertion.

### 5.3 Read paths

1. **Pre-window startup theme** (`src/main.rs:43–45`): `Config::new` +
   `get_entry` (defaults on error) ⇒ `Settings.theme(theme_for(scheme))` so
   the first frame already has the right palette (no flash; complements the
   65a4ae1 startup-theme fix).
2. **`App::init`** (`src/app.rs:302–309`): full `get_entry` with
   partial-error fallback (`unwrap_or_else(|(_, config)| config)` keeps good
   fields), handler stored for writes; `Err` ⇒ `None` + `Config::default()`
   (app still runs, persistence off).

### 5.4 Write paths

`persist_config()` (1010–1014) after every mutation: `ToggleWrap` (776),
`ToggleStatusBar` (780), `ApplyFont` (802), `apply_scheme` (1018, used by
`Scheme`/`ToggleScheme`). `write_entry` rewrites all five keys per
transaction — fine at this scale.

### 5.5 Live update (`UpdateConfig` subscription)

`App::subscription` wires `core.watch_config::<Config>(APP_ID)` ⇒
`Message::UpdateConfig` (`src/app.rs:600–604`). `Core::watch_config`
(`libcosmic:src/core.rs:386–403`) prefers the **dbus settings daemon** when
the `dbus-config` feature is active (it is — `Cargo.toml` libcosmic features),
else falls back to the **inotify** `config_subscription`
(`libcosmic:cosmic-config/src/subscription.rs`; recursive watch on the user
path, `cosmic-config/src/lib.rs:332–385`). Inside the Flatpak the manifest
grants only the portal talk-name (CosmicSettingsDaemon talk-name deliberately
deferred, DECISIONS D12), so the sandbox path is expected to be the inotify
fallback over the `:rw` bind — **needs Phase 3 verification** in the smoke
environment. Handler behavior on external change: replace config, re-derive
`editor_font`, `set_theme` only when `color_scheme` changed (850–857) — the
no-churn fix from the bugfix pass.

### 5.6 Persistence test plan (recap of §3.6)

`with_custom_path(APP_ID, 1, tempdir)` handler injected via §3.5 seam ⇒
drive toggles ⇒ assert in-memory config **and** per-key RON files; separate
test for handler-`None` no-op; `UpdateConfig` round-trip test (external edit
simulated by writing key files + driving the message); **invalid-config
fallback test (RV-5)** — write a malformed RON value into one key file under
the tempdir, construct via the seam, assert that field falls back to its
`Default` while well-formed fields survive (per-field `get_entry` defaults,
`libcosmic:cosmic-config-derive/src/lib.rs:183–215`; the
`unwrap_or_else(|(_, config)| config)` partial-error paths,
`src/app.rs:302–309` and `src/main.rs:43–45`) and the app is functional.
Direct descendant of v2's `test_invalid_value_falls_back_to_system`
(`v2.0.4:tests/test_theme.py:311–313`). Together these replace v2's
`SettingsTests` QSettings roundtrip (`v2.0.4:tests/test_theme.py`).

---

## 6. Risks & mitigations

| # | Risk | Evidence | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **clippy `double_must_use` fails the gate** — the only current `-D warnings` failure | `src/config.rs:43` (`#[must_use]` on `theme_for`) vs `cosmic::Theme` already `#[must_use]` (`libcosmic:src/theme/mod.rs:182`); recorded as DECISIONS D7 | Blocks every task's definition-of-done | **T1**: delete the redundant attribute (not `#[allow]` — D7 requires the reviewer verify that). One-line, zero behavior change |
| R2 | **Task opacity** — `iced::Task` has no inspection/`PartialEq`; tests cannot assert *which* task was returned | `libcosmic:src/app/mod.rs:18`; no public introspection API in `iced/runtime` | Clipboard payloads, `set_theme`, window-close/exit tasks unverifiable at unit level | Assert state + use inspectable enums (`AfterSave`, `PendingDialog`) (§3.4); behavior-bearing tasks covered by smoke test (D11); optional pure-helper extraction for clipboard payload (T10). Accepted limitation — same as every iced app |
| R3 | **`LaunchUrl` has an immediate side effect inside `update()`** (`open::that_detached` spawns a process) | `src/app.rs:821–825` | A test driving it would spawn `xdg-open` on the host | Hard rule: never sent in tests (§3.4); two-line wrapper, low regression risk; manual/smoke coverage only |
| R4 | **`App::init` touches the real user config dir** (reads settings; `create_dir_all` side effect) | `src/app.rs:302–303`; `libcosmic:cosmic-config/src/lib.rs:215–250` | Tests would depend on / pollute `~/.config/cosmic/com.goshapps.Notepad` | **T2** `with_config` seam (§3.5); `None` handler or `with_custom_path` tempdir. Avoids edition-2024 `unsafe set_var` + parallel-test env races entirely |
| R5 | **`fl!` without `i18n::init` in test binaries unproven** | `src/i18n.rs` (LazyLock loader, rust-embed); no existing test calls `fl!` | Title/dialog-string assertions could panic or fall back unexpectedly | First harness test settles it (**needs Phase 2 verification**); fallback: call `i18n::init(&[en])` in `test_app()` |
| R6 | **Headless THEME defaults to Dark** (const `Mutex<Theme>`), so `System` scheme assertions are environment-dependent | `libcosmic:src/theme/mod.rs:47–52`; `effective_is_dark` (`src/app.rs:1002–1008`) | Flaky theme tests | Tests pin `ColorScheme::Light/Dark` (§3.4); `System` only exercised via `theme_for`'s pure fallbacks (`libcosmic:src/theme/mod.rs:103–132` — config-read failures degrade to `Theme::dark()/light()`, no panic) |
| R7 | **Undo snapshots are whole-document**: memory O(doc × 100); `Vec::remove(0)` eviction is O(n) per overflow | `src/app.rs:107–108, 1040–1047, 1444` | 1 MB doc ⇒ up to ~100 MB history; eviction cost trivial at depth 100 | Accepted: cap is deliberate (commit 776b74d "cap undo history"); v2's Qt undo was unbounded but per-fragment — **a documented, reviewer-visible deviation**, memory-safety wins (priority: parity caveat noted; lead may log in DECISIONS). Optional later: `VecDeque` (cheap), or diff-based snapshots (not worth it) |
| R8 | **Font interning leaks by design** (`Box::leak` for `&'static str`) | `src/app.rs:1413–1425`; tested (1499–1505) | Bounded by distinct family strings a user types in one session | Accepted + tested; documented here so it's never "fixed" into a dangling-reference bug (`Family::Name` requires `'static`, `libcosmic:iced/core` Font type) |
| R9 | **Single-instance startup race / silent bind failure**: two simultaneous cold starts — both see no socket, one binds, the loser silently runs server-less (`return` on bind error); a third instance still reaches the winner | `src/single_instance.rs:101–103`; v2 had the same best-effort class (`v2.0.4:src/application.py` probe-then-bind) | Rare duplicate window; no data loss | Accepted for parity (v2 identical class). Phase 3 hardening option: `eprintln!`/`tracing` on bind failure; T8's extracted `subscription_at` makes the loop testable without changing semantics |
| R10 | **CRLF behavior of `Content::text()`** — RESOLVED by spike (§3.3): `"a\r\nb"` round-trips byte-faithfully; v2 (Python universal newlines) normalized CRLF→LF and rewrote files on save | spike result; `libcosmic:iced/graphics/src/text/editor.rs:120–131` (per-line endings) + `iced/widget/src/text_editor.rs:468–485` (rejoin); v2: `v2.0.4:src/window.py` text-mode open | Residual risk only: a future libcosmic/cosmic-text bump could change normalization silently; v3 deviation is an improvement (no silent rewrite of Windows files), but is still a deviation reviewers should know about | Recorded as **DECISIONS D14** (lead, 2026-09-11): deliberate improvement over 2.0.4. T3 locks it with a load→save byte-equality test (CRLF + mixed endings) |
| R11 | **Binary-only crate blocks `tests/` from importing `App`** | `src/main.rs:3–8`; no `[lib]` in `Cargo.toml`; `tests/packaging.rs` works only on file data | Mandated state tests can't live in `tests/` | Inline `#[cfg(test)]` child modules via `#[path]` (§3.4) — matches existing convention (`src/app.rs:1495`, `src/commands.rs:272`); lib-target alternative flagged for lead, not required |
| R12 | **`src/app.rs` is contested** (UX owns view regions, Architecture owns state regions — same file) | DECISIONS D5 | Edit conflicts / sequencing stalls in Phase 2 | **RULED (lead, 2026-09-11):** test code lives in new Architecture-owned files; `app.rs` touched only by the T2 seam + one `#[path]` mod line per test file; **T2 lands before any UX view edits**; no `app/mod.rs` + `app/view.rs` split now — revisit only if real friction materializes |
| R13 | **`Content<R>` inference pitfall (E0283)** in free-standing test constructions | spike compile log (§3.3); bound at `libcosmic:iced/widget/src/text_editor.rs:397–399` | Confusing first-failure for whoever writes tests | Harness note + alias/annotation rule (§3.4); in-crate assignments to `app.content` are immune |
| R14 | **Portal availability in test environments** (no xdg-desktop-portal under bare weston/xvfb) | `libcosmic:src/dialog/file_chooser/*` (ashpd-based); D11 allowlist mentions portal fallback noise | Could tempt someone to "fix" dialogs for tests | Unit/integration tests never start dialog futures (§4.2 seams); smoke test treats portal warnings as allowlisted noise (D11) |
| R15 | **`set_window_title` path untestable without a window id** | `src/app.rs:1033–1037`; `Core::set_main_window_id` public (`libcosmic:src/core.rs:~458`, exact line **needs Phase 2 verification**) | Multi-window title map (`core.title`, feature default on — `libcosmic:Cargo.toml:11–19`, two-arg `set_window_title` `libcosmic:src/app/mod.rs:597`) unasserted | Optional: set a synthetic main-window id in one dedicated test and assert `core.window.header_title` (+ `core.title` if reachable); low priority — header title covers the string logic |

---

## 7. Proposed Phase 2 tasks (ordered)

Conventions: every task keeps `cargo fmt --check`, `cargo build --locked`,
`cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`
green (DECISIONS D6); one descriptive commit per task, made by the lead after
reviewer sign-off (D4). "Owner" uses the D5 region map. Sizes are S (<1 h),
M (half day), L (day).

**Numbering note (2026-09-11, rev 2):** `PLAN.md` is the authoritative task
ledger and renumbers this proposal — known mapping: T1→T01, T2→T02, T4→T09,
T5→T10, T8→T13 (T13 may run immediately after T01, in parallel with the T02
edit→review cycle; different file, same owner, separate commits). The T#s
below remain as internal references for §2–§6 and the appendices.

| # | Task | Files touched | Owner | Size | Depends on |
|---|---|---|---|---|---|
| **T1** | **Clippy gate fix + dead-code removal** (scope amended per lead ruling 2026-09-11): (a) remove `#[must_use]` from `theme_for` (D7; `cosmic::Theme` already `#[must_use]`, `libcosmic:src/theme/mod.rs:182`) — no `#[allow]`; (b) delete `commands::line_count` (`src/commands.rs:177–181`, `#[allow(dead_code)]`) **and** its only caller, the `empty_document_has_one_line` test (364–368) — no other callers exist (all crate sources read; `tests/packaging.rs` cannot import the binary). Unit-test count 28→27; commit note mentions both changes (D7 requires reviewer verify no silent allow). | `src/config.rs` (1 line), `src/commands.rs` (2 deletions) | Architecture | S | — (do first; unblocks `-D warnings` for everything else) |
| **T2** | **Test seam**: split `App::init` → `init` + `with_config` (§3.5); add `#[cfg(test)] #[path] mod` line(s); create `src/app_test_harness.rs` (test_app/app_with_text/`test_tempdir` helpers per §3.4); **settle inside T02's task record — reviewer commitment, no silent deferral:** `fl!`-without-`i18n::init` (R5) and the `set_main_window_id` constant (R15). | `src/app.rs` (init region + 1–2 mod lines), new `src/app_test_harness.rs` | Architecture (**contested file — T2 lands before any UX view edits**, ruled; the diff is confined to the Architecture region per D5) | M | T1 |
| **T3** | **D8 strict-UTF-8 load**: `load_path` rejects invalid UTF-8 (`String::from_utf8` + named error dialog per DECISIONS D8), replacing lossy conversion (`src/app.rs:1273–1275`); update the in-source comment; add invalid-bytes test (D8 spec: `[0x66,0x6f,0x6f,0xff,0xfe]`, document untouched). Lock CRLF decision from spike (R10) with a round-trip test. | `src/app.rs` (load_path region), harness file | Architecture | M | T2 |
| **T4** | **Editing-message coverage** (§2.3 #1, 10–16, 29, 30): Editor edit/non-edit + undo snapshotting, Undo/Redo (+cap-100 eviction, edit-clears-redo), Cut/Copy state effects, ClipboardPaste, Delete, SelectAll, InsertDateTime format. **Plus (RV-1):** pure-fn test of `MenuAction::message()` — all 22 variants (198–227) → expected `Message` — and the `aligned_disabled_item` Go-To case (932–947: disabled item rendered iff `config.word_wrap`). New `src/app_edit_tests.rs`. | new test file + 1 mod line in `src/app.rs` | Architecture | M | T2 |
| **T5** | **Find/Replace/GoTo coverage** (#17–28 + flows F14–F16): prefill rules, wrap-around, match-case, not-found dialogs, replace-one chain, replace-all single-undo-step, GoTo prefill/validation errors/wrap-disabled no-op. **Carries (RV-12 → ux.md UX-D9):** a code comment in `commands.rs` recording the accepted `to_lowercase`-vs-v2-`casefold` micro-deviation. New `src/app_search_tests.rs`. | new test file + 1 mod line; `src/commands.rs` (comment only) | Architecture | M | T2 |
| **T6** | **File-lifecycle coverage** (#2–9, 42–45, 47–48 + hooks + flows **F1**–F13, F22 — F1 added per RV-4, nearly free: #2's clean branch + untitled-title assert): guard matrix (4 `AfterSave` × dirty/clean), DialogSave continuation (with/without path), stale-prompt clearing (1306–1313), CloseError re-raise, Cancelled semantics, save/load error dialogs, Exit retarget, `on_escape`/`on_app_exit`/`on_close_requested`, `OpenExternal`, argv-init load — all on tempdirs. New `src/app_file_tests.rs`. | new test file + 1 mod line | Architecture | L | T2, T3 |
| **T7** | **Settings/theme/font coverage + persistence tests** (#31–39, 41, 46 + flows F17–F19 **and F20** — Ln/Col app-side, RV-4; §5.6): toggles + on-disk RON assertions via `with_custom_path`, ApplyFont state machine, scheme decisions (`theme_for`/`pin_independent` pure tests), `UpdateConfig` (font re-derive, set_theme-only-on-scheme-change), `ToggleContextPage`, header_title matrix, **invalid-config fallback test (RV-5, §5.6)**. New `src/app_settings_tests.rs`. | new test file + 1 mod line; possibly `src/config.rs` (pure `theme_for` tests inline) | Architecture | M | T2 |
| **T8** | **single_instance server testability**: extract `subscription_at(path)` from `subscription()` (`src/single_instance.rs:95–118`); public `subscription()` delegates. Test: bind temp socket on a tokio current-thread runtime, `forward_to`, assert yielded paths + ack; stale-socket unlink test. Optional R9 logging. | `src/single_instance.rs` | Architecture | S–M | — (independent of T2; parallelizable) |
| **T9** | **Cross-flow integration scripts** (§4.3 multi-hop chains not already inside T4–T7: F5+F6 continuation/abort interplay, F7+F8 failure-retry-stale-prompt, F10 two-hop open, F21+F22 exit/second-instance combos). New `src/app_flow_tests.rs`. | new test file + 1 mod line | Architecture | M | T4–T7 |
| **T10** | *(**DEFERRED** per lead ruling 2026-09-11 — reviewer-gated)* **Clipboard payload seam**: extract pure `selection_text(&self) -> Option<String>` used by Cut/Copy (#12–13) so the clipboard payload itself is assertable (§3.6). Becomes a task only if the adversarial Phase-1 review requires payload-level proof. | `src/app.rs` (689–700), test file | Architecture | S | T4 + reviewer demand |

Sequencing notes for the lead:

- **T1 immediately** (gate is red today, D7).
- **T2 is the contested-file event — RULED (lead, 2026-09-11):** T2 lands
  **before any UX view edits** (sequenced in PLAN.md), and the `app.rs` →
  `app/mod.rs` + `app/view.rs` split is **not happening now** — D5 region
  ownership plus the post-T2 pattern (new Architecture-owned test files + one
  mod line each) keeps conflicts near zero; revisit only if real friction
  materializes in Phase 2.
- T8 has no dependency on the app.rs seam and can run in parallel with T2–T3
  (different file, same owner).
- Adjacent Architecture-owned items from DECISIONS that ride other tasks (not
  re-listed as mine): D10 `Cargo.toml` libcosmic `rev` pin (with packager's
  vendoring task), D6/D11 gate scripts (packaging-owned).

---

## Appendix A — Parity matrix (v2.0.4 → v3.0.0)

Status: ✅ implemented (evidence cited); 🔒 implemented + test-locked today;
🧪 implemented, test lock planned in §7 (task noted); ⚠ documented deviation.

| Feature | v2.0.4 evidence | v3.0.0 evidence | Status |
|---|---|---|---|
| New/Open/Save/Save As + shortcuts | `window.py` QActions Ctrl+N/O/S/Shift+S | `src/app.rs:631–663`, `src/key_bind.rs` | 🧪 T6 |
| Unsaved-changes guard (Save/Discard/Cancel) incl. close & second-instance | `window.py` `_guard_unsaved`, `closeEvent` | `guard_unsaved/proceed/AfterSave` (`src/app.rs:60–67, 1242–1258`), hooks (886–899) | 🧪 T6 (F2–F8) |
| Save-then-continue across Save-As dialog | `window.py` proceed-after-clean | `pending_after` + `write_to` continuation (830–835, 1299–1325) | 🧪 T6/T9 |
| Exit (Ctrl+Q) with guard | `window.py` close action | #9 (664–670) | 🧪 T6 |
| Open-with argv / second instance forwarding | `application.py` socket protocol; `main.py` | `src/main.rs:33–41`; `src/single_instance.rs`; #5 (641–653) | 🔒 client side (`single_instance.rs:144–182`); server 🧪 T8; app-side 🧪 T6 |
| Undo/Redo (Ctrl+Z/Y) | `QTextDocument` stack, `undoAvailable` actions | snapshot stacks (107–108, 671–688) | ⚠ capped at 100 (R7, deliberate); 🧪 T4 |
| Cut/Copy/Paste/Delete (Ctrl+X/C/V, Del) | QActions + clipboard | #12–16 (689–717) | 🧪 T4 |
| Select All (Ctrl+A) | QAction | #29 (767) | 🧪 T4 |
| Find bar (Ctrl+F), Find Next (F3), match case, wrap-around, not-found alert | `window.py` FindBar; `commands.py` find_next | find bar (1049–1107); #17–18; `src/commands.rs:87–106` | 🔒 commands (22 tests); app-side 🧪 T5 |
| Replace / Replace All (Ctrl+H), single undo step for replace-all | `window.py` ReplaceDialog; `commands.py` | #20–21; `src/commands.rs:109–174` | 🔒 commands; app-side 🧪 T5 (F15) |
| Go To Line (Ctrl+G), validation errors, disabled under wrap | `window.py` GoToDialog + `on_toggle_wrap` | #26–28 (738–766, 1207–1240) | 🧪 T5 (F16) |
| Word wrap toggle (Format menu) + status label | `window.py` Format menu, wrap_label | #31 (774–777), footer (559–563) | 🧪 T7 |
| Status bar toggle + `Ln {l}, Col {c}` | `window.py` pos_label, cursorPositionChanged | footer (551–573) + `caret_line_col` (`src/commands.rs:221–245`) | 🔒 pure fn (equivalence corpus 432–460); app-side 🧪 T7 (F20) |
| Time/Date insert (F5), `%-I:%M %p %-m/%-d/%Y` | `window.py` on_insert_datetime | #30 + `datetime_stamp` (1446–1459) | 🧪 T4 |
| Font family/size dialog | `QFontDialog` | PendingDialog::Font (501–538, 782–803), 14 families/sizes (35–52) | 🧪 T7 (F17) |
| Color scheme System/Light/Dark + header toggle + persistence | `theme.py` (palettes, QSettings) | `src/config.rs`; #38–39; header_end (418–441) | ⚠ palettes → COSMIC semantic tokens (per rewrite plan; contrast tests out of scope); 🧪 T7 |
| System dark-mode tracking | `theme.py` system_is_dark | `system_theme_update` (901–911) + `theme_for(System)` | 🧪 T7 (decision-level) |
| Title `•  name — NotePad` dirty marker | `window.py` modificationChanged | `update_title` (1022–1038) | 🧪 T4/T6 |
| Error dialogs (could-not-open/save, cannot-find, goto) | QMessageBox paths | PendingDialog::Error + GoTo errors (457–549, 1134–1136, 1210–1236) | 🧪 T5/T6 |
| Strict UTF-8 open (reject invalid) | `window.py:618–628` (per D8) | currently lossy (1273–1275) | ⚠ **open gap — DECISIONS D8, task T3** |
| CRLF handling on load/save | Python universal newlines (normalizes CRLF→LF, rewrites on save) | per-line LineEnding preservation — spike-confirmed byte-faithful (§3.3, R10) | ⚠ deliberate improvement over parity; lock with test in T3 |
| Keyboard shortcut set | QAction shortcuts | `src/key_bind.rs` (17) + `editor_key_binding` (1391–1411: F5/F3/Ctrl+F/H/G/N/O/S/Shift+S/Q/Z/Shift+Z/Y) | 🧪 T4 (binding-map unit test, pure fn) |
| Menus File/Edit/Format/View/Help | `window.py` menu bar | header_start (361–416) | view region (UX); structure 🧪 T4 / PLAN T09 (RV-1: no test exists yet — pure-fn test of `MenuAction::message()` (198–227), all 22 variants → expected `Message`, plus the `aligned_disabled_item` Go-To case (932–947)) |
| About dialog | QMessageBox about | context drawer (443–455) | view region (UX) |
| i18n | Qt .ts | fluent `i18n/en/notepad.ftl` + `src/i18n.rs` | ✅ (R5 verification pending for tests) |
| Single window, 820×600 default, min size | `window.py` resize/minimumSize | `src/main.rs:47–49` | ✅ smoke-covered (D11) |
| Flatpak packaging | KDE manifest | `com.goshapps.Notepad.json` + `tests/packaging.rs` (6 tests) | 🔒 packaging; smoke per D11/D13 |

## Appendix B — v2.0.4 test suite → v3.0.0 coverage map

| v2.0.4 test (`v2.0.4:tests/`) | Contract it pinned | v3.0.0 equivalent |
|---|---|---|
| `test_commands.py` (find/replace/goto incl. replace-all single undo step) | search/replace semantics | 🔒 `src/commands.rs:272–472` (22 tests, incl. UTF-8/CJK); app-level replace-all undo step → T5 (F15) |
| `test_window.py` (find-bar visibility/focus, Esc closes) | find-bar state machine | visibility/Esc → message-level tests T5 (`find_visible`, `on_escape` 869–884); widget *focus* not unit-testable → **Phase-3 manual verification** (RV-10: smoke criteria contain no focus assertion) |
| `test_application.py` (external open preserves unsaved text; open_paths routing via fakes) | second-instance guard chain | → T6/T9 (F21: `OpenExternal` dirty ⇒ `SaveChanges{OpenPath}`, Discard ⇒ loads) |
| `test_theme.py` (WCAG contrast ratios, palette application, QSettings roundtrip) | theme correctness + persistence | contrast/palette: **out of scope** (COSMIC semantic tokens replace hand-rolled palettes per `plans/libcosmic-rewrite.md`); persistence roundtrip → T7 (§5.6, `with_custom_path`) |
| `test_packaging.py` (license/version/runtime asserts) | packaging metadata | 🔒 `tests/packaging.rs` (6 tests: BaseApp runtime, `xdg-config/cosmic:rw`, version consistency, license/identity) |

Coverage totals today: 28 unit (22 commands + 3 single_instance + 3 app) + 6
packaging (27 after T01's dead-code removal). The §7 plan adds Message-level
coverage for **47 of 48 variants** — #40 `LaunchUrl` is excluded by design
(R3: immediate `open::that_detached` side effect inside `update()`), with
reviewer sign-off; manual/smoke coverage only (RV-3) — plus flows F1–F22. The
charter's "every Message variant update() handles" requirement maps 1:1 onto
the §2.3 matrix rows, with row #40 as the single documented exclusion;
T4–T7 partition it, T9 adds multi-hop chains.

## Appendix C — libcosmic evidence index (rev d4d71fd5)

Checkout root: `~/.cargo/git/checkouts/libcosmic-41009aea1d72760b/d4d71fd/`.

| Topic | Location |
|---|---|
| `Application` trait (hooks, `update` sig 465, `init` 348) | `src/app/mod.rs:323–488` |
| `Task<M>` alias / `Action<M>` | `src/app/mod.rs:18`; `src/action.rs:23` |
| Runtime dispatch (App msg 512, Escape 887, theme 922, Close 1081–1087, exit-on-close 1243–1252, subscriptions 591) | `src/app/cosmic.rs` |
| `Settings` (exit_on_close, size) → Core overrides | `src/app/settings.rs`; `src/app/mod.rs:62–72` |
| `Core` (Default 133, `main_window_id` 453, `set_main_window_id` ~458, `watch_config` 386–403) | `src/core.rs` |
| THEME static (47–52), `is_dark` (77), `system_preference` (119–132), `#[must_use] Theme` (182) | `src/theme/mod.rs` |
| `set_theme` command (lazy) | `src/command.rs:36` |
| `set_window_title` (two-arg, multi-window default feature) | `src/app/mod.rs:597`; `Cargo.toml:11–19` |
| file_chooser portal dialogs, `Error::Cancelled` | `src/dialog/file_chooser/mod.rs:123` |
| `Content<R>` (397–399), API (408–501), `text()` rejoin (468–485) | `iced/widget/src/text_editor.rs` |
| editor `Action`/`Edit`/`Motion`/`Cursor`/`LineEnding` (70–149, 203, 231) | `iced/core/src/text/editor.rs` |
| CPU-only `with_text` (89–111), line-ending mapping (120–131), `perform` (237+) | `iced/graphics/src/text/editor.rs` |
| clipboard `read()`/`write(String)` | `iced/runtime/src/clipboard.rs:64, 84` |
| `window::close_requests` subscription | `iced/runtime/src/window.rs:291` |
| Renderer chain (`cosmic::Renderer` = fallback<wgpu, tiny_skia>) | `src/lib.rs:183`; `iced/renderer/src/lib.rs:27`; `iced/renderer/src/fallback.rs:97`; `iced/wgpu/src/lib.rs:768–771` |
| cosmic-config: dirs (15–36), `new` (215–250), `with_custom_path` (253), atomic writes (319–476), watch (332–385) | `cosmic-config/src/lib.rs` |
| config watch subscription | `cosmic-config/src/subscription.rs` |
| `CosmicConfigEntry` derive (VERSION/write_entry/get_entry) | `cosmic-config-derive/src/lib.rs:183–215` |

*End of document.*

