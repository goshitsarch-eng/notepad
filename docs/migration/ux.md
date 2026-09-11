# NotePad — UX parity inventory (v2.0.4 Qt → v3.0.0 libcosmic)

**Phase 1 deliverable — UX teammate.** No source changes; this document only.

*Rev 3 — reviewer Phase-1 pass (`review-phase1.md`): **ACCEPT WITH
OBJECTIONS** on ux.md; lead accepted every finding (PLAN.md rev 2). This rev
applies the four ux-owned doc fixes: **RV-8** (§4 unused-ftl-key count
corrected 2→4 with per-key dispositions, incl. the lead ruling deleting
`app-keywords` in T17), **RV-7** (§1.4/§3.7/§8 Go-To editor-refocus gap →
PLAN T22), **RV-12/13/14** (§7 D-9/D-10/D-11 = UX-D9/D10/D11 accepted
micro-deviations), and §6 decision-log sync (incl. the final PLAN T-#→T##
mapping).*

*Rev 2 — lead review: **ACCEPTED**; rulings on T-6/T-1/T-8 and the D12
sign-off recorded in §6; ux.md deviation D-5 resolved (strict reject,
DECISIONS.md D8); evidence preamble corrected per DECISIONS.md D3 addendum
(no installed 2.0.4 Flatpak).*

This file inventories every user-visible behavior of NotePad **2.0.4** (Python 3 +
PySide6 / Qt 6, the parity reference) and maps it to its **libcosmic (COSMIC)**
equivalent, then classifies the current **3.0.0** working-tree implementation.

- 2.0.4 evidence is cited as `~/.cache/notepad-v2.0.4/<file>:<line>` (the
  source cache). Per the DECISIONS.md D3 addendum (2026-09-11) **no 2.0.4
  Flatpak is installed anywhere visible**, so live A/B runtime comparison is
  unavailable — see §6 "Verification-context correction".
- 3.0.0 evidence is cited as `src/<file>:<line>` in the repo
  (`/home/gosh/Documents/GitHub/notepad`).
- Toolkit facts are cited from the pinned libcosmic checkout
  (`~/.cargo/git/checkouts/libcosmic-41009aea1d72760b/d4d71fd`, rev `d4d71fd`).

**The 2.0.4 Python tests are behavior gold.** Where a test pins exact behavior
(time/date format, find-wrap semantics, replace counts, unsaved-guard routing,
find-bar focus/close), that test is cited and treated as the contract 3.0.0 must
meet.

## Status legend

| Status | Meaning |
|---|---|
| **Implemented** | Behavior matches 2.0.4 (or is a faithful COSMIC rendering of it). |
| **Partial** | Behavior exists but is incomplete / subtly differs / not verified at runtime. |
| **Gap** | User-visible 2.0.4 behavior is missing or broken in 3.0.0. |
| **Deviation** | Deliberate COSMIC-convention replacement of Qt behavior (see §7). |

Anything that can only be settled by launching the app is tagged
**needs runtime check (Phase 3)**.

Verification-method key used in the checklist: **U** = `cargo test` unit test,
**M** = manual GUI check, **S** = Flatpak smoke test, **R** = runtime check
deferred to Phase 3.

---

## 1. Canonical parity checklist

One row per user-visible behavior. This is the table `PLAN.md` should reference.

### 1.1 Window, chrome, and layout

| Item | v2.0.4 behavior (evidence) | COSMIC / libcosmic mapping | 3.0.0 status (evidence) | Verify |
|---|---|---|---|---|
| Main window | Single `QMainWindow` document window (`window.py:213`, `application.py:161-164`). | `cosmic::Application` main window (`app.rs:287-291`). | **Implemented** — one `App` window (`app.rs:287`). | M/S |
| Default size | `resize(820, 600)` (`window.py:226`). | `Settings.size(820×600)` (`main.rs:48`). | **Implemented** (`main.rs:48`). | M |
| Min window size | No explicit minimum (Qt `minimumSizeHint`). | `size_limits(min 360×180)` (`main.rs:49`). | **Deviation** — 3.0.0 adds an explicit 360×180 min so the find bar can wrap (`main.rs:49`, `app.rs:1054-1056`). 2.0.4 could shrink smaller. | M |
| Window title format | `"{marker}{name} — NotePad"`, `marker = "•  "` (bullet + 2 spaces) when modified, `name = basename or "Untitled"` (`window.py:412-415`). | `set_header_title` + `set_window_title`, same format (`app.rs:1022-1038`). | **Implemented** — `format!("{marker}{name} — {}", app-title)`, marker `"•  "` (`app.rs:1030-1031`). Byte-identical format. | U/M |
| Header bar | Qt menubar (`window.py:320`) + non-movable toolbar with right-aligned theme button (`window.py:375-390`). | libcosmic header: `header_start` = menu bar, `header_end` = scheme button (`app.rs:361-441`). | **Deviation** (COSMIC header bar) — menubar in header, scheme button right of header. See §7. | M |
| Editor area | `QPlainTextEdit`, `NoWrap` by default, fixed font (`window.py:228-230`). | `widget::text_editor::text_editor(&content)` (`app.rs:589-595`). | **Implemented** (`app.rs:589`). | M |
| Status bar / footer | `QStatusBar` with left `wrap_label` + right permanent `pos_label` (`window.py:393-397`). | `Application::footer()` row: wrap text left, `Ln/Col` right (`app.rs:551-573`). | **Implemented** (`app.rs:564-571`). | M |
| Inline find bar | `FindBar` widget above editor, hidden by default (`window.py:52-99`, `363-373`). | Row(s) pushed above editor when `find_visible` (`app.rs:578-579`, `1049-1107`). | **Implemented** (placement) (`app.rs:576-579`). | M |
| About surface | `QMessageBox.about` modal (`window.py:452-461`). | `context_drawer::about` (`app.rs:443-455`). | **Deviation** — About moved to context drawer (COSMIC convention; plan `libcosmic-rewrite.md:44`). Content differs, see §1.5 and §5. | M |

### 1.2 Menus — structure and every item

2.0.4 menus: `window.py:320-361` (`_build_menus`), actions `window.py:265-314`.
3.0.0 menus: `app.rs:366-410` (`header_start`), `edit_menu_items` `app.rs:915-956`,
`view_menu_items` `app.rs:958-996`. Labels from `i18n/en/notepad.ftl`.

| Menu | Item (2.0.4 label / shortcut, evidence) | 3.0.0 label / action (evidence) | Status | Verify |
|---|---|---|---|---|
| **File** | `&New` / Ctrl+N (`window.py:265,324`) | `New` → `MenuAction::New` (`app.rs:372`, ftl `new`) | **Implemented** | M |
| | `&Open…` / Ctrl+O (`window.py:266,325`) | `Open…` → `Open` (`app.rs:373`, ftl `open`) | **Implemented** | M |
| | `&Save` / Ctrl+S (`window.py:267,326`) | `Save` → `Save` (`app.rs:374`, ftl `save`) | **Implemented** | M |
| | `Save &As…` / Ctrl+Shift+S (`window.py:268-270,327`) | `Save As…` → `SaveAs` (`app.rs:375`, ftl `save-as`) | **Implemented** | M |
| | `E&xit` / Ctrl+Q (`window.py:271,328`) | `Exit` → `Exit` (`app.rs:376`, ftl `exit`) | **Implemented** | M |
| **Edit** | `&Undo` / Ctrl+Z (`window.py:273,331`) | `Undo` → `Undo` (`app.rs:919`) | **Implemented** | M |
| | `&Redo` / Ctrl+Y (`window.py:274,332`) | `Redo` → `Redo` (`app.rs:920`) | **Implemented** | M |
| | separator (`window.py:333`) | `Divider` (`app.rs:921`) | **Implemented** | M |
| | `Cu&t` / Ctrl+X (`window.py:275,334`) | `Cut` → `Cut` (`app.rs:922`) | **Implemented** | M |
| | `&Copy` / Ctrl+C (`window.py:276,335`) | `Copy` → `Copy` (`app.rs:923`) | **Implemented** | M |
| | `&Paste` / Ctrl+V (`window.py:277,336`) | `Paste` → `Paste` (`app.rs:924`) | **Implemented** | M |
| | `&Delete` / Del (`window.py:278,337`) | `Delete` → `Delete` (`app.rs:925`) | **Deviation** — see §1.6 (Delete with no selection). | M |
| | separator (`window.py:338`) | `Divider` (`app.rs:926`) | **Implemented** | M |
| | `&Find…` / Ctrl+F (`window.py:279,339`) | `Find…` → `Find` (`app.rs:927`) | **Implemented** | M |
| | `Find &Next` / F3 (`window.py:280,340`) | `Find Next` → `FindNext` (`app.rs:928`) | **Partial** — fires from editor focus; F3 from find-bar focus is a gap (§1.6). | M/R |
| | `&Replace…` / Ctrl+H (`window.py:281,341`) | `Replace…` → `Replace` (`app.rs:929`) | **Deviation** — inline bar, not modeless dialog (§7). | M |
| | `&Go To…` / Ctrl+G (`window.py:282,342`) | `Go To…` → `GoTo` (`app.rs:938-946`) | **Implemented** | M |
| | `Select &All` / Ctrl+A (`window.py:283-285,343`) | `Select All` → `SelectAll` (`app.rs:951`) | **Implemented** | M |
| | `Time/&Date` / F5 (`window.py:286-288,344`) | `Time/Date` → `InsertDateTime` (`app.rs:952`) | **Implemented** | U/M |
| **Format** | `&Word Wrap` (checkable, off) (`window.py:290-292,347`) | `Word Wrap` CheckBox(`wrap`) → `ToggleWrap` (`app.rs:389`) | **Implemented** | M |
| | `&Font…` (`window.py:293,348`) | `Font…` → `Font` (`app.rs:390`) | **Partial** — dialog is a reduced picker (§1.5). | M |
| **View** | `&Status Bar` (checkable, checked) (`window.py:295-297,351`) | `Status Bar` CheckBox(`show_status_bar`) → `ToggleStatusBar` (`app.rs:961-967`) | **Implemented** | M |
| | `&Color Scheme` submenu (`window.py:352`) | `Color Scheme` folder (`app.rs:969`) | **Implemented** | M |
| | ↳ `System`/`Light`/`Dark` (radio, exclusive) (`window.py:302-312,353-358`) | ↳ `System`/`Light`/`Dark` CheckBox reflecting `config.color_scheme` (`app.rs:973-991`) | **Implemented** (radio→single-check semantics equivalent) | M |
| **Help** | `&About NotePad` (`window.py:314,361`) | `About NotePad` → `ToggleContextPage(About)` (`app.rs:402-407`) | **Deviation** — opens drawer (§7). | M |

