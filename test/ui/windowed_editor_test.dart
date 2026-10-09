import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';
import 'package:xp_notepad/ui/notepad/editor/xp_editor.dart';

String _line(int i) =>
    'line ${i.toString().padLeft(6, '0')} ${'abcdefghij' * (i % 3)}';

String _document(int lines) => List.generate(lines, _line).join('\n');

int _offsetOfLine(String text, int line) =>
    TextMetrics.lineStart(text, line + 1);

class _Rig {
  _Rig(this.master, this.windowed, this.reveal, this.focus, this.undo);

  final NotepadTextController master;
  final WindowedText windowed;
  final ValueNotifier<int> reveal;
  final FocusNode focus;
  final UndoHistoryController undo;
}

Future<_Rig> _pump(
  WidgetTester tester,
  String text, {
  int caret = 0,
  bool wordWrap = false,
  EditorFont font = const EditorFont(),
}) async {
  final master = NotepadTextController()
    ..value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  final windowed = WindowedText(master: master);
  final focus = FocusNode();
  final reveal = ValueNotifier<int>(0);
  final undo = UndoHistoryController();
  addTearDown(() {
    windowed.dispose();
    master.dispose();
    focus.dispose();
    reveal.dispose();
    undo.dispose();
  });
  tester.view
    ..physicalSize = const Size(700, 404)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFFFFFFFF),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, a, b) => builder(context),
      ),
      home: XpEditor(
        controller: master,
        focusNode: focus,
        undoHistory: undo,
        font: font,
        wordWrap: wordWrap,
        revealSerial: reveal,
        onTab: () {},
        windowed: windowed,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Rig(master, windowed, reveal, focus, undo);
}

/// The scroll view around the text box. The text box has a scroll view of its own inside.
final _verticalScrollable = find
    .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
    .first;

ScrollPosition _vertical(WidgetTester tester) {
  return tester.state<ScrollableState>(_verticalScrollable).position;
}

