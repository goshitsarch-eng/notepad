import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

import '../support/fakes.dart';
import '../support/fonts.dart';

const _sample = 'Dark mode test.\nSecond line of text.';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadLiberationFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? <String, Object?>{'text': ''}
              : null,
        );
  });

  tearDown(() => XpColors.dark = false);

  Future<NotepadViewModel> pumpNotepad(WidgetTester tester) async {
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
        settings: const NotepadSettings(),
      ),
    );
    await tester.pump();
    final vm = Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
    vm.text.value = const TextEditingValue(text: _sample);
    await tester.pump();
    return vm;
  }

  testWidgets('View > Dark Mode switches the palette on and off', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    expect(vm.darkMode, isFalse);

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.tap(find.text('Dark Mode'));
    await tester.pump();
    expect(vm.darkMode, isTrue);
    expect(XpColors.dark, isTrue);

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.tap(find.text('Dark Mode'));
    await tester.pump();
    expect(vm.darkMode, isFalse);
    expect(XpColors.dark, isFalse);
  });

  testWidgets('Help > Help Topics lists the shortcuts and closes with OK', (
    tester,
  ) async {
    final vm = await pumpNotepad(tester);
    await tester.tap(find.text('Help'));
    await tester.pump();
    await tester.tap(find.text('Help Topics'));
    await tester.pump();

    expect(vm.modal, isA<HelpRequest>());
    expect(find.text('Ctrl+N'), findsOneWidget);
    expect(find.text('Find next'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(vm.modal, isNull);
  });

  testWidgets('dark mode main window', (tester) async {
    final vm = await pumpNotepad(tester);
    vm.toggleDarkMode();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dark_main_window.png'),
    );
  });

  testWidgets('dark mode File menu and Help dialog', (tester) async {
    final vm = await pumpNotepad(tester);
    vm.toggleDarkMode();
    vm.openMenuAt(0, byClick: true);
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/dark_menu_file.png'),
    );
    vm.closeMenu();
    vm.showHelp();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(NotepadScreen),
      matchesGoldenFile('goldens/help_dialog.png'),
    );
  });
}