**Menu enabled-state (greying) parity:** see §1.6 — a real gap.

### 1.3 Keyboard shortcuts

2.0.4 binds shortcuts as window-global `QAction`/`QKeySequence`
(`window.py:265-288`); they fire regardless of which child widget has focus.
3.0.0 declares shortcuts in two places: the **`key_binds` map**
(`key_bind.rs:17-93`) — used by `menu::items` **for display only** (libcosmic
`menu_tree.rs:220-254`, `find_key` just renders the string) — and the
**`editor_key_binding` closure** (`app.rs:1391-1411`) registered on the
`text_editor` (`app.rs:595`), which fires **only while the editor has focus**.
There is no app-level global key handler in libcosmic's `Application` trait
(no `on_key_press`; confirmed in `src/app/mod.rs`).

| Shortcut | Action | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|---|
| Ctrl+N | New | `window.py:265` | `key_bind.rs:18-22`; `app.rs:1399` | **Implemented** (editor focus) | M/R |
| Ctrl+O | Open | `window.py:266` | `key_bind.rs:23-27`; `app.rs:1400` | **Implemented** (editor focus) | M/R |
| Ctrl+S | Save | `window.py:267` | `key_bind.rs:28-32`; `app.rs:1402` | **Implemented** (editor focus) | M/R |
| Ctrl+Shift+S | Save As | `window.py:268-270` | `key_bind.rs:33-37`; `app.rs:1401` | **Implemented** (editor focus) | M/R |
| Ctrl+Q | Exit | `window.py:271` | `key_bind.rs:38-42`; `app.rs:1403` | **Implemented** (editor focus) | M/R |
| Ctrl+Z | Undo | `window.py:273` | `key_bind.rs:43-47`; `app.rs:1405` | **Implemented** | M |
| Ctrl+Y | Redo | `window.py:274` | `key_bind.rs:48-52`; `app.rs:1406` | **Implemented** | M |
| Ctrl+Shift+Z | Redo | *not bound* | `app.rs:1404` | **Deviation** — extra binding, editor-only, not shown in menu | M |
| Ctrl+X | Cut | `window.py:275` | `key_bind.rs:53-57` (display); text_editor built-in `from_key_press` | **Implemented** | M |
| Ctrl+C | Copy | `window.py:276` | `key_bind.rs:58-62`; built-in | **Implemented** | M |
| Ctrl+V | Paste | `window.py:277` | `key_bind.rs:63-67`; built-in | **Implemented** | M |
| Delete | Delete | `window.py:278` (enabled only w/ selection) | `key_bind.rs:68` (display); built-in editor delete | **Deviation** (§1.6) | M |
| Ctrl+F | Find | `window.py:279` | `key_bind.rs:69-73`; `app.rs:1396` | **Implemented** (editor focus) | M/R |
| F3 | Find Next | `window.py:280` | `key_bind.rs:74`; `app.rs:1394` | **Partial** — not fired when find input focused (§1.6) | M/R |
| Ctrl+H | Replace | `window.py:281` | `key_bind.rs:75-79`; `app.rs:1397` | **Implemented** (editor focus) | M/R |
| Ctrl+G | Go To | `window.py:282` | `key_bind.rs:80-84`; `app.rs:1398` (only `!word_wrap`) | **Implemented** | M |
| Ctrl+A | Select All | `window.py:283-285` | `key_bind.rs:85-89`; built-in | **Implemented** | M |
| F5 | Time/Date | `window.py:286-288` | `key_bind.rs:90`; `app.rs:1393` | **Implemented** | U/M |
| Esc | Close find bar | `window.py:87-89` (find-bar-scoped `QShortcut`) | `app.rs:869-884` (`on_escape`) | **Implemented** (see §1.6 for focus) | M |

**Cross-cutting shortcut gap (G-1):** Because 3.0.0 shortcuts live on the
`text_editor`, they only fire while the editor has focus. With focus in the find
input, the replace input, or a dialog, **F3 / Ctrl+S / Ctrl+F / etc. do not
fire**, whereas 2.0.4's window-global `QAction`s did. Needs runtime confirmation
(R), then fix (§8, T-1). This is the single most likely reviewer-flagged parity
regression.

### 1.4 Find / Replace / Go-To flows

