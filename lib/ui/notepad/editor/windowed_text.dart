import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/text/edit_history.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/domain/text/text_scan.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';

/// Documents with at least this many characters are edited through a [WindowedText].
/// Laying out one paragraph costs time in proportion to its length, and the editor lays
/// the whole text out again after every key, so past this size a key press takes tens of
/// milliseconds and soon much longer.
const kWindowedDocumentCharacters = 128 * 1024;

/// The window of a document that has moved, with the text that left it and entered it. The
/// editor measures that text to keep the visible lines where they were.
class WindowShift {
  const WindowShift({
    required this.removedBefore,
    required this.addedBefore,
    required this.removedAfter,
    required this.addedAfter,
  });

  /// Whole lines that left the window at its top, with their line feed.
  final String removedBefore;

  /// Whole lines that entered the window at its top, with their line feed.
  final String addedBefore;

  /// Whole lines that left the window at its bottom, with the line feed before them.
  final String removedAfter;

  /// Whole lines that entered the window at its bottom, with the line feed before them.
  final String addedAfter;
}

/// Edits a large document through a small window of its text.
///
/// The editor lays out and sends to the platform every character it holds, on every key.
/// For a document of several megabytes that is most of a second per key. This keeps the
/// whole text in [master], which the rest of the app reads and writes as it always did,
/// and gives the editor only the lines around the part on screen in [view]. Both stay in
/// step: typing in the window is written into the document, and a change to the document
/// made by anything else, such as a paste, a search or an undo, is written into the window.
///
/// The window always starts at the start of a line and ends at the end of one, so a line
/// is never cut in two. [start] is where it begins in the document.
class WindowedText extends ChangeNotifier {
  WindowedText({
    required this.master,
    this.marginCharacters = 12000,
    this.triggerCharacters = 4000,
    this.maxViewCharacters = 160000,
    EditHistory? history,
  }) : history = history ?? EditHistory() {
    _masterText = master.text;
    _masterSelection = master.selection;
    _viewText = '';
    _lineCount = TextScan.lineFeeds(_masterText, 0, _masterText.length) + 1;
    _longestLine = TextMetrics.longestLine(_masterText);
    _load(master.selection.isValid ? master.selection.extentOffset : 0);
    master.addListener(_onMasterChanged);
    view.addListener(_onViewChanged);
  }

  /// The whole document. The rest of the app uses this controller as before.
  final TextEditingController master;

  /// The window. The text editor is bound to this controller.
  final NotepadTextController view = NotepadTextController();

  final EditHistory history;

  /// How much text is kept on each side of what is on screen.
  final int marginCharacters;

  /// The window grows on a side when less than this is left there.
  final int triggerCharacters;

  /// A window that would grow past this is rebuilt around the caret instead.
  final int maxViewCharacters;

  late String _masterText;
  late String _viewText;
  late TextSelection _masterSelection;
  TextSelection _viewSelection = const TextSelection.collapsed(offset: 0);
  int _start = 0;
  int _startLine = 0;
  int _lineCount = 1;
  String _longestLine = '';
  int _generation = 0;
  bool _applying = false;
  bool _undoing = false;
  TextChange? _expected;
  bool _disposed = false;

  /// Texts the window held before it was moved or rebuilt. The text box keeps the text it
  /// was last built with until the next frame, and Flutter's vertical caret keys (Up,
  /// Down, PageUp, PageDown) write that text back with a new selection. Such a write is
  /// the old window, not an edit of the new one, and is undone. The texts are compared by
  /// identity: an edit makes a new string, while the text box hands back the very string
  /// it was given.
  final List<String> _retired = [];

  /// Where the window begins in the document, and where it ends.
  int get start => _start;

  int get end => _start + _viewText.length;

  /// Number of the first line of the window, counting from 0.
  int get startLine => _startLine;

  /// Number of lines in the whole document.
  int get lineCount => _lineCount;

