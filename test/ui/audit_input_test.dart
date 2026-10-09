import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/config/app_info.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/core/xp_caption.dart';
import 'package:xp_notepad/ui/core/xp_menu.dart';
import 'package:xp_notepad/ui/notepad/editor/longest_line_meter.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/notepad/editor/xp_editor.dart';
import 'package:xp_notepad/ui/notepad/notepad_menus.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

import '../support/fakes.dart';

/// Keyboard, pointer and layout behaviour found wanting in the second audit.
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

  Future<NotepadViewModel> pump(
    WidgetTester tester, {
    Size size = const Size(600, 404),
  }) async {
    window = FakeWindowService();
    tester.view
      ..physicalSize = size
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

  Future<void> frames(WidgetTester tester, [int count = 3]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('Alt and the menu accelerators', () {
    testWidgets('Alt+F opens the File menu', (tester) async {
      final vm = await pump(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      expect(vm.openMenu, 0);
    });

    testWidgets(
      'a lost Alt key-up does not turn later letters into menu commands',
      (tester) async {
        final vm = await pump(tester);

        // Alt goes down, then the window loses the key-up, as when Alt+Tab leaves the app.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        HardwareKeyboard.instance.clearState();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pump();

        expect(vm.openMenu, isNull);
      },
    );

    testWidgets(
      'Ctrl+Alt+letter, which is AltGr on Windows, types instead of opening a menu',
      (tester) async {
        final vm = await pump(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(vm.openMenu, isNull);
      },
    );

    testWidgets(
      'Alt+F still works after a lost Alt key-up once Alt is pressed again',
      (tester) async {
        final vm = await pump(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        HardwareKeyboard.instance.clearState();
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();

        expect(vm.openMenu, 1);
      },
    );
  });

  group(
    'F-27: the caption maximizes only on a primary-button double click',
    () {
      // A point on the blank part of the caption, between the title and the buttons.
      const spot = Offset(330, 15);

      testWidgets('two quick left clicks toggle the window size', (
        tester,
      ) async {
        await pump(tester);

        await tester.tapAt(spot);
        await tester.tapAt(spot);
        await tester.pump();

        expect(window.maximizeToggles, 1);
      });

      testWidgets('two quick right clicks do nothing', (tester) async {
        await pump(tester);

        await tester.tapAt(spot, buttons: kSecondaryButton);
        await tester.tapAt(spot, buttons: kSecondaryButton);
        await tester.pump();

        expect(window.maximizeToggles, 0);
      });

      testWidgets(
        'a right click between two left clicks does not make a double click',
        (tester) async {
          await pump(tester);

          await tester.tapAt(spot);
          await tester.tapAt(spot, buttons: kSecondaryButton);
          await tester.pump();

          // The right click is ignored, so the first left click is still waiting for its pair.
          await tester.tapAt(spot);
          await tester.pump();
          expect(window.maximizeToggles, 1);
        },
      );

      testWidgets('the caption buttons still work', (tester) async {
        final vm = await pump(tester);

        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is XpCaptionButton && w.kind == XpCaptionButtonKind.maximize,
          ),
        );
        await tester.pump();

        expect(window.maximizeToggles, 1);
        expect(vm.modal, isNull);
      });
    },
  );

  group('F-07: every menu fits in the smallest window', () {
    NotepadViewModel viewModel() => NotepadViewModel(
      documents: FakeDocumentRepository(),
      settingsRepository: FakeSettingsRepository(),
      fileSystem: FakeFileSystemService(),
      printing: FakePrintingService(),
      window: FakeWindowService(),
      settings: const NotepadSettings(),
    );

    test('the tallest popup ends above the bottom frame at the minimum height', () {
      final vm = viewModel();
      addTearDown(vm.dispose);
      const popupTop = XpMetrics.captionHeight + XpMetrics.menuBarHeight;

      for (final menu in buildNotepadMenus(vm)) {
        final bottom = popupTop + XpMenuLayout.popupHeight(menu.items);
        expect(
          bottom + XpMetrics.frame,
          lessThanOrEqualTo(kMinimumWindowSize.height),
          reason:
              'the ${menu.label} menu would be cut off in the smallest window',
        );
      }
    });

    testWidgets(
      'the Edit menu shows its last item at the minimum window size',
      (tester) async {
        final vm = await pump(
          tester,
          size: Size(kMinimumWindowSize.width, kMinimumWindowSize.height),
        );

        vm.openMenuAt(1, byClick: true);
        await frames(tester);

        final popup = tester.getRect(find.byType(XpMenuPopup));
        final lastItem = tester.getRect(find.text('Time/Date'));
        expect(
          popup.bottom,
          lessThanOrEqualTo(kMinimumWindowSize.height - XpMetrics.frame),
        );
        expect(lastItem.bottom, lessThanOrEqualTo(popup.bottom));
        expect(tester.takeException(), isNull);
      },
    );

    test('the minimum size is enforced when a settings file asks for less', () {
      final settings = NotepadSettings.fromJson({
        'windowWidth': 300.0,
        'windowHeight': 200.0,
      });
      expect(settings.windowHeight, kMinimumWindowSize.height);
      expect(settings.windowWidth, kMinimumWindowSize.width);
    });
  });

  testWidgets('F-25: Help > About names the version', (tester) async {
    final vm = await pump(tester);

    unawaited(vm.showAbout());
    await frames(tester);

    expect(find.text('Version $appVersion'), findsOneWidget);
    vm.modal!.complete(true);
  });

  group(
    'the no-wrap editor measures its longest line only when the text changes',
    () {
      test('the meter keeps its answer for the same text and style', () {
        final meter = LongestLineMeter();
        const style = TextStyle(fontSize: 13);
        final text = 'short\nthe longest line of all\nmid';

        final first = meter.measure(text, style);
        final second = meter.measure(text, style);

        expect(first, greaterThan(0));
        expect(second, first);
        expect(meter.computations, 1);
      });

      test('a different text or style is measured again', () {
        final meter = LongestLineMeter();
        const style = TextStyle(fontSize: 13);
        meter.measure('abc', style);

        final wider = meter.measure('abcdefghijkl', style);
        meter.measure('abcdefghijkl', const TextStyle(fontSize: 20));

        expect(meter.computations, 3);
        expect(wider, greaterThan(0));
      });

      test('an empty text still has a width and does not fail', () {
        final meter = LongestLineMeter();
        expect(
          meter.measure('', const TextStyle(fontSize: 13)),
          greaterThan(0),
        );
      });

      testWidgets(
        'moving the caret through a large document does not measure it again',
        (tester) async {
          final meter = LongestLineMeter();
          final controller = NotepadTextController()
            ..text = List.generate(
              2000,
              (i) => 'line $i of the document',
            ).join('\n');
          final focus = FocusNode();
          final undo = UndoHistoryController();
          final reveal = ValueNotifier<int>(0);
          addTearDown(() {
            controller.dispose();
            focus.dispose();
            undo.dispose();
            reveal.dispose();
          });
          tester.view
            ..physicalSize = const Size(600, 404)
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
                controller: controller,
                focusNode: focus,
                undoHistory: undo,
                font: const EditorFont(),
                wordWrap: false,
                revealSerial: reveal,
                onTab: () {},
                meter: meter,
              ),
            ),
          );
          await tester.pump();
          final afterFirstBuild = meter.computations;
          expect(afterFirstBuild, 1);

          for (var i = 0; i < 25; i++) {
            controller.selection = TextSelection.collapsed(offset: i * 11);
            await tester.pump();
          }
          expect(
            meter.computations,
            afterFirstBuild,
            reason: 'only the caret moved',
          );

          controller.text = '${controller.text}\nand one more line';
          await tester.pump();
          expect(
            meter.computations,
            afterFirstBuild + 1,
            reason: 'the text changed',
          );
        },
      );
    },
  );
}
