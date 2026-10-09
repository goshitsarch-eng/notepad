import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/edit_history.dart';
import 'package:xp_notepad/domain/text/text_scan.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';

/// Random edits through a window, checked against the same edits made to a plain string.
/// Whatever the window does, the document must be exactly what a plain editor would hold,
/// the window must be whole lines of it, and the line numbers must be right.
void main() {
  const words = ['alpha', 'be', 'g', 'delta\n', '\n', 'ε', ' ', '\t', 'x'];

  String makeDocument(math.Random random) {
    final lines = 1500 + random.nextInt(1500);
    return List.generate(lines, (i) {
      final width = random.nextInt(60);
      return random.nextInt(9) == 0 ? '' : 'l$i ${'k' * width}';
    }).join('\n');
  }

  void check(WindowedText w, String expected, String step) {
    final text = w.master.text;
    expect(text, expected, reason: 'document after $step');
    expect(w.view.text, text.substring(w.start, w.end), reason: 'window $step');
    expect(
      w.start == 0 || text[w.start - 1] == '\n',
      isTrue,
      reason: 'start of a line $step',
    );
    expect(
      w.end == text.length || text[w.end] == '\n',
      isTrue,
      reason: 'end of a line $step',
    );
    expect(
      w.lineCount,
      TextScan.lineFeeds(text, 0, text.length) + 1,
      reason: 'line count $step',
    );
    expect(
      w.startLine,
      TextScan.lineFeeds(text, 0, w.start),
      reason: 'first line $step',
    );
    final selection = w.master.selection;
    expect(selection.isValid, isTrue, reason: 'selection $step');
    expect(selection.start >= 0 && selection.end <= text.length, isTrue);
    final probe = (selection.extentOffset + 7) % (text.length + 1);
    expect(
      w.lineIndexAt(probe),
      TextScan.lineFeeds(text, 0, probe),
      reason: 'line at $probe $step',
    );
  }

  for (var seed = 1; seed <= 40; seed++) {
    test('random editing, seed $seed', () {
      final random = math.Random(seed);
      var expected = makeDocument(random);
      final masterController = TextEditingController(text: expected)
        ..selection = TextSelection.collapsed(
          offset: random.nextInt(expected.length),
        );
      var now = DateTime(2026);
      final w = WindowedText(
        master: masterController,
        marginCharacters: 250,
        triggerCharacters: 80,
        maxViewCharacters: 2500,
        history: EditHistory(clock: () => now),
      );
      addTearDown(() {
        w.dispose();
        masterController.dispose();
      });
      final snapshots = <String>[];
      check(w, expected, 'opening');

      for (var step = 0; step < 160; step++) {
        now = now.add(const Duration(seconds: 2));
        final before = expected;
        final op = random.nextInt(11);
        final master = w.master;
        var label = 'op $op at step $step';
        switch (op) {
          case 0:
            // A click in the window.
            final at = random.nextInt(w.view.text.length + 1);
            w.view.selection = TextSelection.collapsed(offset: at);
          case 1 || 2:
            // Typing at the caret, or over the selection, as the text box does. The editor
            // first brings the window back to a caret that has been scrolled away from.
            if (w.caretOutside) w.teleportTo(w.master.selection.extentOffset);
            final word = words[random.nextInt(words.length)];
            final view = w.view.value;
            final sel = view.selection;
            final low = sel.start;
            final high = sel.end;
            final range = master.selection;
            w.view.value = TextEditingValue(
              text: view.text.replaceRange(low, high, word),
              selection: TextSelection.collapsed(offset: low + word.length),
            );
            expected = expected.replaceRange(range.start, range.end, word);
            label += ' (typed over ${range.end - range.start} characters)';
          case 3:
            // Backspace.
            if (w.caretOutside) w.teleportTo(w.master.selection.extentOffset);
            final view = w.view.value;
            final sel = view.selection;
            final range = master.selection;
            if (!sel.isCollapsed) {
              w.view.value = TextEditingValue(
                text: view.text.replaceRange(sel.start, sel.end, ''),
                selection: TextSelection.collapsed(offset: sel.start),
              );
              expected = expected.replaceRange(range.start, range.end, '');
            } else if (sel.start > 0) {
              w.view.value = TextEditingValue(
                text: view.text.replaceRange(sel.start - 1, sel.start, ''),
                selection: TextSelection.collapsed(offset: sel.start - 1),
              );
              expected = expected.replaceRange(
                range.start - 1,
                range.start,
                '',
              );
            } else {
              continue;
            }
          case 4:
            // Selecting a stretch of the window.
            final view = w.view.text;
            if (view.length < 4) continue;
            final a = random.nextInt(view.length - 2);
            final b = a + 1 + random.nextInt(math.min(40, view.length - a - 1));
            w.view.selection = TextSelection(baseOffset: a, extentOffset: b);
          case 5:
            // A paste or other edit by the rest of the app, at the caret.
            final selection = master.selection;
            final word = 'PASTE${random.nextInt(99)}\nline';
            final start = selection.start;
            final end = selection.end;
            master.value = TextEditingValue(
              text: expected.replaceRange(start, end, word),
              selection: TextSelection.collapsed(offset: start + word.length),
            );
            expected = expected.replaceRange(start, end, word);
          case 6:
            // An edit by the rest of the app somewhere else in the document.
            final at = random.nextInt(expected.length + 1);
            final cut = math.min(random.nextInt(30), expected.length - at);
            master.value = TextEditingValue(
              text: expected.replaceRange(at, at + cut, 'E'),
              selection: TextSelection.collapsed(offset: at + 1),
            );
            expected = expected.replaceRange(at, at + cut, 'E');
          case 7:
            // The window moves along, as scrolling makes it.
            final delta = random.nextInt(900) - 450;
            w.moveWindow(
              (w.start + delta).clamp(0, expected.length),
              (w.end + delta).clamp(0, expected.length),
            );
          case 8:
            w.teleportTo(random.nextInt(expected.length + 1));
          case 9:
            // A selection made by the rest of the app, such as Find or select all.
            if (random.nextBool()) {
              master.selection = TextSelection(
                baseOffset: 0,
                extentOffset: expected.length,
              );
            } else {
              final a = random.nextInt(expected.length + 1);
              master.selection = TextSelection(
                baseOffset: a,
                extentOffset: math.min(expected.length, a + random.nextInt(50)),
              );
              // Find and Go To scroll to what they select.
              if (!w.covers(master.selection.extentOffset)) {
                w.teleportTo(master.selection.extentOffset);
              }
            }
          case 10:
            if (!w.canUndo || snapshots.isEmpty) continue;
            final restored = snapshots.removeLast();
            expect(w.undo(), isTrue, reason: 'undo at step $step');
            expected = restored;
            check(w, expected, label);
            continue;
        }
        if (expected != before) snapshots.add(before);
        check(w, expected, label);
      }
    });
  }
}