  /// Number of lines in the window.
  int get viewLineCount =>
      TextScan.lineFeeds(_viewText, 0, _viewText.length) + 1;

  /// The longest line of the document, or one as long as the longest has been.
  String get longestLine => _longestLine;

  /// Bumps whenever the window is rebuilt around somewhere else, so the editor knows the
  /// visible text is no longer where it was.
  int get generation => _generation;

  bool get canUndo => history.canUndo;

  /// True while the master selection reaches outside the window.
  bool get selectionClamped =>
      _masterSelection.isValid &&
      (_outside(_masterSelection.baseOffset) ||
          _outside(_masterSelection.extentOffset));

  bool _outside(int offset) => offset < _start || offset > end;

  /// True when the caret is in a part of the document the window does not hold, for
  /// example after the view was scrolled away from it. The text box then shows its caret
  /// at the edge of the window, which is not where the caret really is.
  bool get caretOutside =>
      _masterSelection.isValid && _outside(_masterSelection.extentOffset);

  // ---- Positions ----

  /// The line (counting from 0) that contains [offset].
  int lineIndexAt(int offset) {
    final text = _masterText;
    final target = offset < 0
        ? 0
        : (offset > text.length ? text.length : offset);
    var bestOffset = 0;
    var bestLine = 0;
    void consider(int at, int line) {
      if ((target - at).abs() < (target - bestOffset).abs()) {
        bestOffset = at;
        bestLine = line;
      }
    }

    consider(_start, _startLine);
    consider(end, _startLine + viewLineCount - 1);
    consider(text.length, _lineCount - 1);
    if (bestOffset <= target) {
      return bestLine + TextScan.lineFeeds(text, bestOffset, target);
    }
    return bestLine - TextScan.lineFeeds(text, target, bestOffset);
  }

  /// Offset where line [line] (counting from 0) starts. A line past the end resolves to the
  /// last line.
  int offsetOfLine(int line) {
    final text = _masterText;
    final target = line < 0 ? 0 : (line >= _lineCount ? _lineCount - 1 : line);
    var offset = 0;
    var current = 0;
    void consider(int at, int atLine) {
      if ((target - atLine).abs() < (target - current).abs()) {
        offset = at;
        current = atLine;
      }
    }

    consider(_start, _startLine);
    consider(TextScan.lineStart(text, end), _startLine + viewLineCount - 1);
    consider(TextScan.lineStart(text, text.length), _lineCount - 1);
    while (current < target) {
      final feed = text.indexOf('\n', offset);
      if (feed < 0) break;
      offset = feed + 1;
      current++;
    }
    while (current > target && offset > 0) {
      offset = TextScan.lineStart(text, offset - 1);
      current--;
    }
    return offset;
  }

  /// Line and column, counting from 1, of the caret at [offset].
  CaretPosition caretAt(int offset) {
    final text = _masterText;
    final at = offset < 0 ? 0 : (offset > text.length ? text.length : offset);
    return CaretPosition(
      lineIndexAt(at) + 1,
      at - TextScan.lineStart(text, at) + 1,
    );
  }

  // ---- Moving the window ----

  /// Rebuilds the window around [offset]. The text on screen is no longer where it was, so
  /// the editor has to scroll.
  void teleportTo(int offset) {
    _load(offset);
    _generation++;
    _notify();
  }

  /// True when the window can show the line holding [offset] without being rebuilt: the
  /// offset lies inside it and is not close to either edge that has more text beyond.
  bool covers(int offset) {
    final text = _masterText;
    final nearStart = _start > 0 && offset < _start + triggerCharacters;
    final nearEnd = end < text.length && offset > end - triggerCharacters;
    return offset >= _start && offset <= end && !nearStart && !nearEnd;
  }