Find/replace/go-to logic lives in `commands.rs` (GUI-free, unit-tested) so the
2.0.4 `tests/test_commands.py` cases port directly.

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Find next from cursor/selection-end | `commands.py:38-56`; test `test_commands.py:40-52` | `commands.rs:88-106`; `app.rs:1122-1139`; test `commands.rs:276-295` | **Implemented** | U |
| Find wraps to first match | `commands.py:50-51`; test `test_commands.py:54-59` | `commands.rs:101-105`; test `commands.rs:289-295` | **Implemented** | U |
| Case-insensitive default | `commands.py:13-17`; test `test_commands.py:61-64` | `commands.rs:20-37`; test `commands.rs:297-301` | **Implemented** (micro-difference: v2's `selection_matches` casefolds — full Unicode folding, `commands.py:35`; v3 lowercases, `commands.rs:81` — exotic Unicode only; accepted, §7 D-9/UX-D9) | U |
| Match case | test `test_commands.py:66-69` | `commands.rs:56-60`; test `commands.rs:303-308` | **Implemented** | U |
| Missing text → false, no crash | test `test_commands.py:71-74` | `commands.rs:95-96`; test `commands.rs:310-314` | **Implemented** | U |
| Find shows `Cannot find "…"` when not found | `window.py:542-543` | `app.rs:1132-1136` (`fl!("cannot-find")`) | **Implemented** | M |
| Prefill find from single-line selection | `window.py:522-530` | `app.rs:1109-1116` | **Implemented** | M |
| Find bar auto-focus + select-all on open | `window.py:93-95,506-509`; test `test_window.py:31-35` | `Message::Find` sets `find_visible=true` only, **no focus** (`app.rs:718-722`) | **Gap (G-2)** — 3.0.0 does not focus the find input on open | M/R |
| Find bar close returns focus to editor | `window.py:97-99`; test `test_window.py:46-62` | `CloseFind` sets `find_visible=false`, no explicit focus return (`app.rs:731-734`) | **Partial (G-3)** — focus return not guaranteed | M/R |
| Find bar visible close button (icon + tooltip) | `window.py:63-69`; test `test_window.py:37-44` | icon `window-close-symbolic` + tooltip `Close Find (Esc)` (`app.rs:1050-1052`) | **Partial** — tooltip present; accessible name missing (§1.7, A-1) | M/R |
| Escape closes find bar | `window.py:87-89`; test `test_window.py:55-62` | `on_escape` closes find (`app.rs:879-882`) | **Implemented** | M |
| Replace one then find next | `commands.py:70-87`; test `test_commands.py:78-90` | `commands.rs:110-147`; test `commands.rs:316-335`; `app.rs:1141-1178` | **Implemented** | U |
| Replace all + count | `commands.py:90-106`; test `test_commands.py:92-96` | `commands.rs:151-174`; test `commands.rs:337-342`; `app.rs:1180-1198` | **Implemented** | U |
| Replace all case-sensitive when asked | test `test_commands.py:98-102` | test `commands.rs:344-349` | **Implemented** | U |
| Replace all empty needle = no-op | test `test_commands.py:104-106` | test `commands.rs:351-356` | **Implemented** | U |
| Replace all = single undo step | test `test_commands.py:108-112` | `app.rs:1193-1196` (`push_undo` once, then `with_text`) | **Implemented** | U/M |
| `Cannot find "…"` on empty replace | `window.py:566-567,576-577` | `app.rs:1157-1160,1188-1191` | **Implemented** | M |
| Go To jumps to 1-based line | `commands.py:109-122`; test `test_commands.py:131-136` | `commands.rs:185-198`; test `commands.rs:371-374`; `app.rs:1207-1240` | **Implemented** | U |
| Go To rejects out-of-range | test `test_commands.py:138-146` | test `commands.rs:376-386` | **Implemented** | U |
| Go To invalid input → warning | `window.py:198-204` ("Please enter a valid line number.") | `app.rs:1209-1217` (`fl!("invalid-line-number")`) | **Implemented** | M |
| Go To beyond end → message | `window.py:585-587` ("The line number is beyond the total number of lines.") | `app.rs:1228-1236` (`fl!("line-beyond-end")`) | **Implemented** (kept in-dialog per bugfix #15, `app.rs:1228`) | M |
| Go To disabled while word wrap on | `window.py:440-441,580-581` | menu shows non-interactive row (`app.rs:932-936`); `Message::GoTo` guarded (`app.rs:739`); editor Ctrl+G gated (`app.rs:1398`) | **Implemented** | M |
| Go To dialog default = current line, select-all | `window.py:177-210` (entry = `current_line`, `selectAll`) | `app.rs:738-753` seeds `goto_input` from current line; **no select-all** | **Partial** — value pre-filled, but text not selected on open | M/R |
| Focus returns to editor after successful Go To | `window.py:588` (`self.edit.setFocus()` once the jump succeeds) | `confirm_goto` closes the dialog + moves the cursor; **no focus task** (`app.rs:1207-1240`); COSMIC's dialog-unmount refocus behavior **unproven** | **Gap (RV-7)** — keyboard user may land on the target line but be unable to type; same `Id`+focus-task mechanism as T-4. Scoped into PLAN T22 (§6, §8 T-10) | R |

### 1.5 Editing, format, and view behaviors

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Word wrap toggle | `window.py:290-292,433-438` (`NoWrap`↔`WidgetWidth`) | `config.word_wrap`; `Wrapping::Word`↔`None` (`app.rs:582-585,774-777`) | **Implemented** | M |
| Word-wrap status label | `window.py:394,439` ("Word Wrap: On/Off") | `app.rs:559-563` (`fl!("word-wrap-on/off")`) | **Implemented** | M |
| Status-bar toggle | `window.py:443-444` (`setVisible`) | `config.show_status_bar`; footer returns `None` when off (`app.rs:551-554,778-781`) | **Implemented** | M |
| Ln/Col live update | `window.py:417-421` on `cursorPositionChanged` | footer computes from `content.cursor()` each frame (`app.rs:555-558,568`) | **Implemented** | M |
| Ln/Col format | `"Ln {line}, Col {col}"` (`window.py:421`) | `ln-col = Ln { $line }, Col { $col }` (ftl:60) | **Implemented** | U/M |
| Ln/Col UTF-8 correctness | n/a (Qt block/col) | `caret_line_col` single-pass, boundary-safe (`commands.rs:222-245`; tests `commands.rs:390-460`) | **Implemented** (bugfix #7/#8) | U |
| F5 insert time/date | `window.py:427-431`: `strftime("%-I:%M %p %-m/%-d/%Y")` e.g. `3:04 PM 8/19/2026` | `app.rs:1446-1459` (`datetime_stamp`): unpadded hour (`%I` trim `0`, `12` fallback) + `%M` + `%p` + unpadded `M/D/YYYY` | **Implemented** — format matches exactly | U/M |
| F5 inserts at cursor as one undo step | `window.py:431` (`insertPlainText`) | `app.rs:768-773` (`push_undo` + `Edit::Paste`) | **Implemented** | M |
| Color scheme System/Light/Dark | `theme.py:29-32`, `window.py:298-312,464-467` | `config.rs:9-14`; `app.rs:958-996,1016-1020` | **Implemented** | M |
| Scheme follows system default | `theme.py:229-234` (`effective_is_dark`), default SYSTEM (`window.py:301`) | `config.rs:29` (default `System`); `app.rs:1002-1008` | **Implemented** | M |
| Scheme persists across restarts | `theme.py:237-248` (QSettings, key `color_scheme`) | `config.rs` via cosmic-config; `persist_config` (`app.rs:1010-1014`) | **Implemented** (Flatpak needs `xdg-config/cosmic:rw`, present `com.goshapps.Notepad.json:19`, test `packaging.rs:67-71`) | M/S |
| Invalid stored scheme → System | `theme.py:240-243`; test `test_theme.py:311-313` | `config.rs`/`Config::get_entry` falls back to default on error (`app.rs:304-306`) | **Implemented** | U |
| Live system theme change while System | Qt re-resolves palette | `system_theme_update` re-applies (`app.rs:901-911`) | **Implemented** | M/R |
| Scheme toggle button (header) | `window.py:384-390,469-503`: shows "Light" (sun icon) when dark else "Dark" (moon icon); toggles to opposite explicit scheme; tooltip "Switch to light mode"/"Toggle dark mode" | `app.rs:418-441`: label `Light`/`Dark`, icons `weather-clear-day/night-symbolic`, tooltips `switch-to-light`/`toggle-dark`, → `ToggleScheme` (`app.rs:805-812`) | **Implemented** — label/icon/tooltip/action parity | M |
| Font selection | `window.py:446-450`: native `QFontDialog.getFont` (full family list, styles bold/italic, sizes, live preview) | `app.rs:501-538`: custom dialog = 14-family dropdown + free-text family + 14-size dropdown; `font_from_family` forces `Weight::Normal`, `Style::Normal` (`app.rs:1427-1440`) | **Gap (G-4)** — no bold/italic/style, no live preview, family list is a fixed 14 (`app.rs:35-50`), no system font enumeration | M |
| Font persistence | *not persisted* in 2.0.4 (`window.py:446-450` sets `self._font` only) | persisted in `config.font_family`/`font_size` (`config.rs:22-23`, `app.rs:797-803`) | **Deviation** — 3.0.0 persists font (enhancement) | M |
| Default font | system fixed font (`window.py:224`) | `monospace`, size 14 (`config.rs:32-33`) | **Implemented** (equivalent monospace default) | M |
| Undo/Redo restore caret | Qt `QPlainTextEdit` keeps caret | `undo_stack`/`redo_stack` store `(text, cursor)`; `move_to(cursor)` on restore (`app.rs:107-108,671-687,1040-1047`) | **Implemented** (bugfix #6) | M |
| Undo depth | Qt document undo (effectively unbounded within session) | `MAX_UNDO_DEPTH = 100` snapshots (`app.rs:1442-1447`) | **Deviation** — bounded to 100 (memory guard) | M |

### 1.6 Menu enabled-state and Delete (behavioral gaps)

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Cut/Copy/Delete greyed without selection | `window.py:406-410` (`setEnabled(has_selection)`) | menu items always active; `CheckBox(false,…)` has no disabled visual (only Go To gets a non-interactive row, `app.rs:932-936`) | **Gap (G-5)** — 3.0.0 never greys Cut/Copy/Delete | M/R |
| Undo/Redo greyed when unavailable | `window.py:316-317,400-404` | always active; clicking with empty stack is a silent no-op (`app.rs:671-687`) | **Gap (G-5)** — no visual disabled state | M/R |
| Delete with no selection | action disabled → no-op (`window.py:278,410`); `on_delete` only `removeSelectedText` (`window.py:424-425`) | `Message::Delete` always `Edit::Delete` (deletes next char) (`app.rs:713-716`); editor built-in also deletes char | **Deviation** — 3.0.0 deletes next char (classic-Notepad), chosen by bugfix #10 (`bugfix-pass.md:46`) | M |
| Delete/cut/copy still function when invoked with selection | `window.py:424-425` etc. | `app.rs:689-716` (guard on `selection()`) | **Implemented** (function correct; only the greying differs) | M |

### 1.7 File operations and unsaved-changes guards

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Open dialog | `QFileDialog.getOpenFileName`, start = current dir, filter "Text files (*.txt);;All files (*)" (`window.py:600-611`) | portal `file_chooser::open::Dialog`, same title/filters/start dir (`app.rs:1327-1346`) | **Deviation** (portal vs Qt dialog; plan `libcosmic-rewrite.md:21`) — functionally equivalent | M/S/R |
| Save (existing path) | writes directly (`window.py:630-633`) | `write_to` (`app.rs:1292-1325`) | **Implemented** | M |
| Save (untitled) → Save As | `window.py:633-634` | `save(false)` → `save_as_dialog` (`app.rs:1292-1296`) | **Implemented** | M |
| Save As default filename | `basename` or `"Untitled.txt"` (`window.py:636-645`) | `file_name` or `fl!("untitled") + ".txt"` (`app.rs:1348-1356`) | **Implemented** (bugfix #14 localized) | M |
| Save As dialog | `QFileDialog.getSaveFileName`, same filters (`window.py:640-645`) | portal save dialog, same title/filters (`app.rs:1361-1378`) | **Deviation** (portal) | M/S/R |
| Write UTF-8, update title/clear dirty | `window.py:649-659` | `app.rs:1299-1316` | **Implemented** | M |
| Save error → dialog | `window.py:654-655` ("Could not save file:\n{err}") | `app.rs:1318-1323` (`fl!("could-not-save")`) | **Implemented** | M |
| Open/load UTF-8 **strict** | `open(path, encoding="utf-8")`; `UnicodeDecodeError` → "Could not open file" dialog (`window.py:618-628`) | `from_utf8_lossy` — never fails, replaces invalid bytes with U+FFFD (`app.rs:1269-1290`) | **Deviation (D-5) — WILL BE FIXED**: strict reject decided (§6, T-6; DECISIONS.md D8); current code opens lossily and can corrupt on re-save | M/R |
| Load error (OS) → dialog | `window.py:622-624` ("Could not open file:\n{err}") | `app.rs:1283-1289` (`fl!("could-not-open")`) | **Implemented** | M |
| Open non-file URL/URI | n/a (Qt path) | `url.to_file_path()` err → `could-not-open` dialog (`app.rs:633-640`) | **Implemented** | M |
| Unsaved guard: New | `_guard_unsaved(_reset_document)` (`window.py:591-592`) | `guard_unsaved(AfterSave::New)` (`app.rs:631,1242-1249`) | **Implemented** | M |
| Unsaved guard: Open | `window.py:600-612` | `app.rs:632` | **Implemented** | M |
| Unsaved guard: external/2nd-instance open | `open_path` guarded (`window.py:614-616`); test `test_application.py:33-42` | `OpenExternal → guard_unsaved(OpenPath)` (`app.rs:641-652`) | **Implemented** | U/M |
| Unsaved guard: Exit / window close | `closeEvent` (`window.py:687-711`); Exit action → `self.close` (`window.py:271`) | `Message::Exit` (`app.rs:664-669`), `on_app_exit` (`app.rs:886-888`), `on_close_requested` (`app.rs:890-899`), `window::close_requests` sub (`app.rs:606`) | **Implemented** (bugfix #1; `exit_on_close(false)` `main.rs:52`) | M |
| Guard dialog buttons + default | Title "Save changes?", text "Save changes?", info "Your changes will be lost…", **Save**(default)/**Discard**(destructive)/**Cancel** (`window.py:666-682`) | Title `save-changes`, body `save-changes-body`, primary `Save`(suggested)/secondary `Cancel`/tertiary `Discard`(destructive) (`app.rs:460-475`) | **Implemented** — same copy, same 3 buttons; default = Save (primary) | M/R |
| "Save" continues original action | `window.py:677-680` (Save → `on_save`; proceed if not modified) | `DialogSave` stashes `after` in `pending_after`; `write_to` success → `proceed(after)` (`app.rs:830-835,1306-1316`) | **Implemented** (bugfix #2) | M |
| "Save" error keeps pending action | (2.0.4: modal Save As, cancel aborts) | `CloseError` restores `SaveChanges` from `pending_after` (`app.rs:843-849`); `Cancelled` clears it (`app.rs:861-863`) | **Implemented** (bugfix #3) | M |
| "Discard" proceeds without saving | `window.py:681-682` | `DialogDiscard` sets `saved_text` then `proceed` (`app.rs:836-842`) | **Implemented** | M |
| "Cancel"/Esc aborts, window stays | `window.py:683,710-711` (`event.ignore()`) | `DialogCancel` clears pending (`app.rs:826-829`); `on_escape` clears (`app.rs:869-873`) | **Implemented** | M |
| Close with clean doc exits | `window.py:688-690` | `proceed(Close)` → `close_window` (`app.rs:1256,1381-1388`) | **Implemented** | M |
| Dirty tracking (saved baseline) | `document.isModified()` (`window.py:233,663`) | `is_dirty() = content.text() != saved_text`; baseline re-snapshotted after new/load/save (`app.rs:998-1000,347,1262,1277,1304`) | **Implemented** (bugfix #4 avoids false-dirty) | U/M |

### 1.8 Single-instance and CLI

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Socket path | `$XDG_RUNTIME_DIR/com.goshapps.Notepad.sock` (`application.py:22-24`) | same (`single_instance.rs:24-28`) | **Implemented** | U |
| 2nd instance forwards file args | `application.py:66-86`, `main.py:23-24` | `single_instance.rs:33-68`, `main.rs:39-41` | **Implemented** | U/M |
| Protocol (newline paths + 1-byte ack) | `application.py:77-81,140` | `single_instance.rs:54-64,112` | **Implemented** | U (`single_instance.rs:145-182`) |
| Stale socket reclaimed | `application.py:91-101` | `unlink_if_stale` (`single_instance.rs:71-81,99`) | **Implemented** | U |
| Ack race fixed (non-blocking read) | (2.0.4 blocking enough) | tokio `read_to_end` then always ack (`single_instance.rs:107-114`) | **Implemented** (bugfix #5) | U |
| Received path opens via guard | `open_paths → open_path` (`application.py:166-169`); test `test_application.py:44-56` | `OpenExternal → guard_unsaved(OpenPath)` (`app.rs:641-646`) | **Implemented** | U/M |
| 2nd launch (no args) focuses window | `open_paths(present=True)` show/raise/activate (`application.py:170-173`) | empty payload → `window::gain_focus` (`app.rs:642-648`; `single_instance.rs:114`) | **Partial** — focus raised; "present/unminimize" equivalence **needs runtime check** | M/R |
| CLI file arg opens file | `main.py:17-27` | `main.rs:33-54` (`Flags.files` → `load_path`, `app.rs:354-356`) | **Implemented** | M/S |
| CLI ignores `-`-prefixed args | `main.py:19-20` | `main.rs:35` | **Implemented** | M |
| Only first file opened | `application.py:168-169` (`files[0]`) | `app.rs:354,644` (`.first()`/`.next()`) | **Implemented** (both open one file) | M |
| Relative CLI path resolved | `os.path.abspath` (`main.py:18`) | `abs_path` vs cwd (`main.rs:18-27`) | **Implemented** | M |

### 1.9 About and error surfaces

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| About content | Title "About NotePad"; HTML body: `NotePad {version}`, "A native Qt 6 clone of Microsoft Notepad.", Kirigami line, "Made by Gosh.", "© 2026 Gosh — GPL-3.0-or-later" (`window.py:452-461`) | `About` drawer: name `app-title`, icon, version `CARGO_PKG_VERSION`, repository link, license `CARGO_PKG_LICENSE` (`app.rs:311-316,443-455`) | **Deviation + Gap (G-6)** — presentation changed (drawer, expected) but **`author`/`comments`/`copyright` fields are unset** even though libcosmic `About` supports them (`about.rs:16-21`); "Made by Gosh", the tagline, and the © line are dropped | M |
| Error dialog | `QMessageBox.warning(self, "Error", message)` (`window.py:684-685`) | `PendingDialog::Error` title `error`, body message, `OK` primary (`app.rs:539-547`) | **Implemented** | M |
| Error dialog OK closes | Qt OK | `CloseError` (`app.rs:544,843-849`) | **Implemented** | M |

### 1.10 Accessibility of specific controls

| Behavior | 2.0.4 (evidence) | 3.0.0 (evidence) | Status | Verify |
|---|---|---|---|---|
| Find close button accessible name | `setAccessibleName("Close Find")` (`window.py:68`); test `test_window.py:43` | icon button with **tooltip only**, no `.name(...)` (`app.rs:1050-1052`); ftl `close-find = Close Find` (ftl:41) is **defined but unused** | **Gap (A-1)** — no programmatic accessible name; screen reader announces unlabeled button | R |
| Scheme button accessible name | `setAccessibleName("Color scheme")` (`window.py:386`); test `test_theme.py:222-224` | `button::standard(label)` has visible text (`app.rs:435-439`); ftl `color-scheme-button = Color scheme` (ftl:57) **unused** | **Partial (A-2)** — visible text gives a name; the richer "Color scheme" name is unused | R |
| Find/Replace inputs labeled | Qt form labels "Find what:"/"Replace with:" (`window.py:116-117`) | placeholder text `Find` / `Replace with` (ftl:36-37; `app.rs:1059,1084`) | **Partial** — placeholders act as labels until typed | R |
| Go To / Font inputs labeled | Qt `QFormLayout`/label buddies (`window.py:116-117,184`) | `text_input("", …)` empty placeholder with a *separate* visible text label not programmatically associated (`app.rs:482-486,513-522`) | **Partial (A-3)** — label not bound to field for AT | R |

---

## 2. Menu structure & shortcut mapping (side by side)

### 2.1 Structure

```
2.0.4 (Qt menubar, window.py:320-361)         3.0.0 (libcosmic menu::bar, app.rs:366-410)
File                                           File
  New            Ctrl+N                          New            Ctrl+N
  Open…          Ctrl+O                          Open…          Ctrl+O
  Save           Ctrl+S                          Save           Ctrl+S
  Save As…       Ctrl+Shift+S                    Save As…       Ctrl+Shift+S
  Exit           Ctrl+Q                          Exit           Ctrl+Q
Edit                                           Edit
  Undo           Ctrl+Z                          Undo           Ctrl+Z
  Redo           Ctrl+Y                          Redo           Ctrl+Y
  ─────────────                                  ─────────────
  Cut            Ctrl+X                          Cut            Ctrl+X
  Copy           Ctrl+C                          Copy           Ctrl+C
  Paste          Ctrl+V                          Paste          Ctrl+V
  Delete         Del                             Delete         Del
  ─────────────                                  ─────────────
  Find…          Ctrl+F                          Find…          Ctrl+F
  Find Next      F3                              Find Next      F3
  Replace…       Ctrl+H                          Replace…       Ctrl+H
  Go To…         Ctrl+G   (disabled if wrap)     Go To…         Ctrl+G  (non-interactive if wrap)
  Select All     Ctrl+A                          Select All     Ctrl+A
  Time/Date      F5                              Time/Date      F5
Format                                         Format
  Word Wrap      (check)                         Word Wrap      (check)
  Font…                                          Font…
View                                           View
  Status Bar     (check, on)                     Status Bar     (check, on)
  Color Scheme ▶                                 Color Scheme ▶
    System (radio)                                 System (check)
    Light  (radio)                                 Light  (check)
    Dark   (radio)                                 Dark   (check)
Help                                           Help
  About NotePad                                  About NotePad
```

Labels are byte-identical once Qt `&`-mnemonics are stripped (2.0.4 uses `&New`,
`&Open…`, etc., `window.py:265-314`; 3.0.0 uses `i18n/en/notepad.ftl`). Ellipses
(`…`) preserved on Open/Save As/Find/Replace/Go To/Font. **3.0.0 drops the `&`
mnemonics entirely** (Deviation D-6, §7) — no Alt-letter menu activation.

### 2.2 Shortcut map

Identical set (see §1.3). Two 3.0.0-only additions: **Ctrl+Shift+Z** = Redo
(`app.rs:1404`, editor-only, not shown in menu) and the editor's built-in
Ctrl+A/C/X/V/Delete from `Binding::from_key_press`. The structural difference is
**scope**: 2.0.4 shortcuts are window-global; 3.0.0's are editor-focus-scoped
(§1.3, G-1).

### 2.3 The check-column alignment quirk (bugfix-pass.md item 17)

libcosmic's `menu::Item::CheckBox` reserves a leading **16 px** check gutter; a
plain command item or a folder does **not**, so mixing checkboxes with commands
in one dropdown misaligns the labels. 2.0.4 never had this problem — Qt draws a
uniform icon/check column automatically.

3.0.0 reproduces Qt's uniform column manually (`app.rs:232-285`):

- `MENU_CHECK_COL = 16.0` matches `Item::CheckBox`'s fixed spacer (`app.rs:232`).
- **Every command item** is emitted as `CheckBox(label, None, false, action)` so
  it reserves the gutter even though it is never checked
  (`app.rs:372-376,919-929,951-952`; comment `app.rs:364-365`).
- `menu_check_gutter()` builds a `Fixed(16.0)` spacer + `space_xxs` gap
  (`app.rs:241-249`).
- The **disabled Go To** row (`aligned_disabled_item`, `app.rs:251-263`) and the
  **Color Scheme folder** (`aligned_folder`, `app.rs:265-285`) replicate the same
  gutter + gap so their labels line up with real checkbox rows.
- Result asserted in packaging/README ("leading check column",
  `packaging.rs:47-48`; metainfo `data/com.goshapps.Notepad.metainfo.xml:50-52`).

Status: **Implemented**. Verify: **M** — open each of File/Edit/Format/View/Help;
all labels (commands, Word Wrap/Status Bar checks, disabled Go To, Color Scheme
folder, scheme checks) share one left edge. This is a purely visual property with
no unit test, so it is a standing manual/smoke item.

---

## 3. User flows (2.0.4 vs 3.0.0)

### 3.1 Open

- **2.0.4:** Edit→Open or Ctrl+O → `_guard_unsaved` (if dirty, Save-changes
  dialog; Save/Discard/Cancel) → `QFileDialog.getOpenFileName` (modal, Qt) →
  `load_path` reads **UTF-8 strict**; on `UnicodeDecodeError`/`OSError` shows
  "Could not open file" (`window.py:600-628`).
- **3.0.0:** Open → `guard_unsaved(Open)` (`app.rs:632`) → portal open dialog
  (`app.rs:1327-1346`) → `OpenSelected` → `guard_unsaved(OpenPath)` →
  `load_path` reads **UTF-8 lossy** (`app.rs:1269-1290`).
- **Delta:** portal vs Qt dialog (Deviation D-1); lossy vs strict decode
  (D-5 — **resolved: strict reject will be restored**, §6/T-6, DECISIONS.md
  D8). Otherwise equivalent, including the guard chain.

### 3.2 Save / Save As

- **2.0.4:** Save → write if path else Save As (`window.py:630-634`); Save As →
  `QFileDialog.getSaveFileName` default name `basename` or `Untitled.txt`
  (`window.py:636-647`).
- **3.0.0:** `save(false)` → `write_to` or `save_as_dialog` (`app.rs:1292-1296`);
  default name localized `untitled + ".txt"` (`app.rs:1348-1356`).
- **Delta:** portal dialog (D-1); localized default name (bugfix #14). Equivalent.

### 3.3 Unsaved-guard chain ("Save continues the original action")

- **2.0.4:** `_guard_unsaved(proceed)` shows dialog; **Save** → `on_save()` then
  `proceed()` **only if no longer modified** (so a cancelled Save As aborts the
  original action) (`window.py:662-682`). **Discard** → `proceed()`. **Cancel** →
  nothing.
- **3.0.0:** `guard_unsaved(after)` (`app.rs:1242-1249`). **Save** →
  `pending_after = after`, `save(false)` (`app.rs:830-835`); on successful
  `write_to`, `proceed(pending_after)` (`app.rs:1306-1316`); save error keeps
  `pending_after` and re-shows Save-changes on `CloseError` (`app.rs:843-849`);
  **Discard** → `proceed` (`app.rs:836-842`); **Cancel**/Esc → clear
  (`app.rs:826-829,869-873`).
- **Delta:** 3.0.0 carries the pending action across the **async** Save As task
  (bugfix #2/#3), which 2.0.4 did synchronously. Behaviorally equivalent and
  more robust. Verify flow: dirty Untitled → New → Save → Save As → choose path →
  document actually resets (M).

### 3.4 Close / Exit

- **2.0.4:** Exit action → `self.close` → `closeEvent` guard (`window.py:271,687-711`).
- **3.0.0:** Exit, header close, and `window::close_requests` all funnel to
  `Message::Exit` → `guard_unsaved(Close)` (`app.rs:606,664-669,886-899`);
  `exit_on_close(false)` (`main.rs:52`) so a clean close still exits via
  `close_window` (`app.rs:1381-1388`).
- **Delta:** none user-visible (bugfix #1 restored the close-button guard the
  README promises). Verify: type in Untitled → click window × → Save/Discard/Cancel;
  Cancel keeps window, Discard exits, Save opens Save As then exits (M).

### 3.5 Find bar (open / close / Esc / F3)

- **2.0.4:** Ctrl+F → prefill from single-line selection, **show + focus + select-all**
  the entry (`window.py:506-509,93-95`; test `test_window.py:31-35`). Esc or close
  button → hide + **return focus to editor** (`window.py:97-99`; test
  `test_window.py:46-62`). Enter → find next; F3 (global) → find next.
- **3.0.0:** Ctrl+F (editor focus) → `Message::Find` prefills + shows, **no focus**
  (`app.rs:718-722`). Esc/close → hide, **no explicit focus return**
  (`app.rs:731-734,879-882`). Enter in find input → FindNext (`app.rs:1061`).
- **Delta / gaps:** **G-2** (no auto-focus/select on open) and **G-3** (focus
  return not guaranteed); **G-1** (F3 does not fire while the find input is
  focused, unlike 2.0.4's global F3). These break the "open find and immediately
  type / press F3 repeatedly" muscle memory. Verify at runtime (R), fix in
  Phase 2 (§8).

### 3.6 Replace

- **2.0.4:** Ctrl+H → **modeless** `ReplaceDialog` (separate window) with Find
  what / Replace with / Match case / Find Next / Replace / Replace All / Cancel;
  default button Find Next; Enter-in-find → find, Enter-in-replace → replace one;
  stays open so you can edit the document between actions (`window.py:102-171,546-557`).
- **3.0.0:** Ctrl+H → find bar **expands inline** with a Replace-with input +
  Replace / Replace All buttons; Enter-in-find → FindNext, Enter-in-replace →
  ReplaceOne (`app.rs:724-730,1079-1103`).
- **Delta:** Deviation D-2 — inline bar instead of a modeless dialog (iced has no
  cheap modeless secondary window; plan `libcosmic-rewrite.md:37`). The inline bar
  is inherently non-modal (editor stays live), so the "edit between replaces"
  capability is preserved. **Match case** is shared state (`app.rs:737`) like
  2.0.4 (`window.py:514-520`). Cancel maps to close/Esc.

### 3.7 Go To

- **2.0.4:** Ctrl+G (disabled if wrap on) → modal `GoToDialog` seeded with the
  current line, entry select-all (`window.py:579-588,207-210`); invalid →
  "Please enter a valid line number." warning; out-of-range → "The line number is
  beyond…" and dialog stays usable (`window.py:198-205,585-587`).
- **3.0.0:** Ctrl+G (gated on `!word_wrap`) → dialog seeded with current line
  (`app.rs:738-753`); invalid → inline `invalid-line-number`; out-of-range →
  inline `line-beyond-end` kept in-dialog (bugfix #15, `app.rs:1207-1240`).
- **Delta:** 3.0.0 shows errors **inline** in the dialog body rather than a
  separate warning popup — a reasonable COSMIC rendering (behavior-preserving).
  **Partial:** entry value pre-filled but **not select-all** on open
  (`app.rs:482-486`); 2.0.4 selected it (`window.py:207-210`, `showEvent`).
  **Gap (RV-7, `review-phase1.md`):** 2.0.4 also **refocuses the editor after a
  successful jump** (`window.py:588` `self.edit.setFocus()`); v3's
  `confirm_goto` closes the dialog and moves the cursor with **no focus task**
  (`app.rs:1207-1240`, returns `Task::none()`), and whether COSMIC returns
  focus to the editor on dialog unmount is **unproven** — if it doesn't, a
  keyboard user who presses Ctrl+G, types a line number, and hits Enter lands
  the cursor but cannot type (the same regression class G-2/G-3 cover for the
  find bar). Scoped into PLAN T22 (same `Id`+focus-task mechanism as T-4;
  cross-boundary — `confirm_goto` is Architecture region); runtime-verify in
  Phase 3 (M/R).

### 3.8 Font

- **2.0.4:** Format→Font → native `QFontDialog.getFont` (all system families,
  bold/italic/strikeout, sizes, **live preview**) (`window.py:446-450`).
- **3.0.0:** Format→Font → custom dialog: family dropdown (fixed 14,
  `app.rs:35-50`) + free-text family field + size dropdown (14 sizes,
  `app.rs:52`); `font_from_family` forces Normal weight/style (`app.rs:1427-1440`).
- **Delta / gap:** **G-4** — no style (bold/italic), no live preview, no system
  font enumeration, family list capped at 14. Free-text field allows typing an
  unlisted family name (partial mitigation). Verify against a real font need (M).

### 3.9 Second-instance forwarding

- **2.0.4:** 2nd process → `forward_to_running_instance` over the Unix socket; if
  a live server exists, send paths, await ack, exit 0; server opens first path via
  guarded `open_path` and presents window (`application.py:66-173`,
  `main.py:23-24`). No-arg 2nd launch → present/focus only.
- **3.0.0:** `single_instance::forward` → exit; subscription accepts, reads to
  EOF, always acks, yields paths (empty vec for no-arg) → `OpenExternal` opens
  first path guarded, plus `window::gain_focus` (`single_instance.rs:95-118`,
  `app.rs:641-652`, `main.rs:39-41`).
- **Delta:** **Partial** on focus/unminimize equivalence for the no-arg case
  (2.0.4 did show+raise+activate; 3.0.0 does `gain_focus`). Verify a minimized
  window is actually raised at runtime (R).

---

## 4. i18n inventory

2.0.4 had **no localization layer** — all strings were hardcoded English literals
in `window.py`/`theme.py`. 3.0.0 introduces Fluent i18n (`src/i18n.rs`,
`i18n/en/notepad.ftl`, `i18n.toml` fallback `en`). **Only `en` is provided**
(`i18n/en/` is the sole locale dir), so 3.0.0 is effectively English-only too —
**no localization regression** (there was nothing to regress), but **no net
localization gain** either beyond the infrastructure. Flag for reviewer: the app
ships a single locale despite having the machinery for more.

Every 3.0.0 string and its 2.0.4 origin:

| ftl key (line) | 3.0.0 value | 2.0.4 source string (evidence) | Match? |
|---|---|---|---|
| `app-title` (1) | NotePad | "NotePad" (`window.py:415,455`; `application.py:57`) | ✓ |
| `app-comment` (2) | A native COSMIC clone of Microsoft Notepad | "A native Qt 6 clone of Microsoft Notepad." (`window.py:457`; desktop `Comment`) | **Changed** Qt 6→COSMIC (Deviation); **unused in `src/`** (RV-8) → consumed by T-7 About fix (PLAN T17) |
| `app-keywords` (3) | notepad,text,editor,plaintext | desktop `Keywords` (`data/…desktop:11`) | ✓ correspondence only — **unused in `src/`** (dead code, RV-8); **deleted in T17** by lead ruling (metainfo `<keywords>` is static XML) |
| `about` (4) | About NotePad | "&About NotePad" (`window.py:314`) | ✓ (mnemonic stripped) |
| `repository` (5) | Repository | *new* (About drawer link, `app.rs:315`) | new |
| `untitled` (6) | Untitled | "Untitled" (`window.py:413,638`) | ✓ |
| `file/edit/format/view/help` (7-11) | File/Edit/Format/View/Help | "&File" etc. (`window.py:323,330,346,350,360`) | ✓ |
| `new/open/save/save-as/exit` (12-16) | New/Open…/Save/Save As…/Exit | `window.py:265-271` | ✓ |
| `undo/redo/cut/copy/paste/delete` (17-22) | Undo/Redo/Cut/Copy/Paste/Delete | `window.py:273-278` | ✓ |
| `find/find-next/replace/go-to/select-all/time-date` (23-28) | Find…/Find Next/Replace…/Go To…/Select All/Time/Date | `window.py:279-288` | ✓ |
| `word-wrap/font/status-bar/color-scheme/system/light/dark` (29-35) | Word Wrap/Font…/Status Bar/Color Scheme/System/Light/Dark | `window.py:290-307,347-358` | ✓ |
| `find-placeholder` (36) | Find | entry placeholder "Find" (`window.py:71`) | ✓ |
| `replace-placeholder` (37) | Replace with | form label "Replace with:" (`window.py:117`) | ✓ (label→placeholder) |
| `match-case` (38) | Match case | "Match case" (`window.py:73,120`) | ✓ |
| `replace-one` (39) | Replace | "Replace" button (`window.py:127`) | ✓ |
| `replace-all` (40) | Replace All | "Replace All" (`window.py:128`) | ✓ |
| `close-find` (41) | Close Find | `setAccessibleName("Close Find")` (`window.py:68`) | **Present but UNUSED** → A-1 regression; consumed by T-2 (PLAN T15) |
| `close-find-tooltip` (42) | Close Find (Esc) | tooltip "Close Find (Esc)" (`window.py:69`) | ✓ |
| `go-to-line` (43) | Go To Line | dialog title "Go To Line" (`window.py:179`) | ✓ |
| `line-number` (44) | Line number | label "Line number:" (`window.py:184`) | ✓ (colon dropped) |
| `go-to-button` (45) | Go To | button "Go To" (`window.py:189`) | ✓ |
| `cancel` (46) | Cancel | "Cancel" (`window.py:129,190,673`) | ✓ |
| `discard` (47) | Discard | "Discard" (`window.py:672,697`) | ✓ |
| `save-changes` (48) | Save changes? | title/text "Save changes?" (`window.py:667,669`) | ✓ |
| `save-changes-body` (49) | Your changes will be lost if you don't save them. | informative text (`window.py:670,695`) | ✓ |
| `error` (50) | Error | warning title "Error" (`window.py:685`) | ✓ |
| `font-title` (51) | Font | `QFontDialog` title "Font" (`window.py:447`) | ✓ |
| `font-family` (52) | Font family | *new* (Qt dialog supplied its own) | new |
| `font-size` (53) | Size | *new* | new |
| `ok` (54) | OK | Qt dialog default OK | ✓ (equivalent) |
| `switch-to-light` (55) | Switch to light mode | tooltip (`window.py:493`) | ✓ |
| `toggle-dark` (56) | Toggle dark mode | tooltip (`window.py:503`) | ✓ |
| `color-scheme-button` (57) | Color scheme | `setAccessibleName("Color scheme")` (`window.py:386`) | **Present but UNUSED** → A-2; consumed by T-9 (PLAN T16) |
| `word-wrap-on/off` (58-59) | Word Wrap: On/Off | `window.py:394,439` | ✓ |
| `ln-col` (60) | Ln { $line }, Col { $col } | `window.py:421` | ✓ |
| `cannot-find` (61) | Cannot find "{ $text }" | `window.py:543,567,577` | ✓ |
| `invalid-line-number` (62) | Please enter a valid line number. | `window.py:203` | ✓ |
| `line-beyond-end` (63) | The line number is beyond the total number of lines. | `window.py:586` | ✓ |
| `could-not-open` (64) | Could not open file: | `window.py:623` | ✓ |
| `could-not-save` (65) | Could not save file: | `window.py:655` | ✓ |
| `text-files` (66) | Text files | filter "Text files (*.txt)" (`window.py:607,644`) | ✓ (glob shown separately) |
| `all-files` (67) | All files | filter "All files (*)" (`window.py:607,644`) | ✓ |
| `open-title` (68) | Open | dialog title "Open" (`window.py:605`) | ✓ |
| `save-as-title` (69) | Save As | dialog title "Save As" (`window.py:642`) | ✓ |

**i18n findings for the reviewer:**

1. **Missing strings vs 2.0.4 About body.** The About tagline ("A native … clone
   of Microsoft Notepad"), the "Made by Gosh." author line, and the
   "© 2026 Gosh — GPL-3.0-or-later" copyright line (`window.py:456-460`) have no
   ftl keys and are not surfaced in the drawer (G-6). The identity test still
   requires "© 2026 Gosh" to appear in `src/app.rs`/metainfo/COPYRIGHT
   (`packaging.rs:74-86`), and it does — but it is **not shown to the user in
   About** as it was in 2.0.4.
2. **Four defined-but-unused strings** (count corrected per review RV-8, whose
   mechanical grep of all 69 keys against `src/` I re-ran: zero references for
   all four): `app-comment` (ftl:2), `app-keywords` (ftl:3), `close-find`
   (ftl:41), `color-scheme-button` (ftl:57). The original count of two covered
   only the accessible-name pair (`close-find`, `color-scheme-button` — exactly
   the two accessible names 2.0.4 set explicitly; their non-use is the A-1/A-2
   accessibility regression, §5). The reviewer is right that this table's
   mapping of `app-comment` / `app-keywords` to *static desktop-file text* is a
   correspondence, not a use — both ftl entries are dead code today.
   Dispositions (lead ruling, PLAN.md rev 2 → §6): `close-find` → consumed by
   T-2 (PLAN T15); `color-scheme-button` → consumed by T-9 (PLAN T16);
   `app-comment` → consumed by T-7 (PLAN T17, About attribution);
   **`app-keywords` → deleted as dead code in T17** (metainfo `<keywords>` is
   static XML; the ftl duplicate has no consumer — deliberate duplication
   removed). Post-T15/T16/T17 target: **zero unused ftl keys** (T17
   done-criterion).
3. **Changed string:** `app-comment` "Qt 6"→"COSMIC" (intended, matches new
   desktop `Comment` and metainfo `summary`).
4. **Dropped 2.0.4-only strings** that no longer apply: the Replace **dialog**
   title "Replace" and its "Find what:" label (now an inline bar), and the
   separate Go To warning title "NotePad" (`window.py:203`) — all subsumed by the
   inline/dialog redesign.
5. **Single locale** (`en`) — infrastructure present, no translations shipped
   (same effective coverage as 2.0.4).

---

## 5. Accessibility notes

**2.0.4 (Qt):** Full Qt accessibility stack — AT-SPI bridge, native menu/dialog
semantics, `QFontDialog`/`QFileDialog` are accessible system dialogs, and the app
set explicit accessible names on the two icon-only controls: the find-bar close
button (`setAccessibleName("Close Find")`, `window.py:68`, tested
`test_window.py:37-44`) and the scheme button (`setAccessibleName("Color scheme")`,
`window.py:386`, tested `test_theme.py:220-224`). Tooltips present on both.

**3.0.0 (libcosmic + accesskit):** The `a11y` feature **is enabled** (libcosmic
default features are on — the app's `[dependencies.libcosmic]` does not set
`default-features = false`, and `a11y` is in libcosmic's `default` list,
`Cargo.toml:11-22`). So accesskit is compiled in and buttons expose `.name()` /
`.description()` (`button/icon.rs:42-45,175`). Text editor, menus, footer text,
and dialogs are exposed via accesskit.

**Regressions / gaps:**

- **A-1 (Gap): Find-bar close button has no accessible name.** It is an icon-only
  `button::icon` with a tooltip but no `.name(...)` (`app.rs:1050-1052`). The
  matching string `close-find = Close Find` exists (ftl:41) but is unused. 2.0.4
  explicitly named it and **tested** it (`test_window.py:43`). A screen reader will
  announce an unlabeled button. **Fix is one line**: `.name(fl!("close-find"))`.
- **A-2 (Partial): Scheme button** relies on its visible "Light"/"Dark" text for a
  name (`app.rs:435-439`); the richer `color-scheme-button = Color scheme`
  (ftl:57) is unused. Acceptable (visible label = name) but loses 2.0.4's stable
  "Color scheme" identity when the label flips between Light/Dark.
- **A-3 (Partial): Go To and Font inputs** use `text_input("", …)` (empty
  placeholder) with a *separate* `widget::text` label above
  (`app.rs:482-486,513-522`). The label is not programmatically associated with
  the field (no buddy/`labelled-by` equivalent), so AT may announce an unlabeled
  edit box. 2.0.4's `QFormLayout` associated labels with fields. Find/Replace
  inputs are better (placeholder text acts as the name, ftl:36-37).
- **A-4 (Gap): Menu enabled-state is not conveyed.** 2.0.4 greyed unavailable
  Cut/Copy/Delete/Undo/Redo (`window.py:406-410,316-317`); AT users got the
  disabled state. 3.0.0 always shows them active (G-5), so a screen-reader/sighted
  user loses the "this does nothing right now" affordance.
- **A-5 (Deviation): No Alt-mnemonics.** 2.0.4 menus had `&`-mnemonics
  (Alt+F, Alt+E, …) for keyboard menu access (`window.py:265-361`). 3.0.0 dropped
  them (D-6). libcosmic menu navigation model differs; verify what keyboard menu
  access remains (R).
- **A-6 (runtime): Global shortcuts scoped to editor** (G-1) also affects
  keyboard-only users who tab into the find bar and then can't use F3/Ctrl+S.

**Positive:** accesskit is on; find/replace inputs have placeholder-names; the
scheme toggle and all menu items have text labels; dialogs have titles and
labeled primary/secondary/tertiary buttons (`app.rs:460-547`).

Net: **accessibility regressed on the two explicitly-named icon controls (A-1 is
the clear, tested regression), on form-field labeling (A-3), and on menu
enabled-state (A-4).** A-1 is a trivial fix and should be prioritized.

---

## 6. Decision log (lead rulings on flagged items)

The lead reviewed this document (**ACCEPTED**; it becomes the parity-checklist
source for `PLAN.md`) and independently re-verified its load-bearing claims
against the libcosmic `d4d71fd` checkout: the `Application` trait has no
app-level key handler (G-1 confirmed), `menu_tree::find_key` is display-only,
and `widget::about::About` exposes author/comments/copyright setters (T-7
viable). The reviewer's Phase-1 pass (`review-phase1.md`, 2026-09-11) graded
this document **ACCEPT WITH OBJECTIONS** — ~30 re-checked v2.0.4 citations all
accurate, G-/A-/D- inventories matching the code; the lead accepted every
finding (PLAN.md rev 2), and the four ux-owned doc fixes (RV-8, RV-7,
RV-12/13/14, decision-log sync) are folded into this rev 3 (rows below; §4
finding 2; §1.4/§3.7; §7 D-9/D-10/D-11). Rulings that lock or change items
elsewhere in this document:

| Item | Ruling | Consequence / split |
|---|---|---|
| **T-6 / D-5** — lossy UTF-8 open | **DECIDED: strict reject** (option a) — the exact 2.0.4 contract and the only zero-data-loss option. `String::from_utf8` on load; on `Err` show `PendingDialog::Error` with `could-not-open` copy + decode detail naming the file (mirrors "Could not open file:\n{err}", `window.py:622-624`); document/title/`saved_text` untouched. **Required unit test:** invalid bytes (e.g. `[0x66,0x6f,0x6f,0xff,0xfe]`) → error path + state unchanged. Recorded as **DECISIONS.md D8**. | D-5 is retired as an accepted deviation and becomes a Phase 2 fix. Owner: **architect** (load logic = state region per DECISIONS.md D5); **ux** reviews dialog copy/flow. |
| **T-1** — global shortcuts | **Design direction approved**, two constraints: (i) `iced::event::listen_with` filtered to `(Event::Keyboard(_), Status::Ignored)` — fires only for keys the focused widget did **not** consume; this kills double-fire by construction (the editor binding closure consumes its own keys and stays as-is; `text_input` does not consume Ctrl+S/F3, so the find bar gets them). (ii) Suppress while a modal dialog is open (`self.pending.is_some()`) — 2.0.4's modal Qt dialogs (GoTo, save-guard, error box) blocked window shortcuts; the modeless ReplaceDialog maps to our inline bar, which is not `pending`. | Split per DECISIONS.md D5 cross-boundary rule: **architect** implements the subscription + routing; **ux** verifies the 17-binding table parity and focus interactions — T-3/T-4 sequencing must not fight the subscription. |
| **T-8** — font dialog | **Scope set.** (1) Enumerate real system families — architect spikes the cheapest enumeration through libcosmic's cosmic-text stack (no new crate if avoidable; vendoring cost matters, cf. DECISIONS.md D9); (2) keep the free-text family field; (3) keep the size list; (4) add weight/style (bold/italic) **only if** the spike shows `Font{weight,style}` plumbing + two new config fields are straightforward (iced `Font` supports both; cosmic-config v1 tolerates added keys with defaults); (5) **no live preview — accepted deviation, to be documented** (§7). | Split: **architect** = enumeration spike + config fields; **ux** = dialog UI. Final scope locks after reviewer input. |
| **T-2** — close-find accessible name | **Approved as proposed** — do exactly `.name(fl!("close-find"))`. | ux |
| **T-5** — Edit-menu enabled state | **Approved as proposed** — reuse `aligned_disabled_item`; the per-frame menu rebuild makes selection/stack state available. | ux (view region), coordinating the enable-state predicate with **architect** (`has_selection`/undo-depth live in the state region). |
| **T-7, T-9, T-10** | **Approved as proposed.** | ux |
| **DECISIONS.md D12** — desktop `Categories` | `Categories=COSMIC;Utility;TextEditor;` → `Utility;TextEditor;X-COSMIC;` (bare `COSMIC` is unregistered and fails `desktop-file-validate`; `X-` prefix is the spec's extension mechanism). **UX sign-off: GRANTED** (per-question evidence sent to lead, 2026-09-11). Evidence: (1) *Grouping/launch* — independent grep of this host's installed desktop files: every COSMIC-ecosystem app uses the X- convention (`cosmic-ext-whether`: `Utility;X-Cosmic;`; `clippy-land`: `Utility;X-Cosmic;X-Iced;`; `YapCap`: `System;Monitor;X-COSMIC;`) and **zero installed apps use bare `COSMIC;`**; launching never reads `Categories` (that is `Exec`/`Icon`/`TryExec`), so only grouping is at stake and `X-COSMIC` is the convention COSMIC's launcher reads. (2) *2.0.4 intent* — `Categories=Qt;Utility;TextEditor;` (`~/.cache/notepad-v2.0.4/data/com.goshapps.Notepad.desktop:9`): both substantive registered categories (Utility, TextEditor) are kept verbatim and the toolkit marker is swapped Qt→X-COSMIC — same pattern; marker position differs (2.0.4 led with it, proposal trails) but `Categories` is an unordered set per spec and marker-last matches every shipped app observed. All other desktop-entry keys unchanged. (3) *Metainfo consistency* — no `<categories>` element exists in `data/com.goshapps.Notepad.metainfo.xml` (AppStream desktop-application components take categories from the desktop file, linked via `<launchable>`, metainfo:29); the `<provides><id>com.system76.CosmicApplication</id>` identity (metainfo:36) is untouched by this change; `tests/packaging.rs` pins no Categories (no test churn); the ride-along `<binaries>`→`<binary>` unwrap is confirmed needed (wrapper present, metainfo:37-39). | packager (`data/` packaging metadata per D5); the metainfo `<provides><binary>` unwrap rides along. |
| **RV-8** — unused ftl keys (reviewer; lead ruling, PLAN.md rev 2) | Mechanical grep of all 69 ftl keys against `src/` (re-run by ux: zero references) shows **four** defined-but-unused keys, not the two §4 originally claimed: `app-comment` (ftl:2), `app-keywords` (ftl:3), `close-find` (ftl:41), `color-scheme-button` (ftl:57). Dispositions: `close-find` → consumed by T-2 (PLAN T15); `color-scheme-button` → T-9 (PLAN T16); `app-comment` → consumed by T-7 (PLAN T17); **`app-keywords` → deleted as dead code in T17** (metainfo `<keywords>` is static XML; the ftl duplicate has no consumer — deliberate duplication removed). Post-T15/T16/T17 target: **zero unused ftl keys** (T17 done-criterion). | §4 corrected (finding 2 + per-row disposition annotations). All four consumers/deletion are ux-owned (`i18n/` + view regions, D5). |
| **RV-7** — Go To editor refocus (reviewer) | Parity gap inside this document's own cited range: v2 returns keyboard focus to the editor after a successful Go To (`window.py:588` `self.edit.setFocus()`); v3's `confirm_goto` closes the dialog and moves the cursor with **no focus task** (`app.rs:1207-1240`, `Task::none()`), and COSMIC's dialog-unmount refocus behavior is unproven. **Accepted; scoped into PLAN T22** (same `Id`+focus-task mechanism as T-4/T19). | §1.4 row + §3.7 delta added; §8 T-10 scope updated. Cross-boundary per RV-9/D5 (`confirm_goto` = Architecture region — architect edits/co-signs); runtime-verify in Phase 3 (M/R). |
| **RV-12/13/14** — accepted micro-deviations (reviewer) | Three v2 affordances missing from the original inventory are **accepted as deviations** (PLAN.md rev 2): **UX-D9** — v3 `to_lowercase()` vs v2 `casefold()` full Unicode folding (`"ß"`→`"ss"`; `commands.py:35` vs `commands.rs:81`); observable only for exotic Unicode; no std casefold in Rust and a new crate conflicts with DECISIONS.md D9 vendoring discipline → code comment rides architect's PLAN T10. **UX-D10** — v2's find-entry QLineEdit clear button (`window.py:72` `setClearButtonEnabled(True)`) has no iced/cosmic `text_input` equivalent → workaround select-all+delete; T18's select-all-on-open covers the common case. **UX-D11** — v2's `NOTEPAD_ICON` env icon override (`application.py:27-48` `_find_icon`) dropped; v3 embeds the SVG (`app.rs:311-316`) → dev affordance, not user-facing. | §7 rows D-9/D-10/D-11 + Appendix B; §1.4 case-insensitive row annotated. No behavior change. |

**ID conventions.** This document's deviation IDs (D-1…D-11) and gap IDs (G-#,
A-#) are local to it; `PLAN.md` prefixes them **UX-D#/UX-G#**, and
DECISIONS.md D8 notes the distinction explicitly. Task IDs T-1…T-10 were
adopted as PLAN.md's seed list; the **PLAN.md rev 2 mapping is final**:
T-1→T21, T-2→T15, T-3→T18, T-4→T19, T-5→T20, T-6→T03, T-7→T17, T-8→T23,
T-9→T16, T-10→T22, with T18/T19/T22 explicitly cross-boundary (RV-9:
architect edits/co-signs the `update()`/hook lines, ux owns semantics +
verification). The reviewer's Go-To-refocus gap is cited project-wide as
**RV-7** inside T22 rather than minting a new G-# (PLAN.md §3 fixes the gap
range at G-1…G-6).

**Verification-context correction (DECISIONS.md D3 addendum, 2026-09-11).** No
2.0.4 Flatpak is installed anywhere visible — live A/B runtime comparison is
**not available**. The parity mechanism is (a) the 2.0.4 test suite's
behavioral contracts ported into Rust unit/integration tests and (b) Phase 3
checklist verification of the 3.0.0 Flatpak **against this document**. Every
"M/S/R" verification method in this file therefore means "check 3.0.0 against
the cited 2.0.4 contract", never "compare two running apps". (Building 2.0.4
from the source cache remains a fallback only for a parity dispute the ported
contracts cannot settle.)

**Process.** Phase 1 remains doc-only — no source edits until PLAN.md lands
(pending architect + packager docs, then reviewer). Reviewer challenges to any
claim get answered with evidence per the disagreement protocol.

---

## 7. Deviations list (COSMIC conventions deliberately replacing Qt behavior)

Each is a conscious replacement, with justification and the governing plan line.

| # | Deviation | 2.0.4 → 3.0.0 | Justification | Evidence |
|---|---|---|---|---|
| **D-1** | File dialogs use XDG **portals** instead of Qt `QFileDialog` | modal Qt → async `file_chooser` portal | Sandbox-correct file access under Flatpak; COSMIC apps use portals. Priority: Flatpak-sandbox correctness > COSMIC convention. | plan `libcosmic-rewrite.md:21`; `app.rs:1327-1379` |
| **D-2** | Replace is an **inline expanding find bar**, not a modeless dialog | `ReplaceDialog` window (`window.py:102-171`) → second row in find bar (`app.rs:1079-1103`) | iced has no cheap modeless secondary window; inline bar keeps the editor live (non-modal), preserving "edit between replaces". | plan `libcosmic-rewrite.md:37` |
| **D-3** | About is a **context drawer**, not a modal `QMessageBox` | `window.py:452-461` → `app.rs:443-455` | COSMIC convention for About. (Content gap tracked separately as G-6.) | plan `libcosmic-rewrite.md:44` |
| **D-4** | Theming via **cosmic-theme** tokens, not Kirigami `QPalette`/Fusion | `theme.py` palettes → `config.rs:44-58` `theme_for` | Product decision: native COSMIC look. The Kirigami contrast unit tests are explicitly out of scope. | plan `libcosmic-rewrite.md:9,136-137` |
| **D-5** | Open decodes UTF-8 **lossily** (`from_utf8_lossy`) instead of strict | `window.py:620-624` rejects invalid UTF-8 → `app.rs:1273-1275` opens with U+FFFD | Intent: legacy Latin-1/CP1252 files "still open instead of failing" (`app.rs:1270-1272`). **Risk:** re-saving replaces unknown bytes with U+FFFD → silent corruption; 2.0.4 refused such files. **RESOLVED (DECISIONS.md D8): retired — strict reject will be restored in Phase 2 (§6, T-6).** | `app.rs:1269-1290` |
| **D-6** | Menu **mnemonics dropped**; header bar replaces Qt menubar+toolbar | `&File` etc. (`window.py:323-361`) → plain labels in `header_start` (`app.rs:366-410`) | COSMIC header-bar model. A11y impact A-5. | `app.rs:361-416` |
| **D-7** | **Delete** with no selection deletes the next char (classic Notepad) | 2.0.4 disabled Delete without selection (`window.py:410,424-425`) → always deletes (`app.rs:713-716`) | bugfix-pass item #10 chose classic-Notepad behavior over literal 2.0.4 behavior. | `bugfix-pass.md:46` |
| **D-8** | **Font/size persisted**; bounded **undo (100)**; extra **Ctrl+Shift+Z** redo; explicit **min window 360×180** | font not persisted, unbounded undo, no Shift+Z, no min size | Config persistence is a COSMIC norm (`config.rs`); undo bound guards memory (`app.rs:1442-1447`); Shift+Z is a common redo idiom; min size lets the find bar wrap (`main.rs:49`). | `config.rs`, `app.rs`, `main.rs` |
| **D-9** (UX-D9) | Case-insensitive **selection matching** uses Rust `to_lowercase()`, not Python `casefold()` | v2 `selection_matches` casefolds — full Unicode folding, `"ß"`→`"ss"` (`commands.py:35`) → v3 per-char simple mapping, `"ß"` unchanged (`commands.rs:81`) | Observable only for exotic Unicode (e.g. Replace treating a selected "ß" as matching needle "ss"). Rust std has no `casefold`; adding a crate conflicts with DECISIONS.md D9's vendoring-cost discipline (simplicity ranks above an exotic-Unicode exactness edge). **Accepted** (review RV-12, PLAN rev 2); code comment rides architect's PLAN T10. No behavior change. | review-phase1.md RV-12; `commands.rs:81`; `commands.py:35` |
| **D-10** (UX-D10) | No clear (✕) button inside the find entry | v2 enables the QLineEdit clear button on the find entry (`window.py:72` `setClearButtonEnabled(True)`) → iced/cosmic `text_input` has no built-in equivalent | No toolkit affordance to map; workaround is select-all + delete, and T-3/PLAN T18's select-all-on-open covers the common case. **Accepted** (review RV-13, PLAN rev 2). | review-phase1.md RV-13; `window.py:72` |
| **D-11** (UX-D11) | `NOTEPAD_ICON` env icon override dropped | v2 `_find_icon` honors a `NOTEPAD_ICON` environment override for the window icon (`application.py:27-48`) → v3 embeds the SVG (`app.rs:311-316`) | Dev/packaging affordance, not user-facing; embedding matches how COSMIC apps ship icons. **Accepted** (review RV-14, PLAN rev 2). | review-phase1.md RV-14; `application.py:27-48` |

**Priority note (RESOLVED):** D-5 (lossy decode + re-save corruption) was the
one deviation trading *parity/data-safety* for convenience. Under the stated
priority (parity > sandbox correctness > a11y > simplicity > COSMIC convention)
the lead decided **strict reject** — the exact 2.0.4 contract and the only
zero-data-loss option (§6; DECISIONS.md D8). D-5 becomes a Phase 2 fix, not an
accepted deviation.

---

## 8. Gaps → proposed Phase 2 tasks

Concrete, small, each keeps the app buildable. Ordered by user impact and
reviewer-likelihood. IDs are referenced from §1/§5/§7. Ownership follows the
DECISIONS.md D5 region map; per-task splits are recorded in §6 (T-1, T-6, T-8,
T-5 predicate) or noted inline. **PLAN.md rev 2 IDs are final** — see §6 "ID
conventions" for the T-#→T## mapping (ux's first Phase-2 task is T15, after
Stage D coverage lands).

- **T-1 (G-1, A-6) — Restore global shortcuts (design approved, §6).**
  Shortcuts currently fire only with editor focus (`editor_key_binding`,
  `app.rs:1391-1411`). Approved mechanism: `iced::event::listen_with` filtered
  to `(Event::Keyboard(_), Status::Ignored)` — keys the focused widget did NOT
  consume — mapped through the `key_binds` set to `MenuAction::message()`, so
  Ctrl+S/Ctrl+F/F3/Ctrl+H/etc. work from the find bar as in 2.0.4. No
  double-fire by construction (the editor closure consumes its own keys and
  stays as-is); suppressed while a modal dialog is open (`pending.is_some()`),
  matching 2.0.4's modal-blocks-shortcuts behavior. Split: architect
  implements subscription + routing; ux verifies the 17-binding table parity
  and focus interactions (T-3/T-4 sequencing must not fight it). *Verify:* R
  then M (focus find input, press F3 / Ctrl+S; open Go To dialog, confirm
  suppression).

- **T-2 (A-1) — Name the find-bar close button (approved — exactly this
  one-liner).** Add `.name(fl!("close-find"))` to `app.rs:1050-1052`; the
  string already exists (ftl:41). *Verify:* accesskit inspection / screen
  reader (R). Lowest-effort, highest-confidence a11y fix.

- **T-3 (G-2) — Auto-focus + select-all the find input on open.** On
  `Message::Find`/`Message::Replace`, emit a focus task for the find input
  (`widget::text_input::focus(id)`, `text_input/input.rs:1283`; give the input a
  stable `Id`, `input.rs:308`) and select its contents, matching
  `window.py:93-95,506-509` / `test_window.py:31-35`. *Verify:* M/R.

- **T-4 (G-3) — Return focus to the editor when the find bar closes.** On
  `CloseFind`/Esc (`app.rs:731-734,879-882`), focus the text editor, matching
  `window.py:97-99` / `test_window.py:46-62`. *Verify:* M/R.

- **T-5 (G-5, A-4) — Reflect enabled state in the Edit menu (approved).**
  Grey/disable Cut/Copy/Delete when there is no selection and Undo/Redo when
  the stacks are empty, mirroring `window.py:316-317,406-410`. Reuse the
  existing `aligned_disabled_item` pattern (`app.rs:251-263`) already applied
  to Go To; the per-frame menu rebuild makes selection/stack state available.
  Coordinate the enable-state predicate with architect (`has_selection` /
  undo-depth live in their region). *Verify:* M (no selection → Cut/Copy/Delete
  greyed; empty doc → Undo/Redo greyed). Keeps menu alignment work intact.

- **T-6 (D-5, data-safety) — Invalid UTF-8: DECIDED → strict reject (§6;
  DECISIONS.md D8).** Restore the 2.0.4 contract: `String::from_utf8` on load;
  on `Err` show `PendingDialog::Error` with `could-not-open` copy + decode
  detail naming the file (mirrors "Could not open file:\n{err}",
  `window.py:622-624`); document/title/`saved_text` untouched (current lossy
  path: `app.rs:1269-1290`). Owner: architect (load logic); ux reviews dialog
  copy/flow. *Verify:* **required unit test** (invalid bytes → error path +
  state unchanged) + M.

- **T-7 (G-6) — Restore About attribution.** Populate the `About` drawer's
  `author`/`comments`/`copyright` fields (supported: `about.rs:16-21`) with
  "Made by Gosh", the tagline, and "© 2026 Gosh — GPL-3.0-or-later"
  (`app.rs:311-316`), matching `window.py:452-461`. Add ftl keys as needed.
  *Verify:* M (open About drawer).

- **T-8 (G-4) — Improve the Font dialog (scope set, §6).** (1) Enumerate real
  system families instead of the fixed 14 (`app.rs:35-50`) — architect spikes
  the cheapest route through libcosmic's cosmic-text stack (no new crate if
  avoidable); (2) keep the free-text family field; (3) keep the size list;
  (4) add bold/italic weight/style **only if** the spike shows
  `Font{weight,style}` plumbing (`app.rs:1427-1440` forces Normal today) + two
  config fields is straightforward; (5) **no live preview — accepted deviation,
  to be documented** (add to §7 when locked). Split: architect = enumeration
  spike + config fields; ux = dialog UI. Final scope locks after reviewer
  input. *Verify:* M.

- **T-9 (A-2, A-3) — Label form fields and the scheme button.** Set
  `.name(fl!("color-scheme-button"))` on the header scheme button
  (`app.rs:435-439`, ftl:57 unused) and associate the Go To / Font input labels
  with their fields (or move them into placeholders) so AT announces them
  (`app.rs:482-486,513-522`). *Verify:* R.

- **T-10 (§1.4 Go To, §3.7 refocus, §3.9 focus; PLAN T22) — Small parity
  polish.** (a) Select-all the Go To entry on open (`app.rs:482-486`).
  (b) **Return focus to the editor on `GoToConfirm` success** — v2
  `window.py:588` `setFocus()`; gap found by review RV-7; same `Id`+focus-task
  mechanism as T-4; cross-boundary (`confirm_goto` is Architecture region —
  architect edits/co-signs). (c) Confirm the no-arg second instance raises a
  minimized window (may need more than `gain_focus`, `app.rs:642-648`).
  *Verify:* M/R (GoTo refocus runtime-verified in Phase 3).

**Not gaps (confirmed parity, no task):** window title format, Ln/Col format +
UTF-8 correctness, F5 time/date format, find/replace/go-to core semantics and
counts, unsaved-guard chains incl. Save-continues-action, single-instance
protocol, color-scheme model + persistence, check-column alignment. These are
**Implemented** with unit tests where 2.0.4 had them.

---

## Appendix A — Evidence index (primary files)

- **2.0.4:** `~/.cache/notepad-v2.0.4/src/{window,application,commands,theme,main}.py`;
  tests `tests/{test_window,test_commands,test_application,test_theme}.py`;
  `data/com.goshapps.Notepad.{desktop,metainfo.xml}`; `README.md`.
- **3.0.0:** `src/{app,commands,config,key_bind,single_instance,i18n,main}.rs`;
  `i18n/en/notepad.ftl`; `data/com.goshapps.Notepad.{desktop,metainfo.xml}`;
  `tests/packaging.rs`; `com.goshapps.Notepad.json`; `README.md`;
  `plans/{libcosmic-rewrite,bugfix-pass}.md`.
- **libcosmic (rev d4d71fd):** `src/widget/menu/{menu_tree,menu_bar,key_bind}.rs`,
  `src/widget/text_editor.rs`, `src/widget/text_input/input.rs`,
  `src/widget/button/icon.rs`, `src/widget/about.rs`, `src/app/mod.rs`,
  `Cargo.toml` (features).

## Appendix B — Gap/deviation ID index

| ID | Kind | Summary | Task |
|---|---|---|---|
| G-1 | Gap | Shortcuts editor-focus-scoped, not window-global | T-1 |
| G-2 | Gap | Find input not auto-focused/selected on open | T-3 |
| G-3 | Partial | Focus not returned to editor on find close | T-4 |
| G-4 | Gap | Font dialog: no styles/preview, fixed 14 families | T-8 |
| G-5 | Gap | Edit menu never greys Cut/Copy/Delete/Undo/Redo | T-5 |
| G-6 | Gap | About drops author/tagline/copyright | T-7 |
| RV-7 | Gap | Go To success does not refocus the editor (v2 `window.py:588`) | T-10 (PLAN T22) |
| A-1 | Gap (a11y) | Find close button has no accessible name (`close-find` unused) | T-2 |
| A-2 | Partial (a11y) | Scheme button uses visible text; `color-scheme-button` unused | T-9 |
| A-3 | Partial (a11y) | Go To / Font inputs not programmatically labeled | T-9 |
| A-4 | Gap (a11y) | Menu enabled-state not conveyed to AT | T-5 |
| A-5 | Deviation | Alt-mnemonics dropped | (accepted, D-6) |
| D-1…D-8 | Deviation | Portals, inline replace, About drawer, cosmic theming, lossy decode, mnemonics/header, Delete-next-char, persistence/undo/min-size/Shift+Z | D-5→T-6 (decided: strict reject, DECISIONS.md D8) |
| D-9 (UX-D9) | Deviation | `to_lowercase()` vs v2 `casefold()` — exotic Unicode only | (accepted, RV-12; comment rides PLAN T10) |
| D-10 (UX-D10) | Deviation | Find-entry clear button not replicated (no iced equivalent) | (accepted, RV-13; T-3/PLAN T18 mitigates) |
| D-11 (UX-D11) | Deviation | `NOTEPAD_ICON` env icon override dropped (v3 embeds SVG) | (accepted, RV-14) |
