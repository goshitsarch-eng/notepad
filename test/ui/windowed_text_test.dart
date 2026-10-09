import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/edit_history.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/domain/text/text_scan.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';

String _line(int i) =>
    'line ${i.toString().padLeft(5, '0')} ${'abcdefghij' * (i % 4)}';

String _document(int lines) => List.generate(lines, _line).join('\n');

int _offsetOfLine(String text, int line) =>
    TextMetrics.lineStart(text, line + 1);

WindowedText _open(
  String text, {
  int caret = 0,
  TextSelection? selection,
  DateTime Function()? clock,
}) {
  final master = TextEditingController(text: text)
    ..selection = selection ?? TextSelection.collapsed(offset: caret);
  addTearDown(master.dispose);
  final windowed = WindowedText(
    master: master,
    marginCharacters: 300,
    triggerCharacters: 100,
    maxViewCharacters: 3000,
    history: EditHistory(clock: clock ?? DateTime.now),
  );
  addTearDown(windowed.dispose);
  return windowed;
}

/// What the editor does when the user types: it replaces the value of the window.
void _userSets(WindowedText w, String text, int caret) {
  w.view.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret),
  );
}

void _expectConsistent(WindowedText w) {
  final text = w.master.text;
  expect(w.view.text, text.substring(w.start, w.end), reason: 'window text');
  expect(
    w.start == 0 || text[w.start - 1] == '\n',
    isTrue,
    reason: 'starts a line',
  );
  expect(
    w.end == text.length || text[w.end] == '\n',
    isTrue,
    reason: 'ends a line',
  );
  expect(w.lineCount, TextScan.lineFeeds(text, 0, text.length) + 1);
  expect(w.startLine, TextScan.lineFeeds(text, 0, w.start));
}