  /// Moves the window to [newStart, newEnd), widened to whole lines. The caller has to
  /// keep the new window overlapping the old one, or it would use [teleportTo].
  WindowShift moveWindow(int newStart, int newEnd) {
    final text = _masterText;
    final from = TextScan.lineStart(text, math.max(0, newStart));
    final to = TextScan.lineEnd(text, math.min(text.length, newEnd));
    final oldStart = _start;
    final oldEnd = end;
    if (from == oldStart && to == oldEnd) {
      return const WindowShift(
        removedBefore: '',
        addedBefore: '',
        removedAfter: '',
        addedAfter: '',
      );
    }
    final shift = WindowShift(
      removedBefore: from > oldStart
          ? text.substring(oldStart, math.min(from, oldEnd))
          : '',
      addedBefore: from < oldStart
          ? text.substring(from, math.min(oldStart, to))
          : '',
      removedAfter: to < oldEnd
          ? text.substring(math.max(to, oldStart), oldEnd)
          : '',
      addedAfter: to > oldEnd ? text.substring(math.max(oldEnd, from), to) : '',
    );
    if (from > oldStart) {
      _startLine += TextScan.lineFeeds(text, oldStart, from);
    } else if (from < oldStart) {
      _startLine -= TextScan.lineFeeds(text, from, oldStart);
    }
    _start = from;
    _viewText = text.substring(from, to);
    _setView(_viewText, _masterSelection);
    _notify();
    return shift;
  }

  /// Builds the window around [around]. Line numbers are counted from the nearest place
  /// whose number is known, which is the old window unless [forgetWindow] says the text
  /// changed under it.
  void _load(int around, {bool forgetWindow = false}) {
    if (forgetWindow) {
      _start = 0;
      _startLine = 0;
      _viewText = '';
    }
    final text = _masterText;
    final at = around < 0 ? 0 : (around > text.length ? text.length : around);
    final from = TextScan.lineStartBefore(text, at, marginCharacters);
    final to = TextScan.lineEndAfter(text, at, marginCharacters);
    final line = from == 0 ? 0 : lineIndexAt(from);
    _startLine = line;
    _start = from;
    _viewText = text.substring(from, to);
    _setView(_viewText, _masterSelection);
  }

  void _setView(String text, TextSelection masterSelection) {
    if (_disposed) return;
    _retire(view.value.text, replacedBy: text);
    _applying = true;
    try {
      _viewSelection = _project(masterSelection);
      view.value = TextEditingValue(text: text, selection: _viewSelection);
    } finally {
      _applying = false;
    }
  }

  /// Remembers [text], which the text box may still be holding, unless it is not worth
  /// guarding: the window text that stays, or one too short to tell from an empty box.
  void _retire(String text, {required String replacedBy}) {
    if (identical(text, replacedBy) || text.length < 16) return;
    if (_retired.any((old) => identical(old, text))) return;
    _retired.add(text);
    if (_retired.length > _retiredLimit) _retired.removeAt(0);
  }

  bool _isRetired(String text) => _retired.any((old) => identical(old, text));

  /// Far more than the window can change between two frames.
  static const _retiredLimit = 24;

  TextSelection _project(TextSelection selection) {
    if (!selection.isValid) return const TextSelection.collapsed(offset: 0);
    final length = _viewText.length;
    int clamp(int offset) => math.max(0, math.min(length, offset - _start));
    return TextSelection(
      baseOffset: clamp(selection.baseOffset),
      extentOffset: clamp(selection.extentOffset),
      affinity: selection.affinity,
    );
  }

  // ---- The window changed: write it into the document ----

  void _onViewChanged() {
    if (_applying || _disposed) return;
    final value = view.value;
    if (value.text != _viewText) {
      if (_isRetired(value.text)) {
        // The old window, written back by a key before the box was built again.
        _setView(_viewText, _masterSelection);
        return;
      }
      _syncText(value);
    } else {
      _syncSelection(value.selection);
    }
  }

