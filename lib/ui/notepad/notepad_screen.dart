import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/data/services/window_service.dart';
import 'package:xp_notepad/ui/core/xp_caption.dart';
import 'package:xp_notepad/ui/core/xp_frame.dart';
import 'package:xp_notepad/ui/core/xp_resize_edge.dart';
import 'package:xp_notepad/ui/core/xp_menu.dart';
import 'package:xp_notepad/ui/core/xp_status_bar.dart';
import 'package:xp_notepad/ui/notepad/dialogs/dialog_host.dart';
import 'package:xp_notepad/ui/notepad/dialogs/find_dialog.dart';
import 'package:xp_notepad/ui/notepad/editor/xp_editor.dart';
import 'package:xp_notepad/ui/notepad/notepad_menus.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// The Notepad window: caption, menu bar, editor and status bar, with the menus and
/// dialogs layered on top. It renders the view model and passes input to it.
/// A keyboard command. Editing commands act on the document, so they are disabled while a
/// text box in a dialog has focus, and the key then reaches that text box.
class _KeyCommand extends Intent {
  const _KeyCommand(this.run, {this.editing = false});

  final VoidCallback run;
  final bool editing;
}

/// Runs a [_KeyCommand] unless a modal dialog is open, or an editing command is used while
/// a text box has focus. A disabled action lets the key continue to the focused field.
class _KeyCommandAction extends Action<_KeyCommand> {
  _KeyCommandAction({required this.modalOpen, required this.documentFocused});

  final bool Function() modalOpen;
  final bool Function() documentFocused;

  @override
  bool isEnabled(_KeyCommand intent) {
    if (modalOpen()) return false;
    return !intent.editing || documentFocused();
  }

  @override
  Object? invoke(_KeyCommand intent) {
    intent.run();
    return null;
  }
}

class NotepadScreen extends StatefulWidget {
  const NotepadScreen({super.key});

  @override
  State<NotepadScreen> createState() => _NotepadScreenState();
}

class _NotepadScreenState extends State<NotepadScreen> {
  late final NotepadViewModel _vm;
  final _rootFocus = FocusNode(debugLabel: 'notepad');
  final _editorFocus = FocusNode(debugLabel: 'editor');
  int? _highlight;
  bool _altHeld = false;
  bool _altUsed = false;
  bool _modalWas = false;
  bool _findWas = false;
  int? _menuWas;

  @override
  void initState() {
    super.initState();
    _vm = context.read<NotepadViewModel>();
    _vm.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _vm.modal == null) _editorFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _rootFocus.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  /// Keeps keyboard focus where XP puts it: on the menu while one is open, on a dialog
  /// while one is open, and back in the text when either closes.
  void _onViewModelChanged() {
    final menu = _vm.openMenu;
    if (menu != _menuWas) {
      _menuWas = menu;
      if (menu != null) {
        _rootFocus.requestFocus();
      } else if (_vm.modal == null) {
        _restoreFocus();
      }
    }
    final modal = _vm.modal != null;
    final find = _vm.find != null;
    final closed = (_modalWas && !modal) || (_findWas && !find);
    if (closed && !modal && _vm.openMenu == null) _restoreFocus();
    _modalWas = modal;
    _findWas = find;
  }

  /// Focus goes back to the Find box while Find is open, and to the editor otherwise. While
  /// Find is open, typing must not fall through to the document.
  void _restoreFocus() {
    if (_vm.find != null) {
      _vm.focusFind();
    } else {
      _editorFocus.requestFocus();
    }
  }

  List<XpMenu> _menus() => buildNotepadMenus(_vm);

  /// Runs an accelerator unless a modal dialog is open.
  void _run(Function action) {
    if (_vm.modal != null) return;
    action();
  }