RenderEditable _render(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;

/// The line of the document at the top of the screen, found by asking the text box what is
/// at its top edge.
int _topLine(WidgetTester tester, _Rig rig) {
  final render = _render(tester);
  final scrollable = tester.getRect(_verticalScrollable);
  final inBox = render.getPositionForPoint(
    Offset(render.localToGlobal(Offset.zero).dx + 1, scrollable.top + 2),
  );
  return rig.windowed.lineIndexAt(rig.windowed.start + inBox.offset);
}

void main() {
  group('a large document in the editor', () {
    testWidgets('the text box holds a window and not the whole document', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      final box = tester.widget<EditableText>(find.byType(EditableText));
      expect(box.controller.text.length, lessThan(40000));
      expect(text.length, greaterThan(500000));
      expect(box.controller, same(rig.windowed.view));
      expect(rig.master.text, text);
    });

    testWidgets('the scroll extent stands for the whole document', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      // 30000 lines at 13 pixels a line, less the screen.
      expect(
        position.maxScrollExtent + position.viewportDimension,
        closeTo(30000 * 13 + 14, 40),
      );
      expect(rig.windowed.start, 0);
    });

    testWidgets('typing goes into the document', (tester) async {
      final text = _document(30000);
      final caret = _offsetOfLine(text, 4) + 3;
      final rig = await _pump(tester, text, caret: caret);
      await tester.showKeyboard(find.byType(EditableText));
      final view = rig.windowed.view.value;
      final at = view.selection.baseOffset;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: view.text.replaceRange(at, at, 'XYZ'),
          selection: TextSelection.collapsed(offset: at + 3),
        ),
      );
      await tester.pump();
      expect(rig.master.text, text.replaceRange(caret, caret, 'XYZ'));
      expect(rig.master.selection, TextSelection.collapsed(offset: caret + 3));
    });

    testWidgets('scrolling a long way keeps the lines where the bar says', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      var moved = 0;
      var lastEnd = rig.windowed.end;
      for (var step = 0; step < 90; step++) {
        position.jumpTo(position.pixels + 520);
        await tester.pump();
        await tester.pump();
        final top = _topLine(tester, rig);
        final expected = (position.pixels / 13).floor();
        expect(
          top,
          closeTo(expected, 1),
          reason: 'step $step at ${position.pixels}',
        );
        if (rig.windowed.end != lastEnd) moved++;
        lastEnd = rig.windowed.end;
      }
      expect(moved, greaterThan(3), reason: 'the window had to follow');
      expect(rig.windowed.view.text.length, lessThan(80000));
    });

    testWidgets('scrolling back up keeps the lines where the bar says', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text, caret: _offsetOfLine(text, 25000));
      final position = _vertical(tester);
      for (var step = 0; step < 90; step++) {
        position.jumpTo(position.pixels - 520);
        await tester.pump();
        await tester.pump();
        final expected = (position.pixels / 13).floor();
        expect(_topLine(tester, rig), closeTo(expected, 1), reason: '$step');
      }
    });

    testWidgets('dragging the bar far away rebuilds the window there', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      position.jumpTo(20000 * 13);
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.startLine, greaterThan(19000));
      expect(rig.windowed.startLine, lessThan(20100));
      expect(_topLine(tester, rig), closeTo(20000, 1));
    });

    testWidgets('the window is rebuilt before the frame that would be empty', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      // No frame is drawn between the jump and this check, so the window has to follow
      // the scroll position at once, or that frame would show empty room.
      position.jumpTo(20000 * 13);
      expect(rig.windowed.startLine, greaterThan(19000));
      expect(rig.windowed.startLine, lessThan(20100));
      await tester.pump();
      await tester.pump();
      expect(_topLine(tester, rig), closeTo(20000, 1));
    });

    testWidgets('a long scroll to the very end and back to the top', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.end, rig.master.text.length);
      position.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.start, 0);
      expect(_topLine(tester, rig), 0);
    });

    testWidgets('a search result far away is brought into view', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      final target = _offsetOfLine(text, 22000);
      rig.master.selection = TextSelection(
        baseOffset: target,
        extentOffset: target + 11,
      );
      rig.reveal.value++;
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.start, lessThanOrEqualTo(target));
      expect(rig.windowed.end, greaterThanOrEqualTo(target));
      final top = _topLine(tester, rig);
      expect(top, lessThanOrEqualTo(22000));
      expect(top, greaterThan(22000 - 40));
    });

    testWidgets('a result inside the window is brought into view too', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      final target = _offsetOfLine(text, 60);
      rig.master.selection = TextSelection.collapsed(offset: target);
      rig.reveal.value++;
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final top = _topLine(tester, rig);
      expect(top, lessThanOrEqualTo(60));
      expect(top, greaterThan(60 - 40));
    });

    testWidgets('select all then typing replaces the whole document', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      rig.master.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      await tester.pump();
      await tester.showKeyboard(find.byType(EditableText));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'q',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(rig.master.text, 'q');
    });

    testWidgets('works with word wrap on', (tester) async {
      final text = _document(30000);
      final rig = await _pump(
        tester,
        text,
        caret: _offsetOfLine(text, 15000),
        wordWrap: true,
      );
      expect(rig.windowed.view.text.length, lessThan(40000));
      final position = _vertical(tester);
      for (var step = 0; step < 40; step++) {
        position.jumpTo(position.pixels + 700);
        await tester.pump();
        await tester.pump();
      }
      expect(rig.windowed.view.text.length, lessThan(80000));
      await tester.showKeyboard(find.byType(EditableText));
      final view = rig.windowed.view.value;
      final at = rig.windowed.view.text.length ~/ 2;
      final caret = rig.windowed.start + at;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: view.text.replaceRange(at, at, 'W'),
          selection: TextSelection.collapsed(offset: at + 1),
        ),
      );
      await tester.pump();
      expect(rig.master.text, text.replaceRange(caret, caret, 'W'));
    });

    testWidgets('a small caret move leaves the window alone', (tester) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      final generation = rig.windowed.generation;
      final start = rig.windowed.start;
      for (var i = 0; i < 20; i++) {
        rig.master.selection = TextSelection.collapsed(offset: i * 7);
        await tester.pump();
      }
      expect(rig.windowed.generation, generation);
      expect(rig.windowed.start, start);
    });

    testWidgets('a teleport also brings the caret into view sideways', (
      tester,
    ) async {
      // Lines wider than the screen, so the text box can be scrolled along them.
      final text = List.generate(30000, (i) => '${'x' * 140} $i').join('\n');
      final rig = await _pump(tester, text);
      final sideways = tester.state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.horizontal,
            )
            .first,
      );
      sideways.position.jumpTo(sideways.position.maxScrollExtent);
      await tester.pump();
      expect(sideways.position.pixels, greaterThan(100));
      rig.master.selection = TextSelection.collapsed(
        offset: _offsetOfLine(text, 22000),
      );
      rig.reveal.value++;
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(sideways.position.pixels, 0);
    });

    testWidgets('changing the font rebuilds the window around the caret', (
      tester,
    ) async {
      final text = _document(30000);
      final caret = _offsetOfLine(text, 9000);
      final rig = await _pump(tester, text, caret: caret);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, a, b) => builder(context),
          ),
          home: XpEditor(
            controller: rig.master,
            focusNode: rig.focus,
            undoHistory: rig.undo,
            font: const EditorFont(sizePoints: 16),
            wordWrap: false,
            revealSerial: rig.reveal,
            onTab: () {},
            windowed: rig.windowed,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(rig.windowed.start, lessThanOrEqualTo(caret));
      expect(rig.windowed.end, greaterThanOrEqualTo(caret));
    });

    testWidgets('a pointer that is down keeps the window from moving', (
      tester,
    ) async {
      final rig = await _pump(tester, _document(30000));
      final position = _vertical(tester);
      final gesture = await tester.startGesture(const Offset(300, 200));
      final start = rig.windowed.start;
      final end = rig.windowed.end;
      position.jumpTo(position.pixels + 4200);
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.start, start);
      expect(rig.windowed.end, end);
      await gesture.up();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        rig.windowed.end,
        greaterThan(end),
        reason: 'it moves once the pointer is released',
      );
    });

    testWidgets(
      'a key brings the window back to a caret that was scrolled away from',
      (tester) async {
        final text = _document(30000);
        final caret = _offsetOfLine(text, 100);
        final rig = await _pump(tester, text, caret: caret);
        await tester.showKeyboard(find.byType(EditableText));
        final position = _vertical(tester);
        position.jumpTo(20000 * 13);
        await tester.pump();
        await tester.pump();
        expect(rig.windowed.caretOutside, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ, character: 'q');
        await tester.pump();
        await tester.pump();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
        expect(rig.windowed.caretOutside, isFalse);
        expect(rig.windowed.start, lessThanOrEqualTo(caret));
        expect(rig.windowed.end, greaterThanOrEqualTo(caret));
        expect(_topLine(tester, rig), closeTo(100, 40));
      },
    );

    testWidgets('a key that is only a modifier leaves the view where it is', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text, caret: _offsetOfLine(text, 100));
      await tester.showKeyboard(find.byType(EditableText));
      _vertical(tester).jumpTo(20000 * 13);
      await tester.pump();
      await tester.pump();
      final generation = rig.windowed.generation;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(rig.windowed.generation, generation);
      expect(rig.windowed.caretOutside, isTrue);
    });

    testWidgets('typing with the window at the end of the document', (
      tester,
    ) async {
      final text = _document(30000);
      final rig = await _pump(tester, text);
      final position = _vertical(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(rig.windowed.end, text.length);
      rig.master.selection = TextSelection.collapsed(offset: text.length);
      await tester.pump();
      await tester.showKeyboard(find.byType(EditableText));
      final view = rig.windowed.view.value;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '${view.text}!',
          selection: TextSelection.collapsed(offset: view.text.length + 1),
        ),
      );
      await tester.pump();
      expect(rig.master.text, '$text!');
    });
  });
}