  void _syncText(TextEditingValue value) {
    final oldView = _viewText;
    final newView = value.text;
    final oldMaster = _masterText;

    var removeStart = 0;
    var removeEnd = 0;
    var inserted = '';
    var overSelection = false;

    final projected = _viewSelection;
    if (selectionClamped && projected.isValid) {
      // Typing over a selection that reaches outside the window replaces all of it, not
      // just the part the window can show. When the whole selection lies outside, the
      // text box has typed at the edge of the window, and the user meant the caret.
      final typed = _typedOver(
        oldView,
        newView,
        projected.start,
        projected.end,
      );
      if (typed != null) {
        overSelection = true;
        removeStart = math.min(_masterSelection.start, _masterSelection.end);
        removeEnd = math.max(_masterSelection.start, _masterSelection.end);
        inserted = typed;
      }
    }
    if (!overSelection) {
      final change = _resolve(oldView, newView, value.selection);
      removeStart = _start + change.start;
      removeEnd = _start + change.oldEnd;
      inserted = newView.substring(change.start, change.newEnd);
    }

    final removed = oldMaster.substring(removeStart, removeEnd);
    final newMaster = oldMaster.replaceRange(removeStart, removeEnd, inserted);
    final caret = overSelection
        ? TextSelection.collapsed(offset: removeStart + inserted.length)
        : _toMaster(value.selection);

    if (!_undoing) {
      history.record(
        offset: removeStart,
        removed: removed,
        inserted: inserted,
        before: SelectionOffsets(
          _masterSelection.baseOffset,
          _masterSelection.extentOffset,
        ),
        after: SelectionOffsets(caret.baseOffset, caret.extentOffset),
      );
    }
    _lineCount +=
        TextScan.lineFeeds(inserted, 0, inserted.length) -
        TextScan.lineFeeds(removed, 0, removed.length);
    _masterText = newMaster;
    _masterSelection = caret;
    _applying = true;
    try {
      master.value = TextEditingValue(text: newMaster, selection: caret);
    } finally {
      _applying = false;
    }
    _trackLongest(inserted);
    // The document may have become short enough to be edited as a whole, which discards
    // this window while the change is still being written.
    if (_disposed) return;

    if (overSelection ||
        (newView.length > maxViewCharacters &&
            _rebuildShrinks(newMaster, caret.extentOffset, newView.length))) {
      _load(caret.extentOffset, forgetWindow: true);
      _generation++;
      _notify();
      return;
    }
    _viewText = newView;
    _viewSelection = value.selection;
  }

  /// The change from [oldView] to [newView]. Typing a letter next to the same letter can be
  /// read as an insertion on either side of it; the caret says which the user meant, and
  /// the undo list needs that to join the keys of one word.
  TextChange _resolve(String oldView, String newView, TextSelection caret) {
    final change = TextScan.diff(oldView, newView);
    if (!caret.isValid || !caret.isCollapsed) return change;
    final c = caret.extentOffset;
    final grew = newView.length - oldView.length;
    if (grew > 0 && change.removedLength == 0) {
      final from = c - grew;
      if (from >= 0 &&
          from != change.start &&
          _sameAround(oldView, newView, from, from, from + grew)) {
        return TextChange(start: from, oldEnd: from, newEnd: from + grew);
      }
    } else if (grew < 0 && change.insertedLength == 0) {
      final removedLength = -grew;
      if (c >= 0 &&
          c != change.start &&
          c + removedLength <= oldView.length &&
          _sameAround(oldView, newView, c, c + removedLength, c)) {
        return TextChange(start: c, oldEnd: c + removedLength, newEnd: c);
      }
    }
    return change;
  }

  /// True when [oldView] and [newView] agree before [prefix] and after [oldTail] and
  /// [newTail] respectively, which makes the span between them the only difference.
  bool _sameAround(
    String oldView,
    String newView,
    int prefix,
    int oldTail,
    int newTail,
  ) {
    if (oldView.length - oldTail != newView.length - newTail) return false;
    for (var i = 0; i < prefix; i++) {
      if (oldView.codeUnitAt(i) != newView.codeUnitAt(i)) return false;
    }
    final tail = oldView.length - oldTail;
    for (var i = 0; i < tail; i++) {
      if (oldView.codeUnitAt(oldTail + i) != newView.codeUnitAt(newTail + i)) {
        return false;
      }
    }
    return true;
  }

