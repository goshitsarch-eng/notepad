# NotePad

A clone of classic Microsoft Notepad (Windows XP era) for the COSMIC desktop,
written in Rust with [libcosmic](https://github.com/pop-os/libcosmic). One
window, one plain-text file, and the File/Edit/Format/View/Help menus you
remember.

Current release: **3.0.0** — a ground-up rewrite on libcosmic (1.0.0 was GTK4,
2.x was Qt 6). Every dropdown shares a leading check column so Format and
View labels line up with File, Edit, and Help.

NotePad is an independent implementation and is not affiliated with or
endorsed by Microsoft. Microsoft and Windows are trademarks of the Microsoft
group of companies.

## AI-assisted development

I use AI tools to speed up development, but I work architecture-first. I
define the architecture, review and refactor the implementation, and repeat
as the project evolves.

I treat AI as a junior developer: useful for implementation and exploration,
but not the final authority. I remain responsible for the architecture,
technical decisions, and code quality.

I'm including this notice so you can make an informed choice about whether
AI-assisted software is something you're comfortable using.

## Features

- Classic File / Edit / Format / View / Help menu bar
- Open, edit, and save UTF-8 plain-text files (New, Open, Save, Save As)
- Undo / Redo (caret and selection restored), Cut / Copy / Paste / Delete /
  Select All — on the Edit menu and the editor's right-click menu. Delete
  removes the selection or the next character
- Find bar (Ctrl+F) with a Match case checkbox and Find Next (F3, wraps
  around). Replace (Ctrl+H) adds Replace and Replace All
- Go To line (Ctrl+G) — greyed out while Word Wrap is on, like Windows
  Notepad
- Time/Date stamp (F5), Windows-style
- Word Wrap toggle and an optional status bar showing `Ln X, Col Y` and the
  wrap state
- Font picker (Format ▸ Font…): font family + size
- Color scheme: System (follows COSMIC), Light, or Dark — from View ▸ Color
  Scheme; the header button toggles Light/Dark
- Unsaved-changes prompt on New, Open, Exit, and the window close button;
  choosing Save continues what you were doing after Save As
- Single instance: a second `notepad file.txt` opens the file in the running
  window; `notepad` alone just focuses it
- Word wrap, status bar, font, and color scheme persist across restarts —
  including in the Flatpak
- Line endings are preserved: CRLF and mixed-ending files save
  byte-identically
- Find, Go To, and the Ln/Col readout handle UTF-8 text correctly

## Install

### Flatpak remote

NotePad is published on the Gosh Apps remote. As of the 3.0.0 release the
remote still serves the previous Qt-based 2.0.4 build — for the current
version, build it yourself (below).

```bash
flatpak remote-add --user --if-not-exists gosh https://flatpak.goshapps.com/gosh.flatpakrepo
flatpak install --user gosh com.goshapps.Notepad
```

### Build the Flatpak yourself

Requires `flatpak`, `flatpak-builder`, `cargo`, and the Freedesktop 25.08
runtime/SDK plus the COSMIC BaseApp:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08 \
    org.freedesktop.Sdk.Extension.rust-stable//25.08 org.freedesktop.Sdk.Extension.llvm21//25.08 \
    com.system76.Cosmic.BaseApp//stable

# Materialize the vendored cargo sources the offline build needs
./scripts/vendor.sh

flatpak-builder --user --install-deps-from=flathub --install --force-clean \
    build-flatpak com.goshapps.Notepad.json
flatpak run com.goshapps.Notepad
```

The build is fully offline — `scripts/vendor.sh` runs `cargo vendor` once and
caches the result in `vendor.tar` (keyed on `Cargo.lock`; re-run it after
dependency changes).

### Native install

```bash
just build-release
sudo just install   # installs to /usr: binary, desktop file, metainfo, icon, licenses
```

`sudo just uninstall` removes the same files.

## Usage

Launch NotePad from your app menu, run `notepad file.txt`, or use "Open With"
on a `.txt` file. Command-line paths must be absolute or relative to the
current directory; anything starting with `-` is ignored, and only the first
file opens — there are no flags (`--help` included).

Menus work like Windows Notepad, and there's a right-click menu in the editor
with Cut / Copy / Paste / Select All. The full shortcut list:

| Shortcut | Action |
|---|---|
| Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S | New / Open / Save / Save As |
| Ctrl+Q | Exit |
| Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z | Undo / Redo / Redo |
| Ctrl+X / Ctrl+C / Ctrl+V | Cut / Copy / Paste |
| Shift+Delete, Ctrl+Insert, Shift+Insert | Cut, Copy, Paste (alternates) |
| Delete | Delete selection or next character |
| Ctrl+F / F3 / Ctrl+H / Ctrl+G | Find / Find Next / Replace / Go To |
| Ctrl+A | Select All |
| F5 | Insert time/date |
| Esc | Close the open dialog, About drawer, or Find bar |

The menu commands (Ctrl+S, Ctrl+F, F3, F5, and friends) work no matter where
the focus is — they fire even while you're typing in the Find field — except
while a dialog is open. Field-level keys (Ctrl+A/X/C/V, Delete, arrows) act
on the focused widget, so they edit the Find field's text when you're in it.
Enter in the Find field runs Find Next; Enter in the Replace field runs
Replace.

One quirk: the Find bar doesn't grab the keyboard when it opens — click or
Tab into the field to type a search. And while a text field is focused, Esc
just unfocuses the field; a second Esc closes the bar.

Settings live in `~/.config/cosmic/com.goshapps.Notepad/v1/` (one file per
key, shared with the COSMIC desktop — the Flatpak writes to the same place).
Changes made there apply live.

## Limitations

- One document per window, plain text only. No tabs, printing, recent-files
  list, or syntax highlighting — by design
- UTF-8 files only. A file in another encoding (Latin-1, CP1252, …) gets an
  error dialog rather than opening with mangled characters
- Undo history is capped at 100 steps
- The UI is English-only (the Fluent i18n plumbing is in place if translations
  are contributed)
- Go To is unavailable while Word Wrap is on (deliberate Notepad parity)

## Development

Rust + [libcosmic](https://github.com/pop-os/libcosmic) (pinned by commit),
[just](https://github.com/casey/just) for recipes, Flatpak on
`org.freedesktop.Platform` 25.08 + `com.system76.Cosmic.BaseApp` for
distribution.

```bash
just run        # cargo run --release --locked
just test       # cargo test --locked
just check      # cargo clippy (pedantic warnings)
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites and the full
workflow, [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the code is
organized, and [docs/RELEASING.md](docs/RELEASING.md) for the tag-driven
release process (GitHub Actions builds x86_64 and aarch64 tarballs and
Flatpaks automatically).

## Project layout

```
├── com.goshapps.Notepad.json     # Flatpak manifest (Cosmic BaseApp)
├── Cargo.toml / Cargo.lock       # crate definition; libcosmic pinned by rev
├── justfile                      # build, test, install, vendor recipes
├── .github/workflows/            # CI (lint/test) and tag-driven release
├── scripts/                      # vendor.sh, package-*.sh, verify-release.sh, check-version.sh
├── src/
│   ├── main.rs                   # entry point, CLI args, single-instance handoff
│   ├── app.rs                    # window, menus, dialogs, editor, message handling
│   ├── commands.rs               # find / replace / go-to / caret helpers (unit-tested)
│   ├── config.rs                 # cosmic-config settings
│   ├── key_bind.rs               # menu shortcuts
│   ├── single_instance.rs        # Unix-socket instance forwarding
│   └── i18n.rs                   # Fluent loader
├── i18n/                         # Fluent translations (en only today)
└── data/                         # desktop entry, AppStream metainfo, icon
```

## License

GPL-3.0-or-later — see [LICENSE](LICENSE) and [COPYRIGHT](COPYRIGHT).
