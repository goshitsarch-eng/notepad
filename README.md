# NotePad

A native clone of Microsoft Notepad (Windows XP era) built with **GTK4** and
**libadwaita**, with light/dark mode support and shipped as a **Flatpak**.

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
- **Adwaita light and dark** themes (toggle in the header bar or the View menu)
- Unsaved-changes protection when creating/opening files or closing the window

## Tech stack

- Python 3 + [PyGObject](https://pygobject.gnome.org/)
- GTK 4 and libadwaita 1
- [Meson](https://mesonbuild.com/) build system
- Flatpak (`org.gnome.Platform`) for distribution

## Development

### System dependencies (Ubuntu/Debian)

```bash
sudo apt-get install -y \
  gir1.2-gtk-4.0 gir1.2-adw-1 libadwaita-1-0 \
  python3-gi python3-gi-cairo \
  meson ninja-build gettext desktop-file-utils
```

### Run from source

The app runs directly from the checkout without an install step:

```bash
python3 src/main.py
```

### Build and install with Meson

```bash
meson setup _build --prefix=/usr
ninja -C _build
meson test -C _build          # validates the desktop entry
sudo ninja -C _build install  # installs the `notepad` launcher
```

### Build the Flatpak

Requires `flatpak` and `flatpak-builder` plus the GNOME 50 runtime/SDK:

```bash
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub org.gnome.Platform//50 org.gnome.Sdk//50
flatpak-builder --user --install --force-clean build-flatpak com.goshapps.Notepad.json
flatpak run com.goshapps.Notepad
```

## Project layout

```
├── com.goshapps.Notepad.json     # Flatpak manifest
├── meson.build                   # top-level build definition
├── src/                          # application source (Python/PyGObject)
│   ├── main.py                   # entry point
│   ├── application.py            # Adw.Application + app actions
│   ├── window.py                 # editor window, menus, and commands
│   └── notepad.in                # installed launcher template
└── data/                         # desktop entry, AppStream metainfo, icon
```
