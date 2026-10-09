import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/data/repositories/settings_repository.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/data/services/printing_service.dart';
import 'package:xp_notepad/data/services/window_service.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/domain/text/time_date.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/utils/command.dart';
import 'package:xp_notepad/utils/file_error.dart';
import 'package:xp_notepad/utils/result.dart';

typedef _SaveRequest = ({String path, String text, FileEncoding encoding});

/// Documents longer than this many characters get a warning before they open. The
/// platform's text input carries the whole text across on every edit, so typing in a
/// document this size takes seconds per key and can use gigabytes of memory.
const kLargeDocumentCharacters = 2 * 1024 * 1024;

/// State and commands of the Notepad window. The view reads it and calls its methods. It
/// reaches files, settings, printing and the window only through their interfaces.
class NotepadViewModel extends ChangeNotifier implements WindowEventHandler {
  NotepadViewModel({
    required this.documents,
    required this.settingsRepository,
    required this.fileSystem,
    required this.printing,
    required this.window,
    required NotepadSettings settings,
    this.clock = DateTime.now,
  }) {
    _settings = settings;
    XpColors.dark = settings.darkMode;
    _saveCommand = Command1<void, _SaveRequest>(
      (request) =>
          documents.write(request.path, request.text, request.encoding),
    );
    text.addListener(_onTextChanged);
  }

  final DocumentRepository documents;
  final SettingsRepository settingsRepository;
  final FileSystemService fileSystem;
  final PrintingService printing;
  final WindowService window;
  final DateTime Function() clock;
  late final Command1<void, _SaveRequest> _saveCommand;

  /// The document text. The editor binds to this controller directly.
  final NotepadTextController text = NotepadTextController();
  final UndoHistoryController undoHistory = UndoHistoryController();

  /// Bumps when the caret should be scrolled into view.
  final ValueNotifier<int> revealSerial = ValueNotifier<int>(0);

  /// Counts the requests that replace the document. A read that finishes after a newer
  /// request has started is dropped, so it cannot replace what the user chose since.
  int _documentRequest = 0;

  late NotepadSettings _settings;

  /// The last size the window had while it was not maximized. Saved at exit, so a
  /// maximized window does not persist its maximized size as the normal one.
  ({double width, double height})? _normalBounds;
  String? _path;
  FileEncoding _encoding = FileEncoding.ansi;
  bool _modified = false;
  String _lastText = '';
  bool _active = true;
  bool _maximized = false;
  bool _exiting = false;
  int _editorGeneration = 0;
  int? _openMenu;
  bool _menuOpenedByClick = false;
  bool _menuCue = false;
  bool _clipboardHasText = false;
  ModalRequest<Object?>? _modal;
  FindState? _find;
  SearchOptions _lastSearch = const SearchOptions();

  // ---- What the view shows ----

  String get fileName => _path == null ? 'Untitled' : p.basename(_path!);

  String get windowTitle => '$fileName - Notepad';

  bool get isModified => _modified;

  bool get wordWrap => _settings.wordWrap;

  /// The View > Status Bar check mark.
  bool get statusBarChecked => _settings.statusBarVisible;

  /// The bar is shown only when the setting is on and word wrap is off, as in XP.
  bool get statusBarVisible =>
      _settings.statusBarVisible && !_settings.wordWrap;

  EditorFont get font => _settings.font;

  PageSetup get pageSetup => _settings.pageSetup;

  int? get openMenu => _openMenu;

  bool get menuOpenedByClick => _menuOpenedByClick;

  bool get menuCue => _menuCue;

  bool get clipboardHasText => _clipboardHasText;

  ModalRequest<Object?>? get modal => _modal;

  FindState? get find => _find;

  SearchOptions get lastSearch => _lastSearch;

  bool get isActive => _active;

  bool get isMaximized => _maximized;

  int get editorGeneration => _editorGeneration;

  bool get hasSelection =>
      text.selection.isValid && !text.selection.isCollapsed;

  bool get hasText => text.text.isNotEmpty;

  bool get canUndo => undoHistory.value.canUndo;

  CaretPosition get caret =>
      TextMetrics.caretAt(text.text, text.selection.extentOffset);

  String get statusText {
    final position = caret;
    return 'Ln ${position.line}, Col ${position.column}';
  }

  // ---- Document lifecycle ----

  Future<void> newDocument() async {
    if (!await _confirmDiscardChanges()) return;
    _setDocument('', path: null, encoding: FileEncoding.ansi);
  }

