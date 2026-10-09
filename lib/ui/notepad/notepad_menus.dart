import 'package:xp_notepad/ui/core/xp_menu.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

/// The Notepad menu bar, with items, shortcuts, and enabled or checked states that follow
/// the view model. Menu wording and order follow Windows XP Notepad.
List<XpMenu> buildNotepadMenus(NotepadViewModel vm) {
  return [
    XpMenu('&File', [
      XpMenuItem(label: '&New', shortcut: 'Ctrl+N', onSelected: vm.newDocument),
      XpMenuItem(
        label: '&Open...',
        shortcut: 'Ctrl+O',
        onSelected: vm.openDocument,
      ),
      XpMenuItem(label: '&Save', shortcut: 'Ctrl+S', onSelected: vm.save),
      XpMenuItem(label: 'Save &As...', onSelected: vm.saveAs),
      const XpMenuItem.separator(),
      XpMenuItem(label: 'Page Se&tup...', onSelected: vm.editPageSetup),
      XpMenuItem(
        label: '&Print...',
        shortcut: 'Ctrl+P',
        onSelected: vm.printDocument,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(label: 'E&xit', onSelected: vm.requestExit),
    ]),
    XpMenu('&Edit', [
      XpMenuItem(
        label: '&Undo',
        shortcut: 'Ctrl+Z',
        enabled: vm.canUndo,
        onSelected: vm.undo,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(
        label: 'Cu&t',
        shortcut: 'Ctrl+X',
        enabled: vm.hasSelection,
        onSelected: vm.cut,
      ),
      XpMenuItem(
        label: '&Copy',
        shortcut: 'Ctrl+C',
        enabled: vm.hasSelection,
        onSelected: vm.copy,
      ),
      XpMenuItem(
        label: '&Paste',
        shortcut: 'Ctrl+V',
        enabled: vm.clipboardHasText,
        onSelected: vm.paste,
      ),
      XpMenuItem(
        label: 'De&lete',
        shortcut: 'Del',
        enabled: vm.hasSelection,
        onSelected: vm.deleteSelection,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(
        label: '&Find...',
        shortcut: 'Ctrl+F',
        onSelected: () => vm.showFind(replace: false),
      ),
      XpMenuItem(
        label: 'Find &Next',
        shortcut: 'F3',
        enabled: vm.lastSearch.query.isNotEmpty,
        onSelected: vm.repeatFind,
      ),
      XpMenuItem(
        label: '&Replace...',
        shortcut: 'Ctrl+H',
        onSelected: () => vm.showFind(replace: true),
      ),
      XpMenuItem(
        label: '&Go To...',
        shortcut: 'Ctrl+G',
        enabled: !vm.wordWrap,
        onSelected: vm.showGoTo,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(
        label: 'Select &All',
        shortcut: 'Ctrl+A',
        enabled: vm.hasText,
        onSelected: vm.selectAll,
      ),
      XpMenuItem(
        label: 'Time/&Date',
        shortcut: 'F5',
        onSelected: vm.insertTimeDate,
      ),
    ]),
    XpMenu('F&ormat', [
      XpMenuItem(
        label: '&Word Wrap',
        checked: vm.wordWrap,
        checkable: true,
        onSelected: vm.toggleWordWrap,
      ),
      XpMenuItem(label: '&Font...', onSelected: vm.showFont),
    ]),
    XpMenu('&View', [
      XpMenuItem(
        label: '&Status Bar',
        checked: vm.statusBarChecked,
        checkable: true,
        enabled: !vm.wordWrap,
        onSelected: vm.toggleStatusBar,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(
        label: '&Dark Mode',
        checked: vm.darkMode,
        checkable: true,
        onSelected: vm.toggleDarkMode,
      ),
    ]),
    XpMenu('&Help', [
      XpMenuItem(
        label: '&Help Topics',
        shortcut: 'F1',
        onSelected: vm.showHelp,
      ),
      const XpMenuItem.separator(),
      XpMenuItem(label: '&About Notepad', onSelected: vm.showAbout),
    ]),
  ];
}
