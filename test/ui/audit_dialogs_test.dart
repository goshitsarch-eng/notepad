import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/core/xp_frame.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/dialogs/file_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/find_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/go_to_dialog.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

import '../support/fakes.dart';

/// Dialog behaviour found wanting in the second audit. Each test names its finding.
void main() {
  late FakeFileSystemService fileSystem;
  late FakeSettingsRepository settingsRepository;

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
    NotepadSettings settings = const NotepadSettings(),
    Size size = const Size(600, 404),
  }) async {
    fileSystem = FakeFileSystemService();
    settingsRepository = FakeSettingsRepository();
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: FakeDocumentRepository(),
          settings: settingsRepository,
          fileSystem: fileSystem,
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: settings,
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

  /// Text boxes inside [dialog]. The editor behind a dialog is an EditableText too, so a
  /// box has to be looked for inside the dialog that owns it.
  Finder boxIn(Type dialog) => find.descendant(
    of: find.byType(dialog),
    matching: find.byType(EditableText),
  );

  EditableText fieldIn(WidgetTester tester, Type dialog) =>
      tester.widget<EditableText>(boxIn(dialog).first);

  Finder nameBox() => boxIn(FileDialog).first;

  /// Submits the box that has focus, as Enter does.
  Future<void> pressEnter(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await frames(tester);
  }

  /// A dialog's own box: its frame, which spans the title bar and the body.
  Rect frameOf(WidgetTester tester, Type dialog) => tester.getRect(
    find.descendant(
      of: find.byType(dialog),
      matching: find.byType(XpWindowFrame),
    ),
  );

  group('Open and Save As', () {
    testWidgets(
      'F-08: a folder path typed into Save As opens the folder, it does not save a file',
      (tester) async {
        final vm = await pump(tester);
        fileSystem.directories.add('/home/tester/docs');
        final saving = vm.saveAs();
        await frames(tester);
        final request = vm.modal! as FileRequest;
        var answered = false;
        unawaited(request.result.then((_) => answered = true));

        await tester.enterText(nameBox(), '/home/tester/docs');
        await pressEnter(tester);

        expect(answered, isFalse, reason: 'the dialog must stay open');
        expect(fileSystem.listed.last, '/home/tester/docs');
        // The name that was typed is cleared, so it is not read as a file name next.
        expect(tester.widget<EditableText>(nameBox()).controller.text, isEmpty);

        request.complete(null);
        await saving;
      },
    );

    testWidgets('F-08: a name that is not a folder is still a file name', (
      tester,
    ) async {
      final vm = await pump(tester);
      final saving = vm.saveAs();
      await frames(tester);
      final request = vm.modal! as FileRequest;
      FileChoice? chosen;
      unawaited(request.result.then((choice) => chosen = choice));

      await tester.enterText(nameBox(), 'notes');
      await pressEnter(tester);

      expect(chosen!.path, '/home/tester/notes.txt');
      await saving;
    });

    testWidgets(
      'a file name typed after entering a typed folder is saved in that folder',
      (tester) async {
        final vm = await pump(tester);
        fileSystem.directories.add('/home/tester/docs');
        final saving = vm.saveAs();
        await frames(tester);
        final request = vm.modal! as FileRequest;
        FileChoice? chosen;
        unawaited(request.result.then((choice) => chosen = choice));

        await tester.enterText(nameBox(), '/home/tester/docs');
        await pressEnter(tester);
        await tester.enterText(nameBox(), 'a');
        await pressEnter(tester);

        expect(chosen!.path, '/home/tester/docs/a.txt');
        expect(chosen!.encoding, FileEncoding.ansi);
        await saving;
      },
    );

    testWidgets(
      'entering a folder from the list keeps the file name that was typed',
      (tester) async {
        final vm = await pump(tester);
        fileSystem.listings['/home/tester'] = [
          DirectoryEntry(
            name: 'docs',
            path: '/home/tester/docs',
            isDirectory: true,
            size: 0,
            modified: DateTime(2026, 10, 9),
          ),
        ];
        final saving = vm.saveAs();
        await frames(tester);
        await tester.enterText(nameBox(), 'report');

        await tester.tap(find.text('docs'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('docs'));
        await frames(tester);

        expect(fileSystem.listed.last, '/home/tester/docs');
        expect(
          tester.widget<EditableText>(nameBox()).controller.text,
          'report',
          reason: 'XP keeps what you typed while you move between folders',
        );
        (vm.modal! as FileRequest).complete(null);
        await saving;
      },
    );

    testWidgets(
      'F-11: a folder that cannot be listed says why instead of looking empty',
      (tester) async {
        final vm = await pump(tester);
        fileSystem.unreadable['/home/tester'] = 'Permission denied';
        unawaited(vm.openDocument());
        await frames(tester);

        expect(
          find.textContaining('This folder cannot be opened'),
          findsOneWidget,
        );
        expect(find.textContaining('Permission denied'), findsOneWidget);

        vm.modal!.complete(null);
        await frames(tester);
      },
    );

    testWidgets(
      'F-11: a start folder that has been deleted falls back to the nearest one that exists',
      (tester) async {
        final vm = await pump(
          tester,
          settings: const NotepadSettings(
            lastDirectory: '/home/tester/gone/deeper',
          ),
        );
        fileSystem.missingDirectories.addAll([
          '/home/tester/gone/deeper',
          '/home/tester/gone',
        ]);
        unawaited(vm.openDocument());
        await frames(tester);

        expect(fileSystem.listed, [
          '/home/tester/gone/deeper',
          '/home/tester/gone',
          '/home/tester',
        ]);
        expect(find.textContaining('cannot be opened'), findsNothing);

        vm.modal!.complete(null);
        await frames(tester);
      },
    );

    testWidgets('a combo box with no options draws instead of crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: XpComboBox<String>(
            options: const [],
            value: '',
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // Tapping it opens nothing and does not throw either.
      await tester.tap(find.byType(XpComboBox<String>));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Go To', () {
    Future<NotepadViewModel> withLines(WidgetTester tester) async {
      final vm = await pump(
        tester,
        settings: const NotepadSettings(wordWrap: false),
      );
      vm.text.value = const TextEditingValue(text: 'one\ntwo\nthree');
      vm.text.selection = const TextSelection.collapsed(offset: 0);
      await frames(tester, 1);
      return vm;
    }

    testWidgets('F-09: the line number is selected when the dialog opens', (
      tester,
    ) async {
      final vm = await withLines(tester);
      unawaited(vm.showGoTo());
      await frames(tester);

      final field = fieldIn(tester, GoToDialog);
      expect(field.controller.text, '1');
      expect(
        field.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );

      vm.modal!.complete(null);
    });

    testWidgets(
      'F-09: typing replaces the selected number instead of adding to it',
      (tester) async {
        final vm = await withLines(tester);
        unawaited(vm.showGoTo());
        await frames(tester);

        await tester.showKeyboard(boxIn(GoToDialog).first);
        tester.testTextInput.enterText('3');
        await tester.pump();
        await pressEnter(tester);

        expect(vm.caret.line, 3);
      },
    );

    testWidgets(
      'a number too long for an int goes to the last line instead of doing nothing',
      (tester) async {
        final vm = await withLines(tester);
        unawaited(vm.showGoTo());
        await frames(tester);

        await tester.enterText(
          boxIn(GoToDialog).first,
          '99999999999999999999999',
        );
        await pressEnter(tester);

        expect(vm.modal, isNull, reason: 'the dialog must accept it');
        expect(vm.caret.line, 3);
      },
    );

    testWidgets('an empty box keeps the dialog open', (tester) async {
      final vm = await withLines(tester);
      unawaited(vm.showGoTo());
      await frames(tester);

      await tester.enterText(boxIn(GoToDialog).first, '');
      await pressEnter(tester);

      expect(vm.modal, isA<GoToRequest>());
      vm.modal!.complete(null);
    });
  });

  group('Find and Replace', () {
    testWidgets('F-09: the last search text is selected when Find opens', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.text.value = const TextEditingValue(text: 'the fox jumps');
      vm.findNext(const SearchOptions(query: 'fox'));
      vm.showFind(replace: false);
      await frames(tester);

      final field = fieldIn(tester, FindDialog);
      expect(field.controller.text, 'fox');
      expect(
        field.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
    });

    testWidgets(
      'F-17: Replace searches down even after an earlier Find went up',
      (tester) async {
        final vm = await pump(tester);
        vm.text.value = const TextEditingValue(text: 'a b a b a');
        vm.text.selection = const TextSelection.collapsed(offset: 9);
        vm.findNext(const SearchOptions(query: 'b', forward: false));
        expect(vm.lastSearch.forward, isFalse);

        vm.showFind(replace: true);
        await frames(tester);
        vm.text.selection = const TextSelection.collapsed(offset: 0);
        await tester.tap(find.text('Find Next'));
        await frames(tester);

        expect(vm.lastSearch.forward, isTrue);
        expect(
          vm.text.selection.start,
          2,
          reason: 'the first b after the start',
        );
      },
    );

    testWidgets('F-18: the arrow keys move between the Direction buttons', (
      tester,
    ) async {
      final vm = await pump(tester);
      vm.text.value = const TextEditingValue(text: 'x x x x x');
      vm.showFind(replace: false);
      await frames(tester);
      await tester.enterText(boxIn(FindDialog).first, 'x');

      // The caret is put back in the middle before each search, so both directions always
      // have a match and no "Cannot find" message gets in the way.
      Future<bool> searchGoesDown() async {
        vm.text.selection = const TextSelection.collapsed(offset: 4);
        await tester.tap(find.text('Find Next'));
        await frames(tester);
        expect(vm.modal, isNull);
        return vm.lastSearch.forward;
      }

      // Down is the default. A click focuses the Up button, then the keys move.
      await tester.tap(find.text('Up'));
      await frames(tester);
      expect(await searchGoesDown(), isFalse);

      await tester.tap(find.text('Up'));
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await frames(tester);
      expect(await searchGoesDown(), isTrue);

      await tester.tap(find.text('Down'));
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await frames(tester);
      expect(await searchGoesDown(), isFalse);

      // And the up and down arrows do the same.
      await tester.tap(find.text('Up'));
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await frames(tester);
      expect(await searchGoesDown(), isTrue);
      await tester.tap(find.text('Down'));
      await frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester);
      expect(await searchGoesDown(), isFalse);
    });
  });

  group('Page Setup', () {
    Future<NotepadViewModel> open(WidgetTester tester) async {
      final vm = await pump(tester);
      unawaited(vm.editPageSetup());
      await frames(tester);
      return vm;
    }

    Finder margin(String text) => find.byWidgetPredicate(
      (w) => w is EditableText && w.controller.text == text,
    );

    testWidgets('F-06: Enter in a margin box accepts the dialog', (
      tester,
    ) async {
      final vm = await open(tester);

      await tester.enterText(margin('0.75').first, '2');
      await pressEnter(tester);

      expect(vm.modal, isNull);
      expect(settingsRepository.saved!.pageSetup.leftInches, 2);
    });

    testWidgets('F-06: Enter in the header box accepts the dialog too', (
      tester,
    ) async {
      final vm = await open(tester);

      await tester.enterText(margin('&f'), 'My notes');
      await pressEnter(tester);

      expect(vm.modal, isNull);
      expect(settingsRepository.saved!.pageSetup.header, 'My notes');
    });

    testWidgets(
      'F-06: Enter with a bad margin keeps the dialog open and says why',
      (tester) async {
        final vm = await open(tester);

        await tester.enterText(margin('1.0').first, '6');
        await tester.enterText(margin('1.0').last, '6');
        await pressEnter(tester);

        expect(vm.modal, isA<PageSetupRequest>());
        expect(
          find.text('The top and bottom margins leave no room to print.'),
          findsOneWidget,
        );
        vm.modal!.complete(null);
      },
    );
  });

  group('F-20: a dialog cannot be dragged out of reach', () {
    Future<NotepadViewModel> open(WidgetTester tester) async {
      final vm = await pump(
        tester,
        settings: const NotepadSettings(wordWrap: false),
      );
      unawaited(vm.showGoTo());
      await frames(tester);
      return vm;
    }

    testWidgets(
      'dragged far beyond the right and bottom edges, the title bar stays inside',
      (tester) async {
        final vm = await open(tester);
        final start = tester.getCenter(find.text('Go To Line').first);

        await tester.dragFrom(start, const Offset(5000, 5000));
        await frames(tester);

        final dialog = frameOf(tester, GoToDialog);
        expect(
          dialog.left,
          lessThanOrEqualTo(600 - 48),
          reason: 'a grip stays on screen sideways',
        );
        expect(
          dialog.top,
          lessThanOrEqualTo(404 - XpMetrics.dialogTitleHeight),
        );
        expect(dialog.top, greaterThan(100), reason: 'it did move down');
        vm.modal!.complete(null);
      },
    );

    testWidgets(
      'dragged beyond the left and top edges, the title bar stays inside',
      (tester) async {
        final vm = await open(tester);
        final start = tester.getCenter(find.text('Go To Line').first);

        await tester.dragFrom(start, const Offset(-5000, -5000));
        await frames(tester);

        final dialog = frameOf(tester, GoToDialog);
        expect(dialog.top, greaterThanOrEqualTo(0));
        expect(dialog.right, greaterThanOrEqualTo(48));
        expect(dialog.left, lessThan(0), reason: 'it did move left');
        vm.modal!.complete(null);
      },
    );

    testWidgets(
      'the dialog follows the pointer back at once, with no dead zone',
      (tester) async {
        final vm = await open(tester);
        final start = tester.getCenter(find.text('Go To Line').first);

        // Far past the edge, then a short drag back. It must move on the first pixels back.
        final gesture = await tester.startGesture(start);
        await gesture.moveBy(const Offset(5000, 0));
        await frames(tester, 1);
        final pinned = frameOf(tester, GoToDialog).left;
        await gesture.moveBy(const Offset(-40, 0));
        await frames(tester, 1);
        final backed = frameOf(tester, GoToDialog).left;
        await gesture.up();

        expect(pinned, 600 - 48, reason: 'stopped at the edge');
        expect(backed, pinned - 40);
        vm.modal!.complete(null);
      },
    );

    testWidgets(
      'a dialog taller than the window is held to the window, title bar at the top edge',
      (tester) async {
        // Open wants about 380 px, and the smallest window is 310.
        final vm = await pump(
          tester,
          size: Size(kMinimumWindowSize.width, kMinimumWindowSize.height),
        );
        unawaited(vm.openDocument());
        await frames(tester);

        final frame = frameOf(tester, FileDialog);
        expect(frame.top, 0);
        expect(frame.height, kMinimumWindowSize.height);
        vm.modal!.complete(null);
        await tester.pump();
        // The fixed-size dialog overflows a window this small. That is not under test here.
        tester.takeException();
      },
    );

    testWidgets(
      'a dialog that fits starts centred, exactly where it did before',
      (tester) async {
        final vm = await open(tester);

        final dialog = frameOf(tester, GoToDialog);
        expect(dialog.center.dx, 300);
        expect(dialog.center.dy, 202);
        vm.modal!.complete(null);
      },
    );
  });
}
