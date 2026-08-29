# NotePad

A native clone of Microsoft Notepad (Windows XP era) built with **Qt 6**,
with light/dark mode support following the
[Kirigami color guidelines](https://develop.kde.org/docs/getting-started/kirigami/style-colors/),
and shipped as a **Flatpak**.

NotePad is an independent implementation and is not affiliated with or endorsed
by Microsoft. Microsoft and Windows are trademarks of the Microsoft group of companies.

See the project plan in Linear:
[Build Native Notepad Clone in GTK4 and Adwaita in Flatpak](https://linear.app/vaughan-jones/project/build-native-notepad-clone-in-gtk4-and-adiwata-in-flatpak-36ecfc173826).

## Features

- Classic **File / Edit / Format / View / Help** menu bar
- Open, edit, and save plain-text files (`New`, `Open`, `Save`, `Save As`)
- Editing commands: `Undo`, `Redo`, `Cut`, `Copy`, `Paste`, `Delete`, `Select All`
- `Find` with `Find Next` (F3), plus `Replace` (Ctrl+H) and `Go To` (Ctrl+G)
- **Font** selection from the Format menu
- Insert the current **Time/Date** (F5), Windows-style
- **Word Wrap** toggle and a live **Ln/Col** status bar
- **Color scheme** choice: System (follows the platform), Light, and Dark
  (View menu or the scheme button in the toolbar)
- Unsaved-changes protection when creating/opening files or closing the window

## Theming

Light and dark mode support follows the Kirigami color guidelines:

- the app **follows the system color scheme by default** (e.g. the Plasma
  light/dark preference) and can be pinned to Light or Dark instead
- widgets use **semantic palette roles** (Window, Base, Text, Highlight, ...)
  rather than hardcoded colors, so contrast stays correct when the scheme
  switches
- the custom light and dark palettes are defined in one place
  ([`src/theme.py`](src/theme.py)), modeled on the KDE Breeze light/dark
  color schemes

## Tech stack

- Python 3 + [PySide6](https://pypi.org/project/PySide6/) (Qt 6)
- [Meson](https://mesonbuild.com/) build system
- Flatpak (`org.kde.Platform`) for distribution

## Development

### System dependencies

```bash
# Ubuntu/Debian
sudo apt-get install -y python3-pyside6.qtwidgets meson ninja-build desktop-file-utils

# Fedora
sudo dnf install -y meson ninja-build desktop-file-utils && pip3 install --user PySide6
```

Any PySide6 6.x install works (`pip3 install PySide6`).

### Run from source

The app runs directly from the checkout without an install step:

```bash
python3 src/main.py
```

### Build and install with Meson

```bash
meson setup _build --prefix=/usr
ninja -C _build
meson test -C _build          # unit tests + desktop entry validation
sudo ninja -C _build install  # installs the `notepad` launcher
```

### Build the Flatpak

Requires `flatpak` and `flatpak-builder` plus the KDE 6 runtime/SDK:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.kde.Platform//6.9 org.kde.Sdk//6.9
flatpak-builder --user --install --force-clean build-flatpak com.goshapps.Notepad.json
flatpak run com.goshapps.Notepad
```

## Project layout

```
├── com.goshapps.Notepad.json     # Flatpak manifest (org.kde.Platform)
├── meson.build                   # top-level build definition
├── src/                          # application source (Python/PySide6)
│   ├── main.py                   # entry point
│   ├── application.py            # QApplication + single-instance handling
│   ├── window.py                 # editor window, menus, and commands
│   ├── commands.py               # find/replace/go-to editor helpers
│   ├── theme.py                  # Kirigami-style light/dark color schemes
│   └── notepad.in                # installed launcher template
└── data/                         # desktop entry, AppStream metainfo, icon
```