void main() {
  group('opening', () {
    test('shows whole lines around the caret and not the rest', () {
      final text = _document(5000);
      final caret = _offsetOfLine(text, 2500);
      final w = _open(text, caret: caret);
      _expectConsistent(w);
      expect(w.view.text.length, lessThan(1500));
      expect(w.start, lessThanOrEqualTo(caret));
      expect(w.end, greaterThanOrEqualTo(caret));
      expect(w.startLine, greaterThan(2000));
      expect(w.lineCount, 5000);
    });

    test('a caret at the top gives a window that starts the document', () {
      final w = _open(_document(5000));
      _expectConsistent(w);
      expect(w.start, 0);
      expect(w.startLine, 0);
    });

    test('a short document is wholly in the window', () {
      final text = _document(5);
      final w = _open(text);
      expect(w.view.text, text);
      expect(w.start, 0);
      expect(w.end, text.length);
    });

    test('an empty document opens', () {
      final w = _open('');
      expect(w.view.text, '');
      expect(w.lineCount, 1);
      expect(w.canUndo, isFalse);
    });

    test('the selection of the document appears in the window', () {
      final text = _document(5000);
      final caret = _offsetOfLine(text, 100) + 4;
      final w = _open(text, caret: caret);
      expect(w.view.selection.baseOffset, caret - w.start);
      expect(w.view.selection.isCollapsed, isTrue);
    });
  });

  group('typing in the window', () {
    test('goes into the document at the right place', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000) + 3;
      final w = _open(text, caret: caret);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'XYZ'), at + 3);
      expect(w.master.text, text.replaceRange(caret, caret, 'XYZ'));
      expect(w.master.selection, TextSelection.collapsed(offset: caret + 3));
      _expectConsistent(w);
    });

    test('a new line changes the line count and the line numbers', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, '\n'), at + 1);
      expect(w.lineCount, 3001);
      expect(w.caretAt(w.master.selection.extentOffset).line, 1002);
      _expectConsistent(w);
    });

    test('deleting text and joining lines keeps the counts right', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      final at = caret - w.start;
      // Remove the line feed before line 1000, joining it to line 999.
      _userSets(w, w.view.text.replaceRange(at - 1, at, ''), at - 1);
      expect(w.lineCount, 2999);
      _expectConsistent(w);
      expect(w.master.text.contains(_line(999) + _line(1000)), isTrue);
    });

    test('a long run of typing never breaks the window or its numbers', () {
      var text = _document(2000);
      final caret = _offsetOfLine(text, 700) + 5;
      final w = _open(text, caret: caret);
      var at = caret - w.start;
      for (var i = 0; i < 400; i++) {
        final ch = i % 37 == 0 ? '\n' : 'q';
        _userSets(w, w.view.text.replaceRange(at, at, ch), at + 1);
        text = text.replaceRange(w.start + at, w.start + at, ch);
        at++;
      }
      expect(w.master.text, text);
      _expectConsistent(w);
    });

    test('the status bar position follows', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1500) + 7;
      final w = _open(text, caret: caret);
      final position = w.caretAt(caret);
      expect(position.line, 1501);
      expect(position.column, 8);
      final expected = TextMetrics.caretAt(text, caret);
      expect(position.line, expected.line);
      expect(position.column, expected.column);
    });
  });

  group('selecting', () {
    test('a selection made in the window is a selection of the document', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      w.view.selection = const TextSelection(baseOffset: 10, extentOffset: 40);
      expect(
        w.master.selection,
        TextSelection(baseOffset: w.start + 10, extentOffset: w.start + 40),
      );
    });

    test('select all in the document shows as the whole window selected', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      w.master.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      expect(w.view.selection.start, 0);
      expect(w.view.selection.end, w.view.text.length);
      expect(w.selectionClamped, isTrue);
      // The document's own selection is untouched.
      expect(w.master.selection.start, 0);
      expect(w.master.selection.end, text.length);
    });

    test('typing over a select all replaces the whole document', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      w.master.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      _userSets(w, 'x', 1);
      expect(w.master.text, 'x');
      expect(w.view.text, 'x');
      expect(w.lineCount, 1);
      _expectConsistent(w);
      // One undo brings the whole document back.
      expect(w.undo(), isTrue);
      expect(w.master.text, text);
      _expectConsistent(w);
    });

    test('extending a selection whose other end left the window keeps it', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final base = 5;
      // The selection starts at the top of the document and ends in the window.
      w.master.selection = TextSelection(
        baseOffset: base,
        extentOffset: w.start + 100,
      );
      // The user shift-clicks further down: only the extent changes in the window.
      w.view.selection = TextSelection(
        baseOffset: w.view.selection.baseOffset,
        extentOffset: 200,
      );
      expect(w.master.selection.baseOffset, base);
      expect(w.master.selection.extentOffset, w.start + 200);
    });

    test(
      'an arrow key that collapses a select all goes to the document edge',
      () {
        final text = _document(3000);
        final w = _open(text, caret: _offsetOfLine(text, 1000));
        w.master.selection = TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        );
        final generation = w.generation;
        // Left collapses to the start of the selection, which the window shows as its
        // own start.
        w.view.selection = const TextSelection.collapsed(offset: 0);
        expect(w.master.selection, const TextSelection.collapsed(offset: 0));
        expect(w.start, 0);
        expect(w.generation, greaterThan(generation));
        _expectConsistent(w);
      },
    );

    test('a click inside the window just moves the caret', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      w.view.selection = const TextSelection.collapsed(offset: 77);
      expect(w.master.selection, TextSelection.collapsed(offset: w.start + 77));
    });
  });

  group('a caret that has been scrolled away from', () {
    test('is reported when it lies outside the window', () {
      final text = _document(6000);
      final w = _open(text, caret: _offsetOfLine(text, 100));
      expect(w.caretOutside, isFalse);
      w.teleportTo(_offsetOfLine(text, 4000));
      expect(w.caretOutside, isTrue);
      w.teleportTo(_offsetOfLine(text, 100));
      expect(w.caretOutside, isFalse);
    });

    test('text typed at the edge of the window goes to the caret instead', () {
      final text = _document(6000);
      final caret = _offsetOfLine(text, 100) + 3;
      final w = _open(text, caret: caret);
      w.teleportTo(_offsetOfLine(text, 4000));
      expect(w.caretOutside, isTrue);
      // The text box shows the caret at the window's edge, and types there.
      final edge = w.view.selection.baseOffset;
      _userSets(w, w.view.text.replaceRange(edge, edge, 'Q'), edge + 1);
      expect(w.master.text, text.replaceRange(caret, caret, 'Q'));
      expect(w.master.selection, TextSelection.collapsed(offset: caret + 1));
      expect(w.caretOutside, isFalse);
      _expectConsistent(w);
    });

    test('a selection that is typed over from far away is replaced whole', () {
      final text = _document(6000);
      final from = _offsetOfLine(text, 200);
      final to = _offsetOfLine(text, 230);
      final w = _open(
        text,
        selection: TextSelection(baseOffset: from, extentOffset: to),
      );
      w.teleportTo(_offsetOfLine(text, 4000));
      final edge = w.view.selection.baseOffset;
      _userSets(w, w.view.text.replaceRange(edge, edge, 'Q'), edge + 1);
      expect(w.master.text, text.replaceRange(from, to, 'Q'));
      _expectConsistent(w);
    });

    test(
      'typing over a selection that began above the window counts lines',
      () {
        // Lines of irregular length, so that a wrong line count cannot come out right by
        // luck.
        final text = List.generate(
          6000,
          (i) => 'l$i ${'k' * ((i * 7919) % 53)}',
        ).join('\n');
        final from = _offsetOfLine(text, 2000);
        final w = _open(text, caret: _offsetOfLine(text, 3000));
        // The selection runs from well above the window into it.
        final extent = w.start + 300;
        w.master.selection = TextSelection(
          baseOffset: from,
          extentOffset: extent,
        );
        // The text box types over the part of the selection it holds.
        _userSets(w, 'X${w.view.text.substring(300)}', 1);
        final expected = text.replaceRange(from, extent, 'X');
        expect(w.master.text, expected);
        _expectConsistent(w);
        expect(w.caretAt(w.master.selection.extentOffset).line, 2001);
        expect(w.start, lessThanOrEqualTo(from));
      },
    );
  });

  group('changes made by the rest of the app', () {
    test('an edit inside the window is patched into it', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000) + 2;
      final w = _open(text, caret: caret);
      final start = w.start;
      final generation = w.generation;
      w.master.value = TextEditingValue(
        text: text.replaceRange(caret, caret + 3, 'pasted\nbit'),
        selection: TextSelection.collapsed(offset: caret + 10),
      );
      expect(w.start, start);
      expect(w.generation, generation);
      expect(w.lineCount, 3001);
      _expectConsistent(w);
      expect(
        w.view.selection,
        TextSelection.collapsed(offset: caret + 10 - start),
      );
    });

    test('a change the window cannot show rebuilds it around the caret', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final generation = w.generation;
      final replaced = text.replaceAll('line', 'LINE');
      w.master.value = TextEditingValue(
        text: replaced,
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(w.generation, greaterThan(generation));
      expect(w.start, 0);
      expect(w.view.text.startsWith('LINE 00000'), isTrue);
      _expectConsistent(w);
    });

    test('a new document is taken over whole', () {
      final w = _open(_document(3000));
      final other = _document(4000).replaceAll('line', 'text');
      w.master.value = TextEditingValue(
        text: other,
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(w.lineCount, 4000);
      _expectConsistent(w);
    });

    test('a huge paste is not put into the window', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      final big = ('paste line\n' * 5000);
      w.master.value = TextEditingValue(
        text: text.replaceRange(caret, caret, big),
        selection: TextSelection.collapsed(offset: caret + big.length),
      );
      expect(w.view.text.length, lessThan(2000));
      expect(w.lineCount, 3000 + 5000);
      _expectConsistent(w);
      expect(w.master.selection.extentOffset, caret + big.length);
    });

    test('removing the line feed that ends the window rebuilds it', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final feed = w.end; // the line feed after the window
      w.master.value = TextEditingValue(
        text: text.replaceRange(feed, feed + 1, ''),
        selection: w.master.selection,
      );
      _expectConsistent(w);
    });

    test('selecting something far away leaves the window alone', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final start = w.start;
      w.master.selection = const TextSelection(baseOffset: 3, extentOffset: 20);
      expect(w.start, start);
      _expectConsistent(w);
      expect(w.covers(3), isFalse);
    });
  });

  group('moving the window', () {
    test('down: the lines that left and entered are reported', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final oldStart = w.start;
      final oldEnd = w.end;
      final shift = w.moveWindow(oldStart + 400, oldEnd + 400);
      _expectConsistent(w);
      expect(shift.removedBefore, text.substring(oldStart, w.start));
      expect(shift.removedBefore.endsWith('\n'), isTrue);
      expect(shift.addedAfter, text.substring(oldEnd, w.end));
      expect(shift.addedAfter.startsWith('\n'), isTrue);
      expect(shift.addedBefore, '');
      expect(shift.removedAfter, '');
    });

    test('up: the same in the other direction', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final oldStart = w.start;
      final oldEnd = w.end;
      final shift = w.moveWindow(oldStart - 400, oldEnd - 400);
      _expectConsistent(w);
      expect(shift.addedBefore, text.substring(w.start, oldStart));
      expect(shift.removedAfter, text.substring(w.end, oldEnd));
      expect(shift.removedBefore, '');
      expect(shift.addedAfter, '');
    });

    test('the window is widened to whole lines', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      w.moveWindow(w.start + 7, w.end + 7);
      _expectConsistent(w);
    });

    test('the line numbers stay right over many moves', () {
      final text = _document(6000);
      final w = _open(text, caret: _offsetOfLine(text, 3000));
      var step = 1;
      for (var i = 0; i < 40; i++) {
        final delta = 250 * step;
        w.moveWindow(
          (w.start + delta).clamp(0, text.length),
          (w.end + delta).clamp(0, text.length),
        );
        _expectConsistent(w);
        if (w.start == 0 || w.end == text.length) step = -step;
      }
    });

    test('moving to the same place changes nothing', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final shift = w.moveWindow(w.start, w.end);
      expect(shift.addedBefore + shift.removedBefore, '');
      expect(shift.addedAfter + shift.removedAfter, '');
    });

    test('the selection is projected into the new window', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000) + 2;
      final w = _open(text, caret: caret);
      w.moveWindow(w.start - 200, w.end);
      expect(
        w.view.selection,
        TextSelection.collapsed(offset: caret - w.start),
      );
    });

    test('typing after a move still lands at the caret', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000) + 2;
      final w = _open(text, caret: caret);
      w.moveWindow(w.start - 200, w.end + 200);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'Z'), at + 1);
      expect(w.master.text, text.replaceRange(caret, caret, 'Z'));
      _expectConsistent(w);
    });
  });

  group('rebuilding the window elsewhere', () {
    test('teleporting puts the window around the offset', () {
      final text = _document(6000);
      final w = _open(text);
      final target = _offsetOfLine(text, 4000);
      final generation = w.generation;
      w.teleportTo(target);
      expect(w.generation, greaterThan(generation));
      expect(w.start, lessThanOrEqualTo(target));
      expect(w.end, greaterThanOrEqualTo(target));
      expect(w.startLine, greaterThan(3500));
      _expectConsistent(w);
      expect(w.covers(target), isTrue);
    });

    test('covers is false near an edge that has more text beyond', () {
      final text = _document(6000);
      final w = _open(text, caret: _offsetOfLine(text, 3000));
      expect(w.covers(w.start + 10), isFalse);
      expect(w.covers(w.end - 10), isFalse);
      expect(w.covers((w.start + w.end) ~/ 2), isTrue);
      final top = _open(text);
      expect(top.covers(5), isTrue, reason: 'nothing lies above the top');
    });

    test('offsetOfLine and lineIndexAt agree with counting', () {
      final text = _document(6000);
      final w = _open(text, caret: _offsetOfLine(text, 3000));
      for (final line in [0, 1, 17, 1500, 2999, 3000, 3001, 4500, 5998, 5999]) {
        final offset = w.offsetOfLine(line);
        expect(offset, _offsetOfLine(text, line), reason: 'line $line');
        expect(w.lineIndexAt(offset), line);
        expect(w.lineIndexAt(offset + 3), line);
      }
      expect(w.offsetOfLine(99999), _offsetOfLine(text, 5999));
      expect(w.offsetOfLine(-3), 0);
      expect(w.lineIndexAt(text.length), 5999);
      expect(w.lineIndexAt(0), 0);
    });
  });

  group('undo', () {
    test('undoes typing in one step and puts the caret back', () {
      var now = DateTime(2026);
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000) + 3;
      final w = _open(text, caret: caret, clock: () => now);
      var at = caret - w.start;
      for (final ch in 'hello'.split('')) {
        now = now.add(const Duration(milliseconds: 80));
        _userSets(w, w.view.text.replaceRange(at, at, ch), at + 1);
        at++;
      }
      expect(w.master.text, text.replaceRange(caret, caret, 'hello'));
      expect(w.canUndo, isTrue);
      expect(w.undo(), isTrue);
      expect(w.master.text, text);
      expect(w.master.selection, TextSelection.collapsed(offset: caret));
      _expectConsistent(w);
      expect(w.canUndo, isFalse);
      expect(w.undo(), isFalse);
    });

    test('undo does not record itself', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'a'), at + 1);
      expect(w.undo(), isTrue);
      expect(w.canUndo, isFalse);
    });

    test('undoes a change made by the rest of the app', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      w.master.value = TextEditingValue(
        text: text.replaceRange(caret, caret, 'pasted'),
        selection: TextSelection.collapsed(offset: caret + 6),
      );
      expect(w.undo(), isTrue);
      expect(w.master.text, text);
      expect(w.master.selection, TextSelection.collapsed(offset: caret));
      _expectConsistent(w);
    });

    test('undoes a delete of text that the window did not hold', () {
      final text = _document(3000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      w.master.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(w.view.text, '');
      expect(w.undo(), isTrue);
      expect(w.master.text, text);
      _expectConsistent(w);
    });

    test('undo works after the window has moved', () {
      var now = DateTime(2026);
      final text = _document(6000);
      final caret = _offsetOfLine(text, 3000);
      final w = _open(text, caret: caret, clock: () => now);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'moved'), at + 5);
      w.teleportTo(_offsetOfLine(text, 100));
      now = now.add(const Duration(seconds: 5));
      expect(w.undo(), isTrue);
      expect(w.master.text, text);
      _expectConsistent(w);
    });

    test('undo refuses and forgets when the text no longer fits', () {
      final text = _document(3000);
      final caret = _offsetOfLine(text, 1000);
      final w = _open(text, caret: caret);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'abc'), at + 3);
      // Something outside the history rewrites the same spot.
      final changed = w.master.text.replaceRange(caret, caret + 3, 'XYZ');
      w.master.value = TextEditingValue(
        text: changed,
        selection: const TextSelection.collapsed(offset: 0),
      );
      w.history.clear();
      expect(w.undo(), isFalse);
    });
  });

  group('the longest line', () {
    test('is the longest of the document, and grows as lines are typed', () {
      final text = '${_document(2000)}\n${'w' * 500}';
      final w = _open(text, caret: _offsetOfLine(text, 10));
      expect(w.longestLine.length, 500);
      final caret = _offsetOfLine(text, 10);
      final at = caret - w.start;
      _userSets(w, w.view.text.replaceRange(at, at, 'k' * 700), at + 700);
      expect(w.longestLine.length, greaterThanOrEqualTo(700));
    });
  });

  group('disposal', () {
    test('stops following the document', () {
      final master = TextEditingController(text: _document(500));
      addTearDown(master.dispose);
      final w = WindowedText(master: master);
      w.dispose();
      expect(
        () => master.value = const TextEditingValue(text: 'x'),
        returnsNormally,
      );
    });
  });

  group('a line longer than the window may be', () {
    // The window holds whole lines, so a line of 10,000 characters makes a window bigger
    // than the 3,000 this one is allowed. Rebuilding it around the caret cannot make it
    // smaller, and would only move the text on screen with every key.
    String huge() => '${_document(40)}\n${'x' * 10000}\n${_document(40)}';

    test('does not rebuild the window on every key', () {
      final text = huge();
      final inside = _document(40).length + 1 + 5000;
      final w = _open(text, caret: inside);
      expect(w.end - w.start, greaterThan(3000));
      final generation = w.generation;

      var expected = text;
      var at = inside;
      for (var i = 0; i < 6; i++) {
        final view = w.view.text;
        final local = at - w.start;
        _userSets(w, view.replaceRange(local, local, 'Q'), local + 1);
        expected = expected.replaceRange(at, at, 'Q');
        at++;
      }

      expect(w.master.text == expected, isTrue);
      expect(w.generation, generation, reason: 'nothing moved under the user');
      _expectConsistent(w);
    });

    test('still rebuilds when the window can get smaller', () {
      final text = _document(2000);
      final w = _open(text, caret: _offsetOfLine(text, 1000));
      final generation = w.generation;
      // A paste that makes the window bigger than it may be.
      final view = w.view.text;
      final pasted = _document(300);
      final at = view.length ~/ 2;
      _userSets(w, view.replaceRange(at, at, pasted), at + pasted.length);
      expect(w.generation, greaterThan(generation));
      expect(w.end - w.start, lessThanOrEqualTo(3000));
      _expectConsistent(w);
    });
  });

  group('disposal inside a notification', () {
    test(
      'a window can be thrown away while its own text box is announcing',
      () async {
        final text = _document(12);
        final w = _open(text);
        expect(w.end, text.length, reason: 'the window is the whole document');
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previous);
        // What the view model once did when a typed letter left the document short.
        w.master.addListener(() {
          if (w.master.text.length < 10) w.dispose();
        });

        _userSets(w, 'x', 1);
        await Future<void>.delayed(Duration.zero);
        w.teleportTo(0);
        w.moveWindow(0, 5);
        await Future<void>.delayed(Duration.zero);

        expect(errors.map((e) => e.exceptionAsString()), isEmpty);
        expect(w.master.text, 'x');
      },
    );
  });

  group('the text box handing back a window that has been replaced', () {
    // Flutter's Up, Down, PageUp and PageDown write back the text the box was last built
    // with, with a new selection. After the window moved, that is the old window.
    test('after the window moved, the old text is not an edit', () {
      final text = _document(2000);
      final w = _open(text, caret: _offsetOfLine(text, 50));
      final old = w.view.value;
      w.moveWindow(w.start, w.end + 800);
      final moved = w.view.text;

      w.view.value = old.copyWith(
        selection: const TextSelection.collapsed(offset: 40),
      );

      expect(w.master.text == text, isTrue);
      expect(
        w.view.text,
        moved,
        reason: 'the box is given the real window again',
      );
      expect(w.view.selection.baseOffset, isNot(40));
      _expectConsistent(w);
    });

    test('after the window was rebuilt somewhere else', () {
      final text = _document(2000);
      final w = _open(text, caret: _offsetOfLine(text, 50));
      final old = w.view.value;
      w.teleportTo(_offsetOfLine(text, 1500));

      w.view.value = old.copyWith(
        selection: const TextSelection.collapsed(offset: 10),
      );

      expect(w.master.text == text, isTrue);
      _expectConsistent(w);
      expect(w.start, greaterThan(_offsetOfLine(text, 1000)));
    });

    test('after several moves before the box was built again', () {
      final text = _document(2000);
      final w = _open(text, caret: _offsetOfLine(text, 50));
      final built = w.view.value;
      for (var i = 0; i < 5; i++) {
        w.moveWindow(w.start, w.end + 400);
      }
      w.teleportTo(_offsetOfLine(text, 900));

      w.view.value = built.copyWith(
        selection: const TextSelection.collapsed(offset: 5),
      );

      expect(w.master.text == text, isTrue);
      _expectConsistent(w);
    });

    test('typing in the window that is current is still an edit', () {
      final text = _document(2000);
      final w = _open(text, caret: _offsetOfLine(text, 50));
      w.moveWindow(w.start, w.end + 800);
      final at = _offsetOfLine(text, 50) - w.start;

      _userSets(w, w.view.text.replaceRange(at, at, 'Q'), at + 1);

      expect(w.master.text, text.replaceRange(at + w.start, at + w.start, 'Q'));
      _expectConsistent(w);
    });

    test('a window text that is short is not guarded', () {
      final w = _open('abc\ndef');
      final before = w.view.value;
      w.teleportTo(0);
      _userSets(w, 'abc\ndefg', 8);
      expect(w.master.text, 'abc\ndefg');
      expect(before.text, 'abc\ndef');
    });
  });
}