  Future<void> openDocument() async {
    final asked = text.text;
    if (!await _confirmDiscardChanges()) return;
    // The user has just agreed to lose these edits, so the load does not ask again.
    // Text typed since the question was asked, such as while the Yes answer was still
    // saving, is different text and was never agreed to, so it is left to ask.
    final agreed = text.text == asked ? asked : null;
    final choice = await _showModal(
      FileRequest(
        mode: FileDialogMode.open,
        startDirectory: _startDirectory(),
        encoding: _encoding,
      ),
    );
    if (choice == null) return;
    await _openPath(choice.path, discardAgreedFor: agreed);
  }

  Future<bool> save() async {
    final path = _path;
    if (path == null) return saveAs();
    return _writeTo(path, _encoding);
  }

  Future<bool> saveAs() async {
    final choice = await _showModal(
      FileRequest(
        mode: FileDialogMode.save,
        startDirectory: _startDirectory(),
        encoding: _encoding,
        suggestedName: _path == null ? null : fileName,
      ),
    );
    if (choice == null) return false;
    if (choice.path != _path && await fileSystem.fileExists(choice.path)) {
      final answer = await _message(
        'Notepad',
        '${p.basename(choice.path)} already exists.\n\nDo you want to replace it?',
        MessageIcon.warning,
        [MessageChoice.yes, MessageChoice.no],
      );
      if (answer != MessageChoice.yes) return false;
    }
    return _writeTo(choice.path, choice.encoding);
  }

  Future<void> editPageSetup() async {
    final result = await _showModal(
      PageSetupRequest(initial: _settings.pageSetup),
    );
    if (result == null) return;
    _settings = _settings.copyWith(pageSetup: result);
    _persistSettings();
    notifyListeners();
  }

  Future<void> printDocument() async {
    final result = await printing.printDocument(
      text: text.text,
      documentName: fileName,
      setup: _settings.pageSetup,
    );
    if (result is Failure<void>) {
      await _message(
        'Notepad',
        'Notepad cannot print the document.',
        MessageIcon.error,
        [MessageChoice.ok],
      );
    }
  }

  /// File > Exit, the caption close button and Alt+F4 all end here.
  Future<void> requestExit() async {
    if (_exiting) return;
    if (!await _confirmDiscardChanges()) return;
    _exiting = true;
    _resizeSettle?.cancel();
    final normal = await window.isMaximized()
        ? _normalBounds
        : await window.currentSize();
    if (normal != null) {
      _settings = _settings.copyWith(
        windowWidth: normal.width,
        windowHeight: normal.height,
      );
    }
    await _saveSettings();
    await window.setPreventClose(false);
    await window.closeWindow();
  }

  // ---- Editing ----

  void undo() {
    if (canUndo) undoHistory.undo();
  }

  Future<void> cut() async {
    if (!hasSelection) return;
    final selected = _selectedText;
    _replaceSelection('');
    await Clipboard.setData(ClipboardData(text: selected));
  }

  Future<void> copy() async {
    if (!hasSelection) return;
    await Clipboard.setData(ClipboardData(text: _selectedText));
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text;
    if (pasted == null || pasted.isEmpty) return;
    _replaceSelection(pasted.replaceAll('\r\n', '\n'));
  }

  void deleteSelection() {
    if (hasSelection) _replaceSelection('');
  }

  void selectAll() {
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
  }

  void insertTimeDate() => insertText(formatTimeDate(clock()));

  void insertText(String value) => _replaceSelection(value);