  void _findAgain() {
    if (_vm.lastSearch.query.isEmpty) {
      _vm.showFind(replace: false);
    } else {
      _vm.repeatFind();
    }
  }

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyN, control: true): _KeyCommand(
      _vm.newDocument,
    ),
    const SingleActivator(LogicalKeyboardKey.keyO, control: true): _KeyCommand(
      _vm.openDocument,
    ),
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): _KeyCommand(
      _vm.save,
    ),
    const SingleActivator(LogicalKeyboardKey.keyP, control: true): _KeyCommand(
      _vm.printDocument,
    ),
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _KeyCommand(
      _vm.undo,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.keyX, control: true): _KeyCommand(
      _vm.cut,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.keyC, control: true): _KeyCommand(
      _vm.copy,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.keyV, control: true): _KeyCommand(
      _vm.paste,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.keyA, control: true): _KeyCommand(
      _vm.selectAll,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): _KeyCommand(
      () => _vm.showFind(replace: false),
    ),
    const SingleActivator(LogicalKeyboardKey.keyH, control: true): _KeyCommand(
      () => _vm.showFind(replace: true),
    ),
    const SingleActivator(LogicalKeyboardKey.keyG, control: true): _KeyCommand(
      () {
        if (!_vm.wordWrap) _vm.showGoTo();
      },
    ),
    const SingleActivator(LogicalKeyboardKey.f1): _KeyCommand(_vm.showHelp),
    const SingleActivator(LogicalKeyboardKey.f3): _KeyCommand(_findAgain),
    const SingleActivator(LogicalKeyboardKey.f5): _KeyCommand(
      _vm.insertTimeDate,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.insert, control: true):
        _KeyCommand(_vm.copy, editing: true),
    const SingleActivator(LogicalKeyboardKey.insert, shift: true): _KeyCommand(
      _vm.paste,
      editing: true,
    ),
    const SingleActivator(LogicalKeyboardKey.backspace, alt: true): _KeyCommand(
      _vm.undo,
      editing: true,
    ),
  };

  /// True while the document or the window itself has focus, rather than a text box in a
  /// dialog. Editing keys are left to that text box.
  bool _documentHasFocus() {
    final focus = FocusManager.instance.primaryFocus;
    return focus == null ||
        focus is FocusScopeNode ||
        focus == _editorFocus ||
        focus == _rootFocus;
  }

  String? _letterOf(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    return label.length == 1 ? label.toLowerCase() : null;
  }

  int? _menuIndexFor(String letter) {
    final menus = _menus();
    for (var i = 0; i < menus.length; i++) {
      if (MenuLabel.parse(menus[i].label).mnemonic == letter) return i;
    }
    return null;
  }

  int? _firstEnabled(List<XpMenuItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (!items[i].isSeparator && items[i].enabled) return i;
    }
    return null;
  }

  void _openMenuFromKeyboard(int index) {
    final items = _menus()[index].items;
    setState(() => _highlight = _firstEnabled(items));
    _vm.openMenuAt(index);
    unawaited(_vm.refreshClipboard());
  }

  void _closeMenu() {
    setState(() => _highlight = null);
    _vm.closeMenu();
  }

  void _activate(XpMenuItem item) {
    _closeMenu();
    if (item.enabled) item.onSelected?.call();
  }

  void _moveHighlight(List<XpMenuItem> items, int step) {
    if (items.isEmpty) return;
    var index = _highlight ?? (step > 0 ? -1 : items.length);
    for (var i = 0; i < items.length; i++) {
      index = (index + step + items.length) % items.length;
      final item = items[index];
      if (!item.isSeparator && item.enabled) {
        setState(() => _highlight = index);
        return;
      }
    }
  }

  /// Keys while a menu is open go to the menu. Alt and letters open menus as in XP.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (_vm.modal != null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      if (event is KeyDownEvent) {
        _altHeld = true;
        _altUsed = false;
      } else if (event is KeyUpEvent) {
        _altHeld = false;
        if (!_altUsed) _vm.setMenuCue(true);
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_altHeld) _altUsed = true;

    final openIndex = _vm.openMenu;
    if (openIndex != null) return _handleMenuKey(key, openIndex);

    if (_altHeld) {
      final letter = _letterOf(key);
      final index = letter == null ? null : _menuIndexFor(letter);
      if (index != null) {
        _vm.setMenuCue(true);
        _openMenuFromKeyboard(index);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleMenuKey(LogicalKeyboardKey key, int openIndex) {
    final menus = _menus();
    final items = menus[openIndex].items;
    if (key == LogicalKeyboardKey.escape) {
      _closeMenu();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(items, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(items, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _openMenuFromKeyboard((openIndex + 1) % menus.length);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _openMenuFromKeyboard((openIndex - 1 + menus.length) % menus.length);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final index = _highlight;
      if (index != null) _activate(items[index]);
    } else {
      final letter = _letterOf(key);
      if (letter != null) {
        final itemIndex = items.indexWhere(
          (item) =>
              !item.isSeparator &&
              item.enabled &&
              MenuLabel.parse(item.label).mnemonic == letter,
        );
        if (itemIndex >= 0) {
          _activate(items[itemIndex]);
        } else {
          final menuIndex = _menuIndexFor(letter);
          if (menuIndex != null) _openMenuFromKeyboard(menuIndex);
        }
      }
    }
    return KeyEventResult.handled;
  }

  void _onMenuPressed(int index) {
    if (_vm.openMenu == index && _vm.menuOpenedByClick) {
      _closeMenu();
      return;
    }
    setState(() => _highlight = null);
    _vm.openMenuAt(index, byClick: true);
    unawaited(_vm.refreshClipboard());
  }

  void _onMenuHovered(int index) {
    final open = _vm.openMenu;
    if (open == null || open == index) return;
    setState(() => _highlight = null);
    _vm.openMenuAt(index);
    unawaited(_vm.refreshClipboard());
  }

  /// Left edge of the popup under menu [index], in window coordinates.
  double _menuLeft(List<XpMenu> menus, int index) {
    var left = XpMetrics.frame;
    for (var i = 0; i < index; i++) {
      left += XpMenuLayout.barLabelWidth(menus[i].label);
    }
    return left;
  }

  double _popupHeight(List<XpMenuItem> items) {
    var height = 4.0;
    for (final item in items) {
      height += item.isSeparator ? 6 : XpMetrics.menuRowHeight;
    }
    return height;
  }

  static const _barTop = XpMetrics.captionHeight;
  static const _popupTop = XpMetrics.captionHeight + XpMetrics.menuBarHeight;

  /// Clicks outside an open menu close it. Clicks on the menu bar go to its labels.
  void _onPointerDown(PointerDownEvent event, List<XpMenu> menus) {
    if (_vm.menuCue) _vm.setMenuCue(false);
    final openIndex = _vm.openMenu;
    if (openIndex == null) return;
    final position = event.localPosition;
    if (position.dy >= _barTop && position.dy < _popupTop) return;
    final items = menus[openIndex].items;
    final popup = Rect.fromLTWH(
      _menuLeft(menus, openIndex),
      _popupTop,
      XpMenuLayout.popupWidth(items),
      _popupHeight(items),
    );
    if (popup.contains(position)) return;
    _closeMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocus,
      onKeyEvent: _onKeyEvent,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: {
            _KeyCommand: _KeyCommandAction(
              modalOpen: () => _vm.modal != null,
              documentFocused: _documentHasFocus,
            ),
          },
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => _buildWindow(),
          ),
        ),
      ),
    );
  }

  Widget _buildWindow() {
    final menus = _menus();
    final openIndex = _vm.openMenu;
    return Listener(
      onPointerDown: (event) => _onPointerDown(event, menus),
      child: XpWindowFrame(
        active: _vm.isActive,
        child: Stack(
          children: [
            Column(
              children: [
                XpCaption(
                  title: _vm.windowTitle,
                  active: _vm.isActive,
                  maximized: _vm.isMaximized,
                  onDragStart: _vm.startDragging,
                  onToggleMaximize: _vm.toggleMaximize,
                  onMinimize: _vm.minimize,
                  onClose: () => _run(_vm.requestExit),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XpMetrics.frame,
                  ),
                  child: XpMenuBar(
                    menus: menus,
                    openIndex: openIndex,
                    showMnemonics: _vm.menuCue,
                    onPressed: _onMenuPressed,
                    onHovered: _onMenuHovered,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: XpMetrics.frame,
                    ),
                    padding: const EdgeInsets.only(top: 1),
                    color: XpColors.paper,
                    child: XpEditor(
                      key: ValueKey(_vm.editorGeneration),
                      controller: _vm.text,
                      focusNode: _editorFocus,
                      undoHistory: _vm.undoHistory,
                      font: _vm.font,
                      wordWrap: _vm.wordWrap,
                      revealSerial: _vm.revealSerial,
                      onTab: () => _run(() => _vm.insertText('\t')),
                    ),
                  ),
                ),
                if (_vm.statusBarVisible)
                  ListenableBuilder(
                    listenable: _vm.text,
                    builder: (context, _) => XpStatusBar(
                      text: _vm.statusText,
                      onResizeStart: () =>
                          _vm.startResizing(ResizeDirection.bottomRight),
                    ),
                  ),
                const SizedBox(height: XpMetrics.frame),
              ],
            ),
            // The frame bands and corners resize the window from every side, as XP's
            // frame does. The corners come last so they take the hits they overlap.
            ..._resizeEdges(),
            if (openIndex != null) _popupLayer(menus, openIndex),
            // Find is modeless and sits under a modal message or dialog, which must stay on
            // top and block the Find box as well as the text.
            if (_vm.find case final find?)
              Positioned.fill(
                child: Center(
                  child: FindDialog(
                    key: ValueKey('find-${find.replace}'),
                    replace: find.replace,
                  ),
                ),
              ),
            if (_vm.modal case final modal?) ModalDialogHost(request: modal),
          ],
        ),
      ),
    );
  }

  List<Widget> _resizeEdges() {
    const frame = XpMetrics.frame;
    const top = XpMetrics.captionHeight;
    XpResizeEdge grip(ResizeDirection direction, MouseCursor cursor) {
      return XpResizeEdge(
        cursor: cursor,
        onStart: () => _vm.startResizing(direction),
      );
    }

    return [
      Positioned(
        top: top,
        left: 0,
        bottom: frame,
        width: frame,
        child: grip(ResizeDirection.left, SystemMouseCursors.resizeLeftRight),
      ),
      Positioned(
        top: top,
        right: 0,
        bottom: frame,
        width: frame,
        child: grip(ResizeDirection.right, SystemMouseCursors.resizeLeftRight),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: frame,
        child: grip(ResizeDirection.top, SystemMouseCursors.resizeUpDown),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: frame,
        child: grip(ResizeDirection.bottom, SystemMouseCursors.resizeUpDown),
      ),
      Positioned(
        top: 0,
        left: 0,
        width: frame,
        height: frame,
        child: grip(
          ResizeDirection.topLeft,
          SystemMouseCursors.resizeUpLeftDownRight,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        width: frame,
        height: frame,
        child: grip(
          ResizeDirection.topRight,
          SystemMouseCursors.resizeUpRightDownLeft,
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        width: frame,
        height: frame,
        child: grip(
          ResizeDirection.bottomLeft,
          SystemMouseCursors.resizeUpRightDownLeft,
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        width: frame,
        height: frame,
        child: grip(
          ResizeDirection.bottomRight,
          SystemMouseCursors.resizeUpLeftDownRight,
        ),
      ),
    ];
  }

  Widget _popupLayer(List<XpMenu> menus, int index) {
    final items = menus[index].items;
    return Positioned(
      left: _menuLeft(menus, index),
      top: _popupTop,
      child: XpMenuPopup(
        items: items,
        highlight: _highlight,
        showMnemonics: _vm.menuCue,
        onHighlight: (item) => setState(() => _highlight = item),
        onActivate: (item) => _activate(items[item]),
      ),
    );
  }
}
