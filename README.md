# NotePad

A native clone of Microsoft Notepad (Windows XP era) built with
**[libcosmic](https://github.com/pop-os/libcosmic)** for the COSMIC™ desktop,
with system/light/dark color schemes, and shipped as a **Flatpak**.

Current release: **3.0.0**. This release rewrites the application on libcosmic
and the COSMIC design language while keeping the classic Notepad menus,
shortcuts, and document workflow. Every dropdown shares a leading check
column, so Format and View labels line up with File, Edit, and Help.

NotePad is an independent implementation and is not affiliated with or endorsed
by Microsoft. Microsoft and Windows are trademarks of the Microsoft group of companies.

## Features

- Classic **File / Edit / Format / View / Help** menu bar. Toggles, commands,
  and submenus share a leading check column so labels line up
- Open, edit, and save plain-text files (`New`, `Open`, `Save`, `Save As`)
- Editing commands: `Undo`, `Redo`, `Cut`, `Copy`, `Paste`, `Delete`, `Select All`
  (Delete removes the selection or the next character)
- Closable `Find` bar (close button or Escape) with `Find Next` (F3), plus
  `Replace` (Ctrl+H) and `Go To` (Ctrl+G). Find, Go To, and Ln/Col stay on
  the intended character in UTF-8 text
- **Font** selection from the Format menu
- Insert the current **Time/Date** (F5), Windows-style
- **Word Wrap** toggle and a live **Ln/Col** status bar
- **Color scheme** choice: System (follows COSMIC), Light, and Dark
  (View menu or the scheme button in the header)
- Unsaved-changes protection on New, Open, Exit, and the window close button.
  Save from that dialog continues the original action after Save As
- Single-instance Unix socket: a second `notepad path.txt` forwards the file
  to the running window; a second `notepad` with no args focuses that window
- Word wrap, font, status bar, and color scheme persist across restarts,
  including inside the Flatpak

## Theming

Light and dark mode support uses the COSMIC theme:

- the app **follows the system color scheme by default** and can be pinned to Light or Dark instead
- widgets use libcosmic semantic theme tokens rather than hardcoded colors
- System, Light, and Dark map onto `cosmic-theme` palettes via cosmic-config

## Tech stack

- Rust + [libcosmic](https://github.com/pop-os/libcosmic) (iced)
- [just](https://github.com/casey/just) for build and install recipes
- Flatpak (`org.freedesktop.Platform` 25.08 plus `com.system76.Cosmic.BaseApp`) for distribution

## Development

### System dependencies

On Pop!_OS / Ubuntu:

```bash
sudo apt install cargo cmake just libexpat1-dev libfontconfig-dev libfreetype-dev libxkbcommon-dev pkgconf
```

A current stable Rust toolchain (1.93+) is required.

### Run from source

```bash
just run
# or
cargo run
```

### Build and install

```bash
just build-release
cargo test --locked
just install          # installs the `notepad` launcher, desktop file, metainfo, icon, LICENSE, COPYRIGHT
```

### Build the Flatpak

Requires `flatpak` and `flatpak-builder` plus the Freedesktop 25.08 runtime/SDK and Cosmic BaseApp:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.freedesktop.Platform//25.08 org.freedesktop.Sdk//25.08 \
    org.freedesktop.Sdk.Extension.rust-stable//25.08 com.system76.Cosmic.BaseApp//stable
flatpak-builder --user --install-deps-from=flathub --install --force-clean build-flatpak com.goshapps.Notepad.json
flatpak run com.goshapps.Notepad
```

## Project layout

```
├── com.goshapps.Notepad.json     # Flatpak manifest (Cosmic BaseApp)
├── Cargo.toml                    # crate definition
├── justfile                      # build, test, and install recipes
├── src/                          # application source (Rust / libcosmic)
│   ├── main.rs                   # entry point and CLI paths
│   ├── app.rs                    # window, menus, dialogs, editor
│   ├── commands.rs               # find/replace/go-to helpers
│   ├── config.rs                 # cosmic-config settings
│   ├── key_bind.rs               # menu shortcuts
│   ├── single_instance.rs        # Unix-socket instance forwarding
│   └── i18n.rs                   # Fluent loader
├── i18n/                         # Fluent translations
└── data/                         # desktop entry, AppStream metainfo, icon
```
