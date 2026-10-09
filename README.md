# XP Notepad (Flutter)

An unofficial recreation of Windows XP Notepad (Luna, blue), written entirely in Flutter.
Every control is drawn in Flutter: there is no WebView, no HTML or CSS, and no code of our
own in the native runners. The window, menus, dialogs and status bar are Dart widgets.

**Status.** Version 0.1.2+3. The first audit covered 0.1.0+1 on 2026-10-07 and found 28 defects
(F-01 to F-28); 8 of them were fixed in 0.1.1. A second pass on 2026-10-09 fixed 15 of the other 20,
found 12 more (F-29 to F-40) and fixed 11 of those. That makes 34 of 40 fixed. The work was verified
on Linux (x86-64, Flutter 3.47.6) through the test suite and a release build driven by keyboard and
mouse under a virtual display. The Windows build and runtime have not been verified, and no screen
reader has been tried. The six findings that are not fully fixed are listed under Known issues, and the
handbook has the evidence for all 40.

## Screenshots

Light mode:

![XP Notepad in light mode, showing a sample document](docs/screenshots/light-mode.png)

Dark mode:

![XP Notepad in dark mode, showing the same document](docs/screenshots/dark-mode.png)

Both were captured on Linux from the release build, with a sample text file and a separate
settings folder.

## Downloads