  /// Refreshes whether Edit > Paste is available. Called when a menu opens.
  Future<void> refreshClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final available = (data?.text ?? '').isNotEmpty;
    if (available == _clipboardHasText) return;
    _clipboardHasText = available;
    notifyListeners();
  }

  // ---- Find, Replace and Go To ----

  /// Bumps each time Find or Replace is asked for, so an open dialog can take focus again.
  final ValueNotifier<int> findRequests = ValueNotifier<int>(0);

  /// Bumps when keyboard focus should return to the open Find box. Unlike [findRequests]
  /// it keeps the text the user has typed there.
  final ValueNotifier<int> findFocusRequests = ValueNotifier<int>(0);

  /// Gives focus back to the open Find box, for example after a message box closes.
  void focusFind() => findFocusRequests.value++;

  void showFind({required bool replace}) {
    if (hasSelection && !_selectedText.contains('\n')) {
      _lastSearch = _lastSearch.copyWith(query: _selectedText);
    }
    _find = FindState(replace: replace);
    findRequests.value++;
    notifyListeners();
  }

  void closeFind() {
    if (_find == null) return;
    _find = null;
    notifyListeners();
  }

  /// Selects the next match from the caret. Returns false and says so when nothing matches.
  bool findNext(SearchOptions options) {
    _lastSearch = options;
    final selection = text.selection;
    final from = options.forward
        ? (selection.isValid ? selection.end : 0)
        : (selection.isValid ? selection.start : text.text.length);
    final match = TextSearch.find(text.text, options, from: from);
    if (match == null) {
      unawaited(
        _message(
          'Notepad',
          'Cannot find "${options.query}"',
          MessageIcon.information,
          [MessageChoice.ok],
        ),
      );
      return false;
    }
    _select(match.start, match.end);
    notifyListeners();
    return true;
  }

  void repeatFind() => findNext(_lastSearch);

  bool replaceCurrent(SearchOptions options, String replacement) {
    _lastSearch = options;
    if (hasSelection) {
      final selected = _selectedText;
      final exact = TextSearch.find(
        selected,
        options.copyWith(forward: true),
        from: 0,
      );
      if (exact != null && exact.start == 0 && exact.end == selected.length) {
        _replaceSelection(replacement);
      }
    }
    return findNext(options);
  }

  /// Replace All. Reports when nothing matched, as XP does.
  bool replaceAllMatches(SearchOptions options, String replacement) {
    _lastSearch = options;
    final result = TextSearch.replaceAll(text.text, options, replacement);
    if (result.count == 0) {
      unawaited(
        _message(
          'Notepad',
          'Cannot find "${options.query}"',
          MessageIcon.information,
          [MessageChoice.ok],
        ),
      );
      return false;
    }
    text.value = TextEditingValue(
      text: result.text,
      selection: const TextSelection.collapsed(offset: 0),
    );
    return true;
  }

  Future<void> showGoTo() async {
    final result = await _showModal(GoToRequest(currentLine: caret.line));
    if (result != null) goToLine(result);
  }

  void goToLine(int line) {
    final lines = TextMetrics.lineCount(text.text);
    final target = line < 1 ? 1 : (line > lines ? lines : line);
    text.selection = TextSelection.collapsed(
      offset: TextMetrics.lineStart(text.text, target),
    );
    revealSerial.value++;
  }

  // ---- Format and View ----

  void toggleWordWrap() {
    _settings = _settings.copyWith(wordWrap: !_settings.wordWrap);
    _persistSettings();
    notifyListeners();
  }

  void toggleStatusBar() {
    if (_settings.wordWrap) return;
    _settings = _settings.copyWith(
      statusBarVisible: !_settings.statusBarVisible,
    );
    _persistSettings();
    notifyListeners();
  }

  Future<void> showFont() async {
    final result = await _showModal(FontRequest(initial: _settings.font));
    if (result == null) return;
    _settings = _settings.copyWith(font: result);
    _persistSettings();
    notifyListeners();
  }

  // ---- Help ----

  Future<void> showAbout() async {
    await _showModal(AboutRequest());
  }

  /// Help > Help Topics and F1. Lists the shortcuts the app really responds to.
  Future<void> showHelp() async {
    await _showModal(HelpRequest());
  }

  bool get darkMode => _settings.darkMode;

  /// View > Dark Mode. The colours switch on the next frame and the choice is saved.
  void toggleDarkMode() {
    _settings = _settings.copyWith(darkMode: !_settings.darkMode);
    XpColors.dark = _settings.darkMode;
    _persistSettings();
    notifyListeners();
  }

  // ---- Menus and keyboard cues ----

  /// Opens the menu at [index], or closes the menu when [index] is null.
  void openMenuAt(int? index, {bool byClick = false}) {
    _openMenu = index;
    _menuOpenedByClick = index != null && byClick;
    notifyListeners();
  }

  void closeMenu() {
    if (_openMenu == null) return;
    _openMenu = null;
    _menuOpenedByClick = false;
    notifyListeners();
  }

  void setMenuCue(bool visible) {
    if (_menuCue == visible) return;
    _menuCue = visible;
    notifyListeners();
  }

  // ---- Window ----

  void startDragging() => unawaited(window.startDragging());

  void startResizing(ResizeDirection direction) =>
      unawaited(window.startResizing(direction));

  void minimize() => unawaited(window.minimize());

  void toggleMaximize() => unawaited(window.toggleMaximize());

  /// Connects the window events and sets the first title. Opens [initialPath] if given.
  void start({String? initialPath}) {
    window.attach(this);
    unawaited(window.setPreventClose(true));
    unawaited(window.setTitle(windowTitle));
    unawaited(refreshClipboard());
    if (initialPath != null) unawaited(_openPath(initialPath));
  }

  @override
  void onCloseRequested() {
    // The window cannot close while a dialog is open. Otherwise the close would replace
    // that dialog and leave its answer unread.
    if (_modal != null) return;
    unawaited(requestExit());
  }

  @override
  void onActiveChanged(bool active) {
    if (_active == active) return;
    _active = active;
    if (!active) _openMenu = null;
    notifyListeners();
  }

  @override
  void onMaximizedChanged(bool maximized) {
    if (_maximized == maximized) return;
    _maximized = maximized;
    notifyListeners();
  }

  Timer? _resizeSettle;

  @override
  void onResized() {
    _resizeSettle?.cancel();
    _resizeSettle = Timer(const Duration(milliseconds: 150), () {
      unawaited(_settleSize());
    });
  }

  /// Runs after a resize. Linux window managers can let an edge drag go below the
  /// minimum size, so the app holds the minimum itself. It also remembers the size the
  /// window has when it is not maximized.
  Future<void> _settleSize() async {
    final size = await window.currentSize();
    const minimum = kMinimumWindowSize;
    if (size.width < minimum.width || size.height < minimum.height) {
      await window.setSize(
        size.width < minimum.width ? minimum.width : size.width,
        size.height < minimum.height ? minimum.height : size.height,
      );
      return;
    }
    if (await window.isMaximized()) return;
    _normalBounds = size;
  }

  @override
  void dispose() {
    _resizeSettle?.cancel();
    text.removeListener(_onTextChanged);
    text.dispose();
    undoHistory.dispose();
    revealSerial.dispose();
    findRequests.dispose();
    findFocusRequests.dispose();
    super.dispose();
  }

  // ---- Internals ----

  String get _selectedText =>
      text.text.substring(text.selection.start, text.selection.end);

  void _onTextChanged() {
    final current = text.text;
    if (current == _lastText) return;
    _lastText = current;
    if (!_modified) {
      _modified = true;
      notifyListeners();
    }
  }

  void _setDocument(
    String content, {
    required String? path,
    required FileEncoding encoding,
  }) {
    _documentRequest++;
    _path = path;
    _encoding = encoding;
    _lastText = content;
    text.value = TextEditingValue(
      text: content,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _modified = false;
    _editorGeneration++;
    _syncTitle();
    notifyListeners();
  }

  void _replaceSelection(String replacement) {
    final selection = text.selection;
    final length = text.text.length;
    final start = selection.isValid ? selection.start : length;
    final end = selection.isValid ? selection.end : length;
    text.value = TextEditingValue(
      text: text.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _select(int start, int end) {
    text.selection = TextSelection(baseOffset: start, extentOffset: end);
    revealSerial.value++;
  }

  /// Reads [path] and shows it. [discardAgreedFor] is the text the user has already
  /// agreed to lose, from the save prompt shown before the file dialog. While the text is
  /// still that, the replacement needs no second prompt.
  Future<void> _openPath(String path, {String? discardAgreedFor}) async {
    final request = ++_documentRequest;
    final result = await documents.read(path);
    // A newer New, Open or start-up file has taken over, so this result is no longer wanted.
    if (request != _documentRequest) return;
    if (result is Success<TextFile>) {
      // Text typed while the file was read is not in the file. Ask before it is replaced.
      final agreed = discardAgreedFor != null && text.text == discardAgreedFor;
      if (!agreed && !await _confirmDiscardChanges()) return;
      final file = result.value;
      if (file.text.length > kLargeDocumentCharacters &&
          !await _confirmLargeDocument(name: p.basename(path), file: file)) {
        return;
      }
      _settings = _settings.copyWith(lastDirectory: p.dirname(path));
      _persistSettings();
      _setDocument(file.text, path: path, encoding: file.encoding);
    } else if (result is Failure<TextFile>) {
      final name = p.basename(path);
      final reason = describeFileError(result.error);
      // A missing file has its own XP wording. Any other reason is told as it is.
      final missing =
          result.error is PathNotFoundException ||
          (reason.isEmpty && !await fileSystem.fileExists(path));
      await _message(
        'Notepad',
        missing
            ? 'Cannot find "$name". Make sure the path and file name are correct.'
            : 'Cannot open "$name".${reason.isEmpty ? '' : '\n\n$reason'}',
        MessageIcon.error,
        [MessageChoice.ok],
      );
    }
  }

  Future<bool> _writeTo(String path, FileEncoding encoding) async {
    // XP warns before ANSI silently replaces characters Windows-1252 cannot hold.
    if (encoding == FileEncoding.ansi && !canEncodeAnsi(text.text)) {
      final answer = await _message(
        'Notepad',
        '${p.basename(path)}\n'
            'This file contains Unicode characters which will be lost if\n'
            'you save this file in the ANSI encoding.\n'
            'To keep these characters, click Cancel, and then select\n'
            'one of the Unicode options in the Encoding drop down list.\n'
            'Continue?',
        MessageIcon.warning,
        [MessageChoice.ok, MessageChoice.cancel],
      );
      if (answer != MessageChoice.ok) return false;
    }
    final saved = text.text;
    final result = await _saveCommand.execute((
      path: path,
      text: saved,
      encoding: encoding,
    ));
    if (result == null) return false;
    if (result is Failure<void>) {
      final reason = describeFileError(result.error);
      await _message(
        'Notepad',
        'Cannot save "${p.basename(path)}" in "${p.dirname(path)}".'
            '${reason.isEmpty ? '' : '\n\n$reason'}',
        MessageIcon.error,
        [MessageChoice.ok],
      );
      return false;
    }
    _path = path;
    _encoding = encoding;
    // Typing during the save is not in the file, so the document stays modified.
    _modified = text.text != saved;
    _settings = _settings.copyWith(lastDirectory: p.dirname(path));
    _persistSettings();
    _syncTitle();
    notifyListeners();
    return true;
  }

  /// Warns that a large file is slow to edit and asks whether to open it anyway. Reading
  /// and searching such a file is fine, so the choice is the user's.
  Future<bool> _confirmLargeDocument({
    required String name,
    required TextFile file,
  }) async {
    final millions = (file.text.length / 1000000).toStringAsFixed(1);
    final answer = await _message(
      'Notepad',
      'The file "$name" is large ($millions million characters).\n\n'
          'Editing a file this size is very slow and can use a lot of memory. '
          'Reading and searching it are fine.\n\n'
          'Do you want to open it anyway?',
      MessageIcon.warning,
      [MessageChoice.yes, MessageChoice.no],
    );
    return answer == MessageChoice.yes;
  }

  /// Asks whether to save changes before the text is replaced or the window closes.
  /// Returns true when the caller may go ahead.
  Future<bool> _confirmDiscardChanges() async {
    if (!_modified) return true;
    final answer = await _message(
      'Notepad',
      'The text in the $fileName file has changed.\n\nDo you want to save the changes?',
      MessageIcon.warning,
      [MessageChoice.yes, MessageChoice.no, MessageChoice.cancel],
    );
    return switch (answer) {
      MessageChoice.yes => await save(),
      MessageChoice.no => true,
      _ => false,
    };
  }

  Future<MessageChoice?> _message(
    String title,
    String message,
    MessageIcon icon,
    List<MessageChoice> choices,
  ) {
    return _showModal(
      MessageRequest(title: title, text: message, icon: icon, choices: choices),
    );
  }

  /// Shows one modal dialog and waits for its answer. Only one is shown at a time. While
  /// one is open, a second request is refused with null, which counts as a cancel.
  Future<R?> _showModal<R>(ModalRequest<R> request) async {
    if (_modal != null) return null;
    _modal = request;
    notifyListeners();
    try {
      return await request.result;
    } finally {
      _modal = null;
      notifyListeners();
    }
  }

  /// The folder the file dialogs start in. The dialog itself moves up to the nearest
  /// folder that exists, if the last one has been deleted or moved since.
  String _startDirectory() =>
      _settings.lastDirectory ?? fileSystem.homeDirectory;

  void _syncTitle() => unawaited(window.setTitle(windowTitle));

  void _persistSettings() => unawaited(_saveSettings());

  Future<void> _saveSettings() async {
    try {
      await settingsRepository.save(_settings);
    } on FileSystemException {
      // Settings are a convenience. A failed save must not block editing or closing.
    }
  }
}
