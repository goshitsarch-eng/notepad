import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

String _line(int i) =>
    'line ${i.toString().padLeft(6, '0')} ${'abcdefghij' * (i % 3)}';

String _document(int lines) => List.generate(lines, _line).join('\n');

int _offsetOfLine(String text, int line) =>
    TextMetrics.lineStart(text, line + 1);

/// A large document in the whole window: the keys, the status bar and the text box
/// working together.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? <String, Object?>{'text': ''}
              : null,
        );
  });

  Future<NotepadViewModel> pumpNotepad(
    WidgetTester tester,
    String text, {
    bool wordWrap = false,
  }) async {
    tester.view
      ..physicalSize = const Size(700, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final documents = FakeDocumentRepository()
      ..files['/big.txt'] = encodeText(text, FileEncoding.utf8);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: documents,
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: NotepadSettings(wordWrap: wordWrap),
        initialPath: '/big.txt',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
    ];
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a large document opens as a window of it', (tester) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text);
    expect(vm.windowed, isNotNull);
    expect(vm.text.text, text);
    final box = tester.widget<EditableText>(find.byType(EditableText));
    expect(box.controller.text.length, lessThan(40000));
  });

  testWidgets('Ctrl+End goes to the end of the whole document', (tester) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text);
    await tester.tapAt(const Offset(300, 200));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.end, control: true);
    expect(vm.text.selection, TextSelection.collapsed(offset: text.length));
    expect(vm.caret.line, 30000);
    expect(vm.windowed!.end, text.length);
    // The last line is on screen.
    expect(
      find.text('Ln 30000, Col ${_line(29999).length + 1}'),
      findsOneWidget,
    );
  });

  testWidgets('Ctrl+Home goes back to the start, and Shift extends', (
    tester,
  ) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text);
    await tester.tapAt(const Offset(300, 200));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.end, control: true);
    await press(tester, LogicalKeyboardKey.home, control: true, shift: true);
    expect(
      vm.text.selection,
      TextSelection(baseOffset: text.length, extentOffset: 0),
    );
    await press(tester, LogicalKeyboardKey.home, control: true);
    expect(vm.text.selection, const TextSelection.collapsed(offset: 0));
    expect(vm.windowed!.start, 0);
    expect(find.text('Ln 1, Col 1'), findsOneWidget);
  });

  testWidgets('a small document keeps the keys for the text box', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester, _document(50));
    expect(vm.windowed, isNull);
    final reveal = vm.revealSerial.value;
    await tester.tapAt(const Offset(300, 200));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.end, control: true);
    expect(
      vm.revealSerial.value,
      reveal,
      reason: 'the text box moved the caret itself',
    );
  });

  testWidgets('typing and Ctrl+Z work in a large document', (tester) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text);
    final caret = _offsetOfLine(text, 3) + 2;
    vm.text.selection = TextSelection.collapsed(offset: caret);
    await tester.pump();
    await tester.showKeyboard(find.byType(EditableText));
    final view = vm.windowed!.view.value;
    final at = view.selection.baseOffset;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: view.text.replaceRange(at, at, 'hello'),
        selection: TextSelection.collapsed(offset: at + 5),
      ),
    );
    await tester.pump();
    expect(vm.text.text, text.replaceRange(caret, caret, 'hello'));
    expect(vm.isModified, isTrue);
    await press(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(vm.text.text, text);
  });

  testWidgets('the status bar counts lines in the whole document', (
    tester,
  ) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text);
    expect(find.text('Ln 1, Col 1'), findsOneWidget);
    vm.goToLine(12345);
    await tester.pump();
    await tester.pump();
    expect(find.text('Ln 12345, Col 1'), findsOneWidget);
  });

  testWidgets(
    'a paste that makes the document large switches the editor over',
    (tester) async {
      final vm = await pumpNotepad(tester, _document(20));
      expect(vm.windowed, isNull);
      await tester.tapAt(const Offset(300, 200));
      await tester.pump();
      final plain = tester.widget<EditableText>(find.byType(EditableText));
      expect(plain.controller, same(vm.text));

      // Something large lands in the document, as a paste does.
      final big = _document(30000);
      vm.text.value = TextEditingValue(
        text: big,
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pump();
      await tester.pump();

      expect(vm.windowed, isNotNull);
      final windowed = tester.widget<EditableText>(find.byType(EditableText));
      expect(windowed.controller, same(vm.windowed!.view));
      expect(windowed.controller.text.length, lessThan(40000));

      // The keyboard still works after the switch.
      await tester.showKeyboard(find.byType(EditableText));
      final view = vm.windowed!.view.value;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: view.text.replaceRange(0, 0, 'A'),
          selection: const TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(vm.text.text, 'A$big');
    },
  );

  testWidgets('a document that shrinks goes back to a plain editor', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester, _document(30000));
    expect(vm.windowed, isNotNull);
    vm.selectAll();
    vm.deleteSelection();
    await tester.pump();
    await tester.pump();

    expect(vm.windowed, isNull);
    final box = tester.widget<EditableText>(find.byType(EditableText));
    expect(box.controller, same(vm.text));
    expect(tester.takeException(), isNull);
  });

  testWidgets('word wrap can be switched while a large document is open', (
    tester,
  ) async {
    final text = _document(30000);
    final vm = await pumpNotepad(tester, text, wordWrap: true);
    vm.goToLine(20000);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    vm.toggleWordWrap();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(vm.windowed, isNotNull);
    expect(vm.text.text, text);
    vm.toggleWordWrap();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(vm.windowed!.view.text.length, lessThan(80000));
  });
}
