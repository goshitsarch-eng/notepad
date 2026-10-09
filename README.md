# XP Notepad (Flutter)

An unofficial recreation of Windows XP Notepad (Luna, blue), written entirely in Flutter.
Every control is drawn in Flutter: there is no WebView, no HTML or CSS, and no code of our
own in the native runners. The window, menus, dialogs and status bar are Dart widgets.

**Status.** Version 0.1.2+3. The first audit covered 0.1.0+1 on 2026-10-07 and found 28 defects
(F-01 to F-28); 8 of them were fixed in 0.1.1. A second pass on 2026-10-09 fixed 15 of the other 20,
found 12 more (F-29 to F-40) and fixed 11 of those. A follow-up the same day fixed five of the six
that were left (F-14, F-16, F-19, F-26 and F-31), and two gaps the review of the second pass had noted.
That makes 39 of 40 fixed. The work was verified on Linux (x86-64, Flutter 3.47.6) through the test
suite and a release build driven by keyboard and mouse under a virtual display. The Windows build and
runtime have not been verified, and no screen reader has been tried. The one finding that is not fully
fixed is listed under Known issues, and the handbook has the evidence for all 40.

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

On Linux, `flutter analyze` reports no issues and `flutter test` runs 506 tests. Run as root, 3 of them
skip themselves, because they test file permissions and root ignores permissions (the progress line then
ends `+503 ~3`); run as an ordinary user, all 506 run and pass. The 137 tests of 0.1.1 are unchanged.
The 369 added since are in
`test/ui/audit_*_test.dart`, `test/ui/semantics_test.dart`, `test/data/*_test.dart` (the new ones),
`test/domain/print_text_test.dart`, `test/config/app_info_test.dart` and, for editing large documents,
the dialog queue, the window menu and the Open dialog's encoding, `test/ui/windowed_*_test.dart`,
`test/ui/modal_queue_test.dart`, `test/ui/system_menu_test.dart`, `test/ui/open_encoding_test.dart`
and `test/domain/text_scan_test.dart` and `edit_history_test.dart`. Each one names the finding it
guards, and where a fix was made the test was seen to fail without it. The last one fails when the version in `pubspec.yaml`, the About box, the Flatpak metadata, the
Windows installer script and this file do not agree, so change them together.

The golden tests use 16 images in `test/ui/goldens/`. The 13 in `test/ui/notepad_golden_test.dart`
are skipped when the Liberation fonts are missing. The 3 dark-mode images in
`test/ui/dark_mode_and_help_test.dart` are not skipped. Four images changed in 0.1.2 on purpose: the
About box now shows the version, the Go To number is selected when the box opens, the Open dialog has an
Encoding list, and the Font dialog's Script box is greyed. Regenerate goldens with
`flutter test --update-goldens` only after an intended visual change, and review the images.

## What it does

- **Window.** Caption with minimize, maximize and close buttons; drag the caption to move;
  resize from any edge or corner. Alt+Space, a click on the caption icon or a right click on the
  caption opens the window menu (Restore, Minimize, Maximize, Close), so every window command has a
  keyboard route. The content cannot be smaller than 400 × 310, which is the height
  the Edit menu needs. The title follows the document: `notes.txt - Notepad`, or `Untitled - Notepad`.
- **Menus.** File, Edit, Format, View and Help, in XP's order, with shortcuts, Alt
  mnemonics and keyboard navigation.
- **Editing.** Undo, cut, copy, paste, delete, select all, Find, Find Next, Replace,
  Replace All, Go To, and Time/Date (`3:31 PM 10/7/2026`). Tab inserts a tab character. A document
  of more than 128 thousand characters is edited through a window of its text, which keeps typing
  quick however large the file is (see Large documents).
- **Files.** Open and Save As in an XP-style dialog. ANSI (Windows-1252), Unicode (UTF-16 LE),
  Unicode big endian and UTF-8, with byte order marks where XP writes them and CRLF line endings
  on disk. A byte order mark says what a file is. Without one, UTF-16 is recognised by its zero bytes (and only when the other bytes look like text, so ASCII with a NUL in it is left alone),
  valid UTF-8 is read as UTF-8 and the rest as ANSI. The Open dialog's Encoding list reads a file as a
  chosen encoding instead, for the files that cannot be told apart, such as UTF-16 Japanese text
  without a mark. Saving text that ANSI cannot hold asks first. Files over 64 MB are refused, and files
  over 16 million characters ask first, because they take several seconds to open and a lot of
  memory. When a file cannot be opened or saved, the message gives the reason the system reported.
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

