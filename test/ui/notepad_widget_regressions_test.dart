import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

import '../support/fakes.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return call.method == 'Clipboard.getData' ? {'text': ''} : null;
        });
  });

  /// Pumps the whole app at the default 600x404 size and returns its view model.
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
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> frames(WidgetTester tester, [int count = 2]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Presses a key chord, as a user would.
  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  Finder verticalBars() => find.byWidgetPredicate(
    (w) => w is XpScrollBar && w.axis == Axis.vertical,
  );

  group('editor', () {
    testWidgets('a click in the blank area below short text keeps focus', (
      tester,
    ) async {
      // Desktop rules: a tap outside the editable text drops focus.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final vm = await pumpNotepad(tester);
        vm.text.value = const TextEditingValue(text: 'short');
        await frames(tester);
        final editor = tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode;
        expect(editor.hasFocus, isTrue);

        final screen = tester.getRect(find.byType(NotepadScreen));
        await tester.tapAt(Offset(screen.center.dx, screen.top + 150));
        await frames(tester);

        expect(editor.hasFocus, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a vertical scroll bar appears only when the text overflows', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      vm.text.value = const TextEditingValue(text: 'one line');
      await frames(tester);
      expect(verticalBars(), findsNothing);

      vm.text.value = TextEditingValue(
        text: List.generate(80, (i) => 'Line $i').join('\n'),
      );
      await frames(tester, 3);
      expect(verticalBars(), findsOneWidget);
    });

    testWidgets('selected text is white while the editor has focus', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final controller = NotepadTextController()
        ..value = const TextEditingValue(
          text: 'abc',
          selection: TextSelection(baseOffset: 0, extentOffset: 2),
        );
      // EditableText passes withComposing = true whenever the editor has focus.
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );
      final highlighted = span.children![1] as TextSpan;
      expect(highlighted.text, 'ab');
      expect(highlighted.style?.color, XpColors.highlightText);
    });
  });

  group('dialogs', () {
    testWidgets('Find asked again while open moves focus to the Find box', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      vm.showFind(replace: false);
      await frames(tester);
      vm.showFind(replace: false);
      await frames(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'find what');
    });

    testWidgets('Ctrl+A in the Find box does not select the document', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      vm.text.value = const TextEditingValue(text: 'document text');
      await frames(tester);
      vm.showFind(replace: false);
      await frames(tester);

      await chord(tester, LogicalKeyboardKey.keyA, control: true);
      await frames(tester);

      expect(vm.text.selection.isCollapsed, isTrue);
      expect(vm.text.text, 'document text');
    });

    testWidgets('Escape cancels a dialog even when focus is on the dialog', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showAbout());
      await frames(tester);
      expect(vm.modal, isA<AboutRequest>());

      // Focus on the dialog itself, not on one of its fields.
      FocusManager.instance.primaryFocus?.unfocus();
      await frames(tester);
      await chord(tester, LogicalKeyboardKey.escape);
      await frames(tester);

      expect(vm.modal, isNull);
    });

    testWidgets(
      'a message box is drawn over the Find dialog and takes clicks',
      (tester) async {
        final vm = await pumpNotepad(tester);
        vm.text.value = const TextEditingValue(text: 'nothing here');
        vm.showFind(replace: false);
        await frames(tester);

        // No match, so the Cannot find message appears over the Find dialog.
        vm.findNext(const SearchOptions(query: 'missing'));
        await frames(tester, 3);
        expect(vm.modal, isA<MessageRequest>());

        await tester.tap(find.text('OK'));
        await frames(tester, 3);
        expect(vm.modal, isNull);
      },
    );

    testWidgets('Page Setup keeps the dialog open for a bad margin', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.editPageSetup());
      await frames(tester);

      // The top and bottom margins both start at 1.0. Six inches each leaves no room.
      final margins = find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == '1.0',
      );
      await tester.tap(margins.first);
      await tester.pump();
      await tester.enterText(margins.first, '6');
      await tester.enterText(margins.last, '6');
      await frames(tester);
      await tester.tap(find.text('OK'));
      await frames(tester, 3);

      expect(vm.modal, isA<PageSetupRequest>());
      expect(
        find.text('The top and bottom margins leave no room to print.'),
        findsOneWidget,
      );
    });

    testWidgets('a list box shows a scroll bar only when its rows overflow', (
      tester,
    ) async {
      Widget list(int count) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: XpListBox<int>(
            options: [for (var i = 0; i < count; i++) XpOption('Item $i', i)],
            value: 0,
            onChanged: (_) {},
            width: 200,
            height: 100,
          ),
        ),
      );

      await tester.pumpWidget(list(4));
      expect(verticalBars(), findsNothing);
      await tester.pumpWidget(list(40));
      expect(verticalBars(), findsOneWidget);
    });

    testWidgets(
      'an encoding list opens upward and does not throw near the edge',
      (tester) async {
        tester.view
          ..physicalSize = const Size(300, 200)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final options = [
          const XpOption('ANSI', 0),
          const XpOption('Unicode', 1),
          const XpOption('Unicode big endian', 2),
          const XpOption('UTF-8', 3),
        ];
        // WidgetsApp supplies the Overlay that the popup needs, as the real app does.
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFFFFFFFF),
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, animation, secondary) => builder(context),
            ),
            home: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: 200,
                child: XpComboBox<int>(
                  options: options,
                  value: 3,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('UTF-8'));
        await frames(tester, 3);

        // Every option is on screen, so none is clipped off the bottom.
        final screen = Offset.zero & tester.view.physicalSize;
        for (final option in options) {
          final rect = tester.getRect(find.text(option.label).last);
          expect(screen.contains(rect.topLeft), isTrue, reason: option.label);
          expect(
            screen.contains(rect.bottomRight),
            isTrue,
            reason: option.label,
          );
        }
      },
    );
  });
}
