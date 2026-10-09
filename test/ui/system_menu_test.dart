import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/core/xp_menu.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

/// The window menu of the title bar. The minimize, maximize and close buttons are drawn
/// in the title bar and cannot be reached with Tab, so, as in XP, Alt+Space opens a menu
/// that holds the same commands.
void main() {
  late FakeWindowService window;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': ''} : null,
        );
  });

  Future<NotepadViewModel> pump(WidgetTester tester) async {
    window = FakeWindowService();
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
          window: window,
        ),
        settings: const NotepadSettings(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> altSpace(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space, character: ' ');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Finder item(String label) => find.text(label);

  testWidgets('Alt+Space opens the window menu with its commands', (
    tester,
  ) async {
    final vm = await pump(tester);

    await altSpace(tester);

    expect(vm.openMenu, kSystemMenu);
    expect(find.byType(XpMenuPopup), findsOneWidget);
    for (final label in [
      'Restore',
      'Move',
      'Size',
      'Minimize',
      'Maximize',
      'Close',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    expect(find.text('Alt+F4'), findsOneWidget);
  });

  testWidgets('the underlined letter picks a command: n minimizes', (
    tester,
  ) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await press(tester, LogicalKeyboardKey.keyN);

    expect(window.minimizes, 1);
    expect(vm.openMenu, isNull);
  });

  testWidgets('x maximizes and c asks to close', (tester) async {
    final vm = await pump(tester);

    await altSpace(tester);
    await press(tester, LogicalKeyboardKey.keyX);
    expect(window.maximizeToggles, 1);

    await altSpace(tester);
    await press(tester, LogicalKeyboardKey.keyC);
    await tester.pump();
    await tester.pump();
    expect(window.closed, isTrue);
    expect(vm.openMenu, isNull);
  });

  testWidgets('Restore is available only when the window is maximized', (
    tester,
  ) async {
    final vm = await pump(tester);
    vm.onMaximizedChanged(true);
    await tester.pump();

    await altSpace(tester);
    await press(tester, LogicalKeyboardKey.keyR);
    expect(window.maximizeToggles, 1);

    // Not maximized: Restore does nothing and the menu stays open.
    vm.onMaximizedChanged(false);
    await tester.pump();
    await altSpace(tester);
    await press(tester, LogicalKeyboardKey.keyR);
    expect(window.maximizeToggles, 1);
    expect(vm.openMenu, kSystemMenu);
  });

  testWidgets(
    'the first command that can be chosen is the one lit, and Enter picks it',
    (tester) async {
      final vm = await pump(tester);
      await altSpace(tester);

      // Restore, Move and Size are not available, so Minimize is first.
      await press(tester, LogicalKeyboardKey.enter);

      expect(window.minimizes, 1);
      expect(vm.openMenu, isNull);
    },
  );

  testWidgets('Down moves to the next command that can be chosen', (
    tester,
  ) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await press(tester, LogicalKeyboardKey.arrowDown); // Maximize
    await press(tester, LogicalKeyboardKey.enter);

    expect(window.maximizeToggles, 1);
    expect(window.minimizes, 0);
    expect(vm.openMenu, isNull);
  });

  testWidgets('Up from the first command goes round to Close', (tester) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(window.closed, isTrue);
    expect(vm.openMenu, isNull);
  });

  testWidgets('Escape closes it, and the key goes back to the text', (
    tester,
  ) async {
    final vm = await pump(tester);
    await altSpace(tester);
    expect(vm.openMenu, kSystemMenu);

    await press(tester, LogicalKeyboardKey.escape);

    expect(vm.openMenu, isNull);
    expect(find.byType(XpMenuPopup), findsNothing);
  });

  testWidgets('Right goes to the File menu and Left to the last one', (
    tester,
  ) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(vm.openMenu, 0);

    await altSpace(
      tester,
    ); // closes File? Alt+Space opens the window menu again.
    expect(vm.openMenu, kSystemMenu);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(vm.openMenu, 4);
  });

  testWidgets('Alt+Space again closes it', (tester) async {
    final vm = await pump(tester);
    await altSpace(tester);
    expect(vm.openMenu, kSystemMenu);

    await altSpace(tester);

    expect(vm.openMenu, isNull);
  });

  testWidgets('a click on the title bar icon opens it, and again closes it', (
    tester,
  ) async {
    final vm = await pump(tester);
    await tester.tapAt(const Offset(14, 15));
    await tester.pump();
    expect(vm.openMenu, kSystemMenu);

    await tester.tapAt(const Offset(14, 15));
    await tester.pump();
    expect(vm.openMenu, isNull);
  });

  testWidgets('a right click on the title bar opens it', (tester) async {
    final vm = await pump(tester);

    final gesture = await tester.startGesture(
      const Offset(300, 15),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pump();

    expect(vm.openMenu, kSystemMenu);
  });

  testWidgets('a click elsewhere closes it', (tester) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(vm.openMenu, isNull);
  });

  testWidgets('a click on a command runs it', (tester) async {
    final vm = await pump(tester);
    await altSpace(tester);

    await tester.tap(item('Minimize').first);
    await tester.pump();

    expect(window.minimizes, 1);
    expect(vm.openMenu, isNull);
  });

  testWidgets('Alt+Space does nothing while a dialog is open', (tester) async {
    final vm = await pump(tester);
    vm.showAbout();
    await tester.pump();
    await tester.pump();

    await altSpace(tester);

    expect(vm.openMenu, isNull);
  });
}
