# Rewrite NotePad on libcosmic

## Context

NotePad 2.0.4 is a Python/PySide6 (Qt 6) clone of classic Windows Notepad: one document window, File/Edit/Format/View/Help, find/replace/go-to, word wrap, Ln/Col status, F5 time/date, unsaved-change guards, System/Light/Dark schemes, Meson + KDE/PySide Flatpak.

This rewrite replaces the entire stack with **Rust + [libcosmic](https://github.com/pop-os/libcosmic)** (iced-based COSMIC toolkit), following [cosmic-app-template](https://github.com/pop-os/cosmic-app-template). Identity stays the same: app id `com.goshapps.Notepad`, binary `notepad`, GPL-3.0-or-later, Gosh attribution.

**Product decision:** look and theming become native COSMIC (libcosmic widgets, cosmic-theme, header bar + menu bar). Feature set and shortcuts stay Notepad-like. Kirigami/Qt palettes and Fusion style switching go away; Light/Dark/System map onto libcosmic `Theme` / `ThemeMode`.

**Not in scope:** becoming COSMIC Text Editor (`cosmic-edit`). Keep a single plain-text document, not tabs/syntax/projects.

## Approach

Scaffold a COSMIC application (`cosmic::Application`) with:

- `widget::text_editor` (`text_editor::Content`) as the document
- `header_start()` menu bar (`widget::menu`) with Notepad menus + `KeyBind`s
- `header_end()` scheme toggle (Light/Dark), matching today’s toolbar button
- Inline find/replace bar above the editor (Escape / close button); COSMIC `dialog()` for Go To, Font, About-errors, and Save/Discard/Cancel
- XDG portal file choosers (`libcosmic` `xdg-portal`)
- `cosmic-config` for wrap, status bar, font, color scheme
- Fluent i18n (`i18n-embed`) with English strings matching current labels
- Tokio executor; file IO and dialogs as `Task`s
- Cargo + `just` (drop Meson/Python)
- Flatpak on `org.freedesktop.Platform` 25.08 + `com.system76.Cosmic.BaseApp`

Editor helpers (find next with wrap, replace one/all, go-to line, dirty detection) live in a GUI-free `commands` module so `cargo test` can port the existing `tests/test_commands.py` cases.

### Feature mapping

| Current (Qt) | libcosmic |
|---|---|
| `QPlainTextEdit` | `cosmic::widget::text_editor` |
| Menubar File/Edit/Format/View/Help | `menu::bar` in `header_start` |
| Find bar + Esc/close | Row of `search_input` / `text_input` + checkbox + buttons; hide on Esc |
| Modeless Replace dialog | Expand find bar with Replace / Replace All (iced has no cheap modeless extra window) |
| Go To dialog | `Application::dialog()` |
| `QFontDialog` | Dialog: family dropdown + size (fontconfig or cosmic-text list; fallback monospace/sans/serif) |
| Kirigami palettes + QSettings | Follow COSMIC theme; optional pin Light/Dark via `core.set_theme` + cosmic-config |
| Status bar Ln/Col + wrap | `Application::footer()` |
| Unsaved guard | `dialog()` + `on_close_requested` |
| Unix-socket single instance | Keep: tokio Unix listener in a subscription; second process forwards paths and exits |
| About `QMessageBox` | `widget::about::About` in context drawer (COSMIC convention) |
| Meson / KDE Flatpak | `just` install + Cosmic BaseApp Flatpak |

### Shortcuts (unchanged)

Ctrl+N/O/S, Ctrl+Shift+S, Ctrl+Q, Ctrl+Z/Y, Ctrl+X/C/V, Delete, Ctrl+F, F3, Ctrl+H, Ctrl+G, Ctrl+A, F5.

### Config (`cosmic-config`, id `com.goshapps.Notepad`)

- `color_scheme`: `system` \| `light` \| `dark` (default system)
- `word_wrap`: bool (default false; disables Go To when on, as classic Notepad)
- `show_status_bar`: bool (default true)
- `font_family`: string (default monospace)
- `font_size`: u16

### Known toolkit limits (accept, don’t fake Qt)

- `text_editor` has no `QTextDocument` edit blocks; replace-all may be one `Content::with_text` rather than a single Qt undo step.
- Cut/copy/paste from the menu use `Content` selection + `iced::clipboard` tasks, not Qt actions.
- Visuals are COSMIC, not XP/Breeze Fusion.

### Version

Bump to **3.0.0** (toolkit rewrite). Add a metainfo release; keep prior 2.x/1.x entries.

## Files to modify

**Remove**

- `src/*.py`, `src/notepad.in`, `src/meson.build`
- `meson.build`, `data/meson.build`
- `tests/test_*.py`

**Replace / add**

- `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `justfile`, `i18n.toml`
- `src/main.rs` — flags, single-instance forward, `cosmic::app::run`
- `src/app.rs` — `Application`, menus, view, update, dialogs, footer
- `src/config.rs` — `CosmicConfigEntry`
- `src/commands.rs` — find / replace / go-to / document text (unit-tested)
- `src/key_bind.rs` — menu `KeyBind` map
- `src/i18n.rs` — Fluent loader (template pattern)
- `i18n/en/notepad.ftl`
- `data/com.goshapps.Notepad.desktop` — `Categories=COSMIC;Utility;TextEditor;`
- `data/com.goshapps.Notepad.metainfo.xml` — libcosmic summary, 3.0.0, `<provides><id>com.system76.CosmicApplication</id></provides>`
- `com.goshapps.Notepad.json` — Freedesktop 25.08 + Cosmic BaseApp + rust-stable
- `README.md` — stack, `just run` / Flatpak, layout
- `.gitignore` — `target/`, `vendor/`, `_build/`, `.flatpak-builder/`

**Keep**

- `LICENSE`, `COPYRIGHT`, `data/icons/.../com.goshapps.Notepad.svg`
- App id, binary name `notepad`, homepage/bugtracker URLs

## Reuse

- Existing SVG icon and desktop/metainfo identity
- Find/replace/go-to *behavior* from `src/commands.py` / `tests/test_commands.py` (wrap search, case fold, replace-all count, out-of-range go-to)
- Unsaved-change copy (“Save changes?” / Discard / Cancel) and F5 stamp format `%-I:%M %p %-m/%-d/%Y` (Rust `chrono` with same padding)
- Menu structure and shortcuts from `src/window.py`
- Single-instance socket path `$XDG_RUNTIME_DIR/com.goshapps.Notepad.sock`
- Packaging checks: GPL text present, “Vaughan”/“WordPad” absent, version consistent, Gosh copyright

libcosmic APIs: `Application`, `menu::bar`, `text_editor`, `dialog::file_chooser`, `widget::dialog`, `widget::about`, `footer`, `on_close_requested`, cosmic-config, template `justfile` install paths.

## Implementation checklist

- [ ] Add Cargo/just/i18n/toolchain scaffold modeled on cosmic-app-template (`APP_ID = "com.goshapps.Notepad"`, crate/bin `notepad`, libcosmic git + `tokio`, `winit`, `wgpu`, `xdg-portal`, `dbus-config`)
- [ ] Implement `commands` (document text, find-next wrap, match-case, replace one/all, go-to) with `cargo test` ports of `test_commands.py`
- [ ] Implement `App` model: `Content`, path, dirty/saved text, wrap, font, scheme, find/replace UI state, pending dialog enum
- [ ] Wire File/Edit/Format/View/Help menus, keybinds, and `header_end` scheme button
- [ ] Editor view: optional find/replace bar, `text_editor` with wrap/font, `footer` Ln/Col + wrap label
- [ ] File tasks: portal open/save, UTF-8 load/save errors, New/Open/close unsaved guard, CLI path via `Flags`
- [ ] Unix-socket single-instance (forward paths, ack, stale-socket unlink) + guarded `open_path`
- [ ] Dialogs: Go To validation, Font, errors, Save changes; About context drawer
- [ ] Persist config; apply System/Light/Dark through libcosmic theme
- [ ] Fluent strings; desktop/metainfo/README/Flatpak 3.0.0; `just install` copies bin, desktop, metainfo, icon, LICENSE, COPYRIGHT
- [ ] Packaging tests (Rust tests or `just test-packaging`) for license, identity, version, Cosmic BaseApp manifest

## Verification

- `cargo test` — command helpers (find wrap, case, replace counts, go-to range)
- `cargo clippy` / `just check` — no warnings on new code
- `just run` — empty Untitled window; type; Ln/Col; wrap; F5; undo/redo; find/replace/go-to; font
- Manual: New/Open/Save/Save As, unsaved close, Light/Dark/System, About, Esc closes find
- Second process with a file argument focuses the first window and offers the unsaved guard
- `desktop-file-validate` + AppStream on metainfo
- `flatpak-builder` with Cosmic BaseApp; `flatpak run com.goshapps.Notepad`

## Out of scope

- Syntax highlighting, tabs, multiple documents
- Reimplementing Kirigami contrast unit tests against `QPalette`
- Qt offscreen widget tests for the find-bar close button (covered by structure + manual check)
