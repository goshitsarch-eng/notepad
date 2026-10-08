import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/core/xp_caption.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

void main() {
  late FakeWindowService window;

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

  /// Pumps the app and returns its view model. The window fake is kept for close checks.
  Future<NotepadViewModel> pumpNotepad(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(600, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    window = FakeWindowService();
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: FakeDocumentRepository(),
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: window,
        ),
        settings: const NotepadSettings(),
      ),
    );
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  /// Presses [key] with the given modifiers held, as a user would.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool alt = false,
    bool shift = false,
  }) async {
    final modifiers = [
      if (control) LogicalKeyboardKey.controlLeft,
      if (alt) LogicalKeyboardKey.altLeft,
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
  }

  testWidgets('Ctrl+N on an untouched document asks nothing', (tester) async {
    final vm = await pumpNotepad(tester);
    await press(tester, LogicalKeyboardKey.keyN, control: true);
    expect(vm.modal, isNull);
  });

  testWidgets('Ctrl+N after typing asks to save, and No discards the text', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    await tester.enterText(find.byType(EditableText), 'draft');
    await tester.pump();
    expect(vm.isModified, isTrue);

    await press(tester, LogicalKeyboardKey.keyN, control: true);
    expect(vm.modal, isA<MessageRequest>());
    await tester.tap(find.text('No'));
    await tester.pump();

    expect(vm.text.text, isEmpty);
    expect(vm.modal, isNull);
  });

  testWidgets('Alt+F opens the File menu and Escape closes it', (tester) async {
    final vm = await pumpNotepad(tester);
    await press(tester, LogicalKeyboardKey.keyF, alt: true);
    expect(vm.openMenu, 0);
    expect(find.text('Open...'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(vm.openMenu, isNull);
  });

  testWidgets('clicking a menu label opens it and clicking an item runs it', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    await tester.enterText(find.byType(EditableText), 'to be cleared');
    await tester.pump();
    vm.text.value = const TextEditingValue(text: 'to be cleared');
    await tester.pump();

    await tester.tap(find.text('File'));
    await tester.pump();
    expect(vm.openMenu, 0);

    await tester.tap(find.text('Print...'));
    await tester.pump();
    expect(vm.openMenu, isNull);
  });

  testWidgets('Tab inserts a tab character instead of moving focus', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.tab);
    expect(vm.text.text, '\t');
  });

  testWidgets('F5 inserts the time and date', (tester) async {
    final vm = await pumpNotepad(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.f5);
    expect(
      vm.text.text,
      matches(RegExp(r'^\d{1,2}:\d{2} (AM|PM) \d{1,2}/\d{1,2}/\d{4}$')),
    );
  });

  testWidgets('Ctrl+F opens Find, and Find Next selects the match', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: 'alpha beta alpha');
    vm.text.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();

    await press(tester, LogicalKeyboardKey.keyF, control: true);
    expect(vm.find, isNotNull);
    expect(vm.find!.replace, isFalse);

    await tester.enterText(find.byType(EditableText).last, 'alpha');
    await tester.pump();
    await tester.tap(find.text('Find Next'));
    await tester.pump();

    expect(
      vm.text.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
  });

  testWidgets('F3 repeats the last search without opening Find', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: 'one two one');
    vm.text.selection = const TextSelection.collapsed(offset: 0);
    vm.findNext(const SearchOptions(query: 'one'));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.f3);
    expect(vm.find, isNull);
    expect(
      vm.text.selection,
      const TextSelection(baseOffset: 8, extentOffset: 11),
    );
  });

  testWidgets('Escape closes the Find dialog', (tester) async {
    final vm = await pumpNotepad(tester);
    await press(tester, LogicalKeyboardKey.keyF, control: true);
    expect(vm.find, isNotNull);
    await press(tester, LogicalKeyboardKey.escape);
    expect(vm.find, isNull);
  });

  testWidgets(
    'Format > Word Wrap turns wrapping off and shows the status bar',
    (tester) async {
      final vm = await pumpNotepad(tester);
      expect(find.textContaining('Ln 1'), findsNothing);

      await tester.tap(find.text('Format'));
      await tester.pump();
      await tester.tap(find.text('Word Wrap'));
      await tester.pump();

      expect(vm.wordWrap, isFalse);
      expect(find.textContaining('Ln 1, Col 1'), findsOneWidget);
    },
  );

  testWidgets('the caption close button closes an unmodified window', (
    tester,
  ) async {
    await pumpNotepad(tester);
    await tester.tap(find.byType(XpCaptionButton).last);
    await tester.pump();
    await tester.pump();
    expect(window.closed, isTrue);
  });
}