The [v0.1.1 pre-release](https://github.com/goshitsarch-eng/notepad/releases/tag/v0.1.1) contains
a Flatpak bundle for arm64 (64-bit ARM) Linux, and `SHA256SUMS.txt`. Install the bundle with
`flatpak install --user xp-notepad-0.1.1-arm64.flatpak`. Flatpak refuses a second copy of the app, so
remove a system-wide copy first. Close the app before you install or uninstall it. The earlier v0.1.0 pre-release has the same app with an older icon.

Version 0.1.2 is not published yet: no `v0.1.2` tag has been pushed, so build it from source. The
published pre-releases are 0.1.1 and 0.1.0, and they do not have the fixes described here. The x64
Flatpak, the Linux tarballs and the Windows installers are not published for any version, so build those
from source. The release workflow is set up to build them when a version tag is pushed. The files are not
code-signed, so Windows may show a SmartScreen warning.

## Continuous integration

`.github/workflows/ci.yml` runs `flutter analyze` and `flutter test` on every push to `main` and on
every pull request. `.github/workflows/release.yml` builds the downloads above when a version tag is
pushed. It can also be run by hand, which builds the same files without creating a release. No
workflow run has completed yet.

## Handbook

Open **`docs/handbook/index.html`** in a browser. It works straight from disk: no server, no
internet connection, no CDN and no analytics. It holds the user manual, getting started
notes, architecture, development and build notes, troubleshooting, the audit findings with
file and line evidence, and the coverage record with the verification log.

## Run

Desktop only. Install Flutter's desktop prerequisites for your OS (on Linux, the packages in
Flutter's Linux setup guide, including the GTK 3 development headers), then:

```sh
flutter pub get
flutter run -d linux
```

A file can be passed on the command line: `flutter run -d linux -- notes.txt`.
`flutter run -d windows` is not verified.

## Build

```sh
flutter build linux --release
```

The app is in `build/linux/<arch>/release/bundle/`. Keep the whole bundle directory
together. A clean build (no `build/` or `.dart_tool/`) was verified in a copy of the project.

## Test

```sh
flutter analyze
flutter test
```

On Linux, `flutter analyze` reports no issues and `flutter test` runs 255 tests (the progress line it prints counts a few setup steps too, so it reads
higher). Run as root, 3 of them
skip themselves, because they test file permissions and root ignores permissions; run as an ordinary
user, all 255 run and pass. The 137 tests of 0.1.1 are unchanged. The 118 added in 0.1.2 are in
`test/ui/audit_*_test.dart`, `test/ui/semantics_test.dart`, `test/data/*_test.dart` (the new ones),
`test/domain/print_text_test.dart` and `test/config/app_info_test.dart`. Each one names the finding it
guards. The last one fails when the version in `pubspec.yaml`, the About box, the Flatpak metadata, the
Windows installer script and this file do not agree, so change them together.

The golden tests use 16 images in `test/ui/goldens/`. The 13 in `test/ui/notepad_golden_test.dart`
are skipped when the Liberation fonts are missing. The 3 dark-mode images in
`test/ui/dark_mode_and_help_test.dart` are not skipped. Two images changed in 0.1.2 on purpose: the
About box now shows the version, and the Go To number is selected when the box opens. Regenerate goldens with
`flutter test --update-goldens` only after an intended visual change, and review the images.

## What it does

- **Window.** Caption with minimize, maximize and close buttons; drag the caption to move;
  resize from any edge or corner. The content cannot be smaller than 400 × 310, which is the height
  the Edit menu needs. The title follows the document: `notes.txt - Notepad`, or `Untitled - Notepad`.
- **Menus.** File, Edit, Format, View and Help, in XP's order, with shortcuts, Alt
  mnemonics and keyboard navigation.
- **Editing.** Undo, cut, copy, paste, delete, select all, Find, Find Next, Replace,
  Replace All, Go To, and Time/Date (`3:31 PM 10/7/2026`). Tab inserts a tab character.
- **Files.** Open and Save As in an XP-style dialog. ANSI (Windows-1252), Unicode (UTF-16 LE),
  Unicode big endian and UTF-8, with byte order marks where XP writes them and CRLF line endings
  on disk. Saving text that ANSI cannot hold asks first. Files over 64 MB are refused, and files over
  2 million characters ask first, because editing them is very slow (see Known issues). When a file
  cannot be opened or saved, the message gives the reason the system reported.
- **Printing.** Page Setup (header, footer, margins in inches), then Print, which lays the
  text out as a PDF and opens the platform print dialog. Headers and footers accept `&f` (file
  name), `&p` (page), `&d` (date), `&t` (time), `&l`, `&c` and `&r` (alignment) and `&&`.
- **Remembered between runs.** Word wrap, status bar, dark mode, font, page setup, the normal
  window size and the last folder.

The handbook describes each feature with its keyboard shortcut, the verification status and
the limits.

## Settings

Settings are JSON. On Linux they are in `$XDG_CONFIG_HOME/xp_notepad/settings.json`, or
`~/.config/xp_notepad/settings.json` when `XDG_CONFIG_HOME` is unset, empty or not an absolute path,
as the XDG specification says. On Windows they are in `%APPDATA%\xp_notepad\settings.json` (not
verified). With no usable folder at all, settings are not kept and nothing is written to the working
folder. A damaged value falls back to its default. The file is replaced through a temporary file, so a
crash cannot leave half of it. To reset the settings, close the app and delete the file.

## Known issues

The full list, with evidence, reproduction steps and recommendations, is in the handbook's
[audit findings](docs/handbook/index.html#findings). 34 of the 40 findings are fixed. Six are not fully
fixed, and Windows has not been checked:

- **Editing a very large file is slow (F-31, Medium).** Flutter sends the whole text to the
  platform's text input on every edit. In a release build under software rendering (a virtual machine,
  so absolute times will differ), one typed character took about 0.06 s of processor time in a 100 KB file,
  0.7 s in 1 MB and about 4 s, with 2 GB of memory, in 5 MB. Moving the caret is cheaper: about 0.09 s per
  key at 1 MB. The app asks before it opens a file over 2 million characters and refuses files over 64 MB.
  Reading, scrolling and Find work in large files, and a 40 MB file opened in about 5 s. The cost is in
  Flutter's text input, so it is reduced to a warning here and not removed.
- **UTF-16 files without a byte order mark are read as ANSI (F-14, Low).** Notepad XP guesses
  these; this app does not. Open such a file and the text shows a box for every other byte. Save As with
  an encoding choice does write a byte order mark.
- **The Font dialog's Script list has one entry, Western, and does nothing (F-16, Low).** It was left
  in place to match the look of XP's dialog; removing it or implementing it is a choice for the maintainer.
- **The caption buttons cannot be focused (F-19, Low).** The keyboard routes are File > Exit,
  Alt+F4 and the window manager's own shortcuts. XP's caption buttons are not tab stops either.
- **The interface has semantics, but no screen reader has been tried (F-15, Medium).** Menus, buttons,
  fields, check boxes, radio buttons, lists, dialogs and the status bar have names, roles and states, and
  the window behind a dialog is hidden. This was checked through Flutter's semantics tree only.
- **Some leftover code (F-26, Info).** `MessageIcon.question` is not used by any dialog but is kept
  because its icon is drawn. The results of About and Help are ignored on purpose.
- **Windows is unverified.** The build, the runtime and printing have not been run there.

## Architecture

Organised as the Flutter app architecture guide recommends: UI layer (widgets plus view
model), data layer (repositories and services), and a small domain layer for pure text logic.

```
lib/
  main.dart                       window setup, then runApp
  app.dart                        providers (provider package) and WidgetsApp root
  config/app_dependencies.dart    the object graph; tests build it with fakes
  config/app_info.dart            the version shown in Help > About (tested against pubspec.yaml)
  domain/                         pure Dart: settings models, text search, metrics, Time/Date,
                                  header and footer codes and tab stops for printing
  data/
    encoding/text_codec.dart      ANSI, UTF-16, UTF-8 and BOM detection and encoding
    repositories/                 documents and settings (abstract, then implementation)
    services/                     file listing, printing (pdf), window control
  ui/
    theme/                        Luna palette, gradients, metrics and text styles
    core/                         XP widgets: frame, caption, menus, buttons, fields, scrollbars
    notepad/
      notepad_view_model.dart     state and commands; no widget code
      notepad_screen.dart         window layout, keyboard and focus
      notepad_menus.dart          menu definitions, bound to the view model
      editor/                     the edit control (EditableText) with XP scrolling
      dialogs/                    Find, Go To, Font, Page Setup, Help, About, Open/Save, messages
  utils/                          Result, Command (async action state), file error reasons
docs/handbook/                    the HTML handbook (index.html, assets/, screenshots/)
```

Immutable models (`NotepadSettings`, `EditorFont`, `PageSetup`) and `Result` values flow
from repositories through the view model. Files over 512 KB are decoded in a background
isolate, and documents over 512K characters are encoded in one when saved. A file is read in
chunks and refused past 64 MB, so a device such as `/dev/zero` cannot exhaust memory. The PDF for
printing is laid out in an isolate. The lists are built lazily, and a folder is examined 64 entries
at a time. The editor measures its longest line once per text, not once per caret move. Painters
repaint only when their inputs change.

The native runners in `linux/` and `windows/` are generated from Flutter's template. The
Linux runner files match the template. The Linux CMake file differs from it only in the
application ID (`com.goshapps.Notepad`, finding F-21, fixed) and in a conditional block the template omits for this project.

## Dependencies

- `provider` 6.1.5+1: dependency injection, as the architecture guide suggests.
- `window_manager` 0.5.2: the borderless window and the drawn caption. Flutter has no pure-Dart
  API for removing the OS title bar, so this is the one windowing plugin.
- `printing` 5.15.1 and `pdf` 3.13.1: printing. `pdf` is pure Dart; `printing` calls the platform dialog.
- `path` 1.9.1: file path handling.

## Known differences from stock XP Notepad

- **Dialogs are drawn inside the window**, not as separate windows. They are modal, except
  Find and Replace, which are modeless.
- **Fonts.** Tahoma, Trebuchet MS and Lucida Console are used where installed. Elsewhere
  metric-compatible Liberation fonts stand in, and a family that is not installed falls back to
  the default sans font. Glyph shapes differ on Linux, and characters the font lacks show as boxes.
- **Tabs.** A tab is drawn about one space wide in the editor, and goes to the next stop eight columns apart when printed.
- **Open and Save As** have no "Places" bar, and the file list is built by the app.
- **Help Topics** lists the keyboard shortcuts in a dialog. XP opens its help file.
- **Double-click on Linux.** The Flutter Linux embedder is reported to drop the second press of a
  rapid double click, so double-clicking the caption does not maximize the window. This claim was not
  verified in the audit. The caption's double-click detection is written for platforms that deliver the second press.

The author's notes on fidelity below were not re-checked in the audit, except where the
handbook says so.

## Fidelity

The Luna colours, frame bands, caption gradient, 19px menu bar, 17px scrollbars and 13px
editor line pitch come from the Luna theme and the measured reference used by the earlier
clone. Menu and most dialog wording and the default settings (word wrap on, Lucida Console
10pt) are taken from Wine's Notepad, which reimplements Windows Notepad. The Page Setup
margins (0.75 in left and right, 1 in top and bottom), the save-changes prompt, the
"Cannot find" message and the underline-on-Alt default are from memory of XP, so check them
against a real XP install. No side-by-side screenshot comparison was made.

## Licence

This project is an unofficial recreation and is not affiliated with Microsoft. The XP
look is reproduced from measurements and published interface details. No Microsoft icons,
bitmaps or branding are used.

The project's own code is licensed under the GNU General Public License, version 3. The full
text is in the `LICENSE` file (finding F-22, fixed). Dependencies keep their own licences.