  /// What was typed over [from, to) of [oldView] to give [newView], or null when the change
  /// is anything else.
  String? _typedOver(String oldView, String newView, int from, int to) {
    final tail = oldView.length - to;
    if (newView.length < from + tail) return null;
    for (var i = 0; i < from; i++) {
      if (oldView.codeUnitAt(i) != newView.codeUnitAt(i)) return null;
    }
    for (var i = 0; i < tail; i++) {
      if (oldView.codeUnitAt(oldView.length - 1 - i) !=
          newView.codeUnitAt(newView.length - 1 - i)) {
        return null;
      }
    }
    return newView.substring(from, newView.length - tail);
  }

  void _syncSelection(TextSelection selection) {
    if (!selection.isValid || selection == _viewSelection) return;
    final next = _toMaster(selection);
    _viewSelection = selection;
    if (next == _masterSelection) return;
    _masterSelection = next;
    _applying = true;
    try {
      master.selection = next;
    } finally {
      _applying = false;
    }
    if (_outside(next.extentOffset)) {
      // The caret went to a part of the document that is not in the window.
      teleportTo(next.extentOffset);
    }
  }

  /// The document selection for a selection the user made in the window.
  TextSelection _toMaster(TextSelection selection) {
    if (!selection.isValid) return _masterSelection;
    final previous = _viewSelection;
    final old = _masterSelection;
    var base = _start + selection.baseOffset;
    var extent = _start + selection.extentOffset;
    if (old.isValid && previous.isValid && !previous.isCollapsed) {
      final baseOutside = _outside(old.baseOffset);
      if (!selection.isCollapsed &&
          baseOutside &&
          selection.baseOffset == previous.baseOffset) {
        // The selection is being extended from an end that is not in the window.
        base = old.baseOffset;
      } else if (selection.isCollapsed &&
          (baseOutside || _outside(old.extentOffset))) {
        // An arrow key collapsed a selection that reached outside the window. It goes to
        // the end of the selection that the key means.
        final low = math.min(old.baseOffset, old.extentOffset);
        final high = math.max(old.baseOffset, old.extentOffset);
        if (selection.baseOffset == 0 && low < _start) {
          base = extent = low;
        } else if (selection.baseOffset == _viewText.length && high > end) {
          base = extent = high;
        }
      }
    }
    return TextSelection(
      baseOffset: base,
      extentOffset: extent,
      affinity: selection.affinity,
    );
  }

  // ---- The document changed: write it into the window ----

  void _onMasterChanged() {
    if (_applying || _disposed) return;
    final value = master.value;
    if (!identical(value.text, _masterText)) {
      _applyExternal(value);
      return;
    }
    if (value.selection == _masterSelection) return;
    _masterSelection = value.selection;
    _setView(_viewText, _masterSelection);
  }