## Large documents

Flutter lays out the whole text of a text field again after every edit, about 0.5 s per megabyte
in a release build under software rendering (a virtual machine, so absolute times will differ). The first
audit blamed the platform's text input for the slowness; a later profile showed it is this layout
(F-31). A document of at least 128 thousand characters is therefore edited through a window: the text
box holds the lines around what is on screen, a few hundred lines, and empty space above and below
stands in for the rest, so the scroll bar and the wheel cover the whole document. The whole text stays
in one place for everything else (save, print, Find, Replace All, Go To, the status bar), and edits
made in the window are written into it. Undo works on the whole document, Select All and Ctrl+Home and
Ctrl+End reach the ends of it, and a key typed while the caret is out of sight scrolls back to it first.

| Document | One typed character, before | One typed character, now |
|---|---|---|
| 1 MB | 0.5 s of processor time | 0.01 s |
| 5 MB | 3 to 6 s, 2.3 GB of memory | 0.03 s, 0.25 GB |
| 20 MB | not measured (minutes, many gigabytes) | 0.06 s |
| 60 MB | not measured | 0.13 s |

The figures are the processor time of the application's main thread over the idle baseline, from release
builds of the merged 0.1.2 and of this version under Xvfb, on a four-core virtual machine.

The limits that remain are in Known issues.

## Known issues

The full list, with evidence, reproduction steps and recommendations, is in the handbook's
[audit findings](docs/handbook/index.html#findings). 39 of the 40 findings are fixed. One is not fully
fixed, and Windows has not been checked:

- **The interface has semantics, but no screen reader has been tried (F-15, Medium).** Menus, buttons,
  fields, check boxes, radio buttons, lists, dialogs and the status bar have names, roles and states, and
  the window behind a dialog is hidden. This was checked through Flutter's semantics tree only. For a
  large document the editor's text is the window of lines, so a screen reader is told only those.
- **Windows is unverified.** The build, the runtime and printing have not been run there. Two things
  were written for Windows and tested only by simulating its behaviour: the key events of AltGr (the
  engine holds a Ctrl down while it is pressed, and Alt with Ctrl is never taken for a menu accelerator;
  the order of events was read in the engine's source, not run) and a short wait and retry when a
  virus scanner or indexer holds the file at the moment a save moves it into place.
- **Limits of large documents.** The window holds whole lines, so a line of many tens of thousands
  of characters is laid out whole and a file made of enormous lines (minified JSON, say) is still slow to
  edit, in proportion to the length of the line. Each key copies the whole text, which is about 0.13 s
  at 60 MB. With word wrap on, the size and place of the scroll bar's thumb are estimates, because lines
  wrap to different heights; the text on screen stays exactly where it is. The window does not move
  while a mouse button is held down in the text, so a selection that is being dragged is not disturbed,
  and moves when the button is released; this was tested with simulated pointers, and a long drag
  has not been tried with a real mouse. UTF-16 text in Chinese, Japanese or Korean without a byte order
  mark has too few zero bytes to be recognised: choose Unicode in the Open dialog.

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
                                  header and footer codes and tab stops for printing, line
                                  scanning and the undo list used for large documents
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
      editor/                     the edit control (EditableText) with XP scrolling, and the
                                  window of text that large documents are edited through
      dialogs/                    Find, Go To, Font, Page Setup, Help, About, Open/Save, messages
  utils/                          Result, Command (async action state), file error reasons
docs/handbook/                    the HTML handbook (index.html, assets/, screenshots/)
```

Immutable models (`NotepadSettings`, `EditorFont`, `PageSetup`) and `Result` values flow
from repositories through the view model. Files over 512 KB are decoded in a background
isolate, and documents over 512K characters are encoded in one when saved. A file is read in
chunks and refused past 64 MB, so a device such as `/dev/zero` cannot exhaust memory. The PDF for
printing is laid out in an isolate. The lists are built lazily, and a folder is examined 64 entries
at a time. The editor measures its longest line once per text, not once per caret move. A document of
128 thousand characters or more is edited through a window of its lines. Painters repaint only when
their inputs change. A dialog that is ready while another is open waits its turn.

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
