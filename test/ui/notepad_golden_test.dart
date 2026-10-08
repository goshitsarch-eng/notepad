import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';
import '../support/fonts.dart';

const _sample =
    'Notepad is a simple text editor.\n\n'
    'This window is a Flutter recreation of Windows XP Notepad, with the\n'
    'Luna caption, menu bar, status bar and dialogs.\n\n'
    'Type here, or choose File > Open to load a text file.';

const _longLine =
    'This line is long on purpose, so that the horizontal scrollbar shows when '
    'word wrap is turned off in Notepad. It keeps going past the edge of the window.';

void main() {
  late bool fontsAvailable;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? <String, Object?>{'text': ''}
              : null,
        );
    fontsAvailable = await loadLiberationFonts();
  });

  Future<NotepadViewModel> pumpNotepad(
    WidgetTester tester, {
    NotepadSettings settings = const NotepadSettings(),
  }) async {
    tester.view
      ..physicalSize = const Size(600, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: FakeDocumentRepository(),
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: settings,
      ),
    );
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> frame(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 50));

  testWidgets('main window with word wrap on', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: _sample);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/main_word_wrap.png'),
    );
  });

  testWidgets('word wrap off shows the status bar and scrollbars', (
    tester,
  ) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: '$_sample\n$_longLine');
    vm.toggleWordWrap();
    vm.text.selection = const TextSelection.collapsed(offset: 20);
    // The scrollbars appear once the first layout reports the overflow, which takes a
    // second frame, as it does in the app.
    await frame(tester);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/no_word_wrap.png'),
    );
  });

  testWidgets('File menu open by mouse', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: _sample);
    vm.openMenuAt(0, byClick: true);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/menu_file.png'),
    );
  });

  testWidgets('Edit menu open with keyboard cues', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: _sample);
    vm.text.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
    vm.setMenuCue(true);
    vm.openMenuAt(1);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/menu_edit_cues.png'),
    );
  });

  testWidgets('Format and View menus', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.openMenuAt(3);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/menu_view.png'),
    );
  });

  testWidgets('Find dialog over the text', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: _sample);
    vm.showFind(replace: false);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_find.png'),
    );
  });

  testWidgets('Replace dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.showFind(replace: true);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_replace.png'),
    );
  });

  testWidgets('save changes message box', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.text.value = const TextEditingValue(text: _sample);
    vm.newDocument();
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_message.png'),
    );
  });

  testWidgets('Font dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.showFont();
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_font.png'),
    );
  });

  testWidgets('Open dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.openDocument();
    await frame(tester);
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_open.png'),
    );
  });

  testWidgets('Page Setup dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.editPageSetup();
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_page_setup.png'),
    );
  });

  testWidgets('Go To dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.showGoTo();
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_go_to.png'),
    );
  });

  testWidgets('About dialog', (tester) async {
    if (!fontsAvailable) {
      return markTestSkipped('Liberation fonts are not installed');
    }
    final vm = await pumpNotepad(tester);
    vm.showAbout();
    await frame(tester);
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dialog_about.png'),
    );
  });
}