  void _applyExternal(TextEditingValue value) {
    final before = _masterText;
    final after = value.text;
    final change = _expected ?? TextScan.diff(before, after);
    _expected = null;
    final removed = before.substring(change.start, change.oldEnd);
    final inserted = after.substring(change.start, change.newEnd);
    if (!_undoing && !change.isEmpty) {
      history.record(
        offset: change.start,
        removed: removed,
        inserted: inserted,
        before: SelectionOffsets(
          _masterSelection.baseOffset,
          _masterSelection.extentOffset,
        ),
        after: SelectionOffsets(
          value.selection.baseOffset,
          value.selection.extentOffset,
        ),
      );
    }
    final feedsRemoved = TextScan.lineFeeds(removed, 0, removed.length);
    final feedsInserted = TextScan.lineFeeds(inserted, 0, inserted.length);
    _lineCount += feedsInserted - feedsRemoved;
    _masterText = after;
    _masterSelection = value.selection;

    final oldEnd = _start + _viewText.length;
    var rebuilt = false;
    final newViewLength = _viewText.length - removed.length + inserted.length;
    if (change.start >= _start &&
        change.oldEnd <= oldEnd &&
        (newViewLength <= maxViewCharacters ||
            !_rebuildShrinks(
              after,
              value.selection.isValid
                  ? value.selection.extentOffset
                  : change.start,
              newViewLength,
            ))) {
      _viewText = _viewText.replaceRange(
        change.start - _start,
        change.oldEnd - _start,
        inserted,
      );
    } else {
      // A change the window cannot show, such as Replace All, or an undo far away.
      rebuilt = true;
    }
    if (removed.length >= _longestLine.length ||
        inserted.length > _longestLine.length) {
      _longestLine = TextMetrics.longestLine(after);
    } else {
      _trackLongest(inserted);
    }
    if (rebuilt) {
      _load(
        value.selection.isValid ? value.selection.extentOffset : change.start,
        forgetWindow: true,
      );
      _generation++;
    } else {
      _setView(_viewText, _masterSelection);
    }
    _notify();
  }

  /// True when a window rebuilt around [around] would be smaller than one of
  /// [currentLength] characters. The window holds whole lines, so when the lines around
  /// the caret are longer than the limit it cannot be made smaller, and rebuilding it
  /// would only move the text on screen with every key.
  bool _rebuildShrinks(String text, int around, int currentLength) {
    final at = around < 0 ? 0 : (around > text.length ? text.length : around);
    final from = TextScan.lineStartBefore(text, at, marginCharacters);
    final to = TextScan.lineEndAfter(text, at, marginCharacters);
    return to - from < currentLength;
  }

  void _trackLongest(String inserted) {
    final candidate = TextMetrics.longestLine(inserted);
    if (candidate.length > _longestLine.length) {
      _longestLine = candidate;
      return;
    }
    if (inserted.length < _longestLine.length) {
      // A line the user is typing in may have grown past the longest without the inserted
      // text itself being long, so look at the line holding the caret as well.
      final caret = _masterSelection.isValid
          ? _masterSelection.extentOffset
          : 0;
      final text = _masterText;
      final from = TextScan.lineStart(text, caret);
      final to = TextScan.lineEnd(text, caret);
      if (to - from > _longestLine.length) {
        _longestLine = text.substring(from, to);
      }
    }
  }

  // ---- Undo ----

  /// Undoes the newest change. The caret ends up where it was before that change. Returns
  /// false when there is nothing to undo.
  bool undo() {
    final entry = history.takeUndo();
    if (entry == null) return false;
    final current = _masterText;
    if (!current.startsWith(entry.inserted, entry.offset)) {
      // The text was changed behind the history's back, so it no longer fits.
      history.clear();
      return false;
    }
    final restored = current.replaceRange(
      entry.offset,
      entry.offset + entry.inserted.length,
      entry.removed,
    );
    _undoing = true;
    _expected = TextChange(
      start: entry.offset,
      oldEnd: entry.offset + entry.inserted.length,
      newEnd: entry.offset + entry.removed.length,
    );
    try {
      master.value = TextEditingValue(
        text: restored,
        selection: TextSelection(
          baseOffset: entry.before.base,
          extentOffset: entry.before.extent,
        ),
      );
    } finally {
      _undoing = false;
      _expected = null;
    }
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Stops following the document at once. The notifiers go a moment later, because this
  /// can be called from inside a notification of [view]: typing over a selection of the
  /// whole window leaves the document short enough to be edited as a whole, which is
  /// decided while the window's own change is still being delivered.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    master.removeListener(_onMasterChanged);
    view.removeListener(_onViewChanged);
    scheduleMicrotask(() {
      view.dispose();
      super.dispose();
    });
  }
}
