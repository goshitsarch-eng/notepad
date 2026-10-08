import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/dialogs/about_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/file_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/find_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/font_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/go_to_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/help_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/message_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/page_setup_dialog.dart';
import 'package:xp_notepad/ui/notepad/editor/xp_editor.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/utils/result.dart';

import '../support/fakes.dart';

/// A document repository whose reads finish only when the test says so, to model a
/// large file that is still loading.
class LoadingDocumentRepository implements DocumentRepository {
  Completer<Result<TextFile>>? pending;

  @override
  Future<Result<TextFile>> read(String path) {
    return (pending = Completer<Result<TextFile>>()).future;
  }

  void finish(String text) {
    pending!.complete(Success(TextFile(text, FileEncoding.ansi)));
  }

  @override
  Future<Result<void>> write(String path, String text, FileEncoding encoding) async {
    return const Success<void>(null);
  }
}

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
    WidgetTester tester, {
    DocumentRepository? documents,
    String? initialPath,
  }) async {
    tester.view
      ..physicalSize = const Size(600, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: documents ?? FakeDocumentRepository(),
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: const NotepadSettings(),
        initialPath: initialPath,
      ),
    );
    await tester.pump();
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  Finder editorField() =>
      find.descendant(of: find.byType(XpEditor), matching: find.byType(EditableText));

  Finder dialogField(Type dialog) =>
      find.descendant(of: find.byType(dialog), matching: find.byType(EditableText));

  /// True when keyboard focus sits inside one of the app's dialogs or the Find box.
  bool focusInsideDialog() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    const dialogs = <Type>[
      FontDialog,
      PageSetupDialog,
      GoToDialog,
      AboutDialog,
      HelpDialog,
      MessageDialog,
      FileDialog,
      FindDialog,
    ];
    return dialogs.any((type) => _hasAncestor(context, type));
  }

  bool focusInside<T extends Widget>() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && context.findAncestorWidgetOfExactType<T>() != null;
  }

  group('F-01: a size typed into the Font Size box is applied by OK', () {
    testWidgets('a typed size is kept when OK is pressed', (tester) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      await tester.enterText(dialogField(FontDialog), '14');
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(vm.modal, isNull);
      expect(vm.font.sizePoints, 14);
    });

    testWidgets('an out-of-range size keeps the dialog open and says why', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      await tester.enterText(dialogField(FontDialog), '1700');
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(vm.modal, isA<FontRequest>());
      expect(vm.font.sizePoints, 10);
      expect(find.textContaining('1638'), findsOneWidget);
    });
  });

  group('F-02: dialogs take keyboard focus, so typing cannot edit the document', () {
    testWidgets('the Font dialog takes focus when it opens', (tester) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      expect(focusInside<FontDialog>(), isTrue);
    });

    testWidgets('typing while the Font dialog is open leaves the document alone', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      if (tester.testTextInput.hasAnyClients) {
        tester.testTextInput.enterText('zz');
        await tester.pump();
      }
      expect(vm.text.text, isEmpty);
    });

    testWidgets('Escape closes the Font dialog and keeps the font', (tester) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      await press(tester, LogicalKeyboardKey.escape);

      expect(vm.modal, isNull);
      expect(vm.font.sizePoints, 10);
    });

    testWidgets('the arrow keys choose a family in the Font list', (tester) async {
      final vm = await pumpNotepad(tester);
      unawaited(vm.showFont());
      await tester.pump();

      await press(tester, LogicalKeyboardKey.arrowDown);
      await tester.tap(find.text('OK'));
      await tester.pump();

      final current = EditorFont.families.indexOf('Lucida Console');
      expect(vm.font.family, EditorFont.families[current + 1]);
    });

    testWidgets('every dialog and the Find box take focus when they open', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      final openers = <String, Future<void> Function()>{
        'Font': () async => unawaited(vm.showFont()),
        'Page Setup': () async => unawaited(vm.editPageSetup()),
        'Go To': () async => unawaited(vm.showGoTo()),
        'About': () async => unawaited(vm.showAbout()),
        'Help': () async => unawaited(vm.showHelp()),
        'Open': () async => unawaited(vm.openDocument()),
        'Save As': () async => unawaited(vm.saveAs()),
        'Find': () async => vm.showFind(replace: false),
        'Replace': () async => vm.showFind(replace: true),
      };
      for (final entry in openers.entries) {
        await entry.value();
        await tester.pump();
        expect(focusInsideDialog(), isTrue, reason: '${entry.key} has no focus');
        await press(tester, LogicalKeyboardKey.escape);
        if (vm.find != null) vm.closeFind();
        await tester.pump();
      }
    });
  });

  group('F-03: Find keeps focus in its box', () {
    testWidgets('Enter runs Find Next and leaves focus in the Find box', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      vm.insertText('the quick fox');
      // Find Next searches forward from the caret, so the caret goes to the start first.
      vm.text.selection = const TextSelection.collapsed(offset: 0);
      vm.showFind(replace: false);
      await tester.pump();

      await tester.enterText(dialogField(FindDialog).first, 'fox');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(focusInside<FindDialog>(), isTrue);
    });

    testWidgets('after a Cannot find message closes, focus returns to the Find box', (
      tester,
    ) async {
      final vm = await pumpNotepad(tester);
      vm.showFind(replace: false);
      await tester.pump();

      await tester.enterText(dialogField(FindDialog).first, 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(vm.modal, isA<MessageRequest>());

      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(vm.modal, isNull);
      expect(focusInside<FindDialog>(), isTrue);
    });
  });

  group('F-04: the editor accepts text after the document is replaced', () {
    testWidgets('typing reaches the editor after File > New', (tester) async {
      final vm = await pumpNotepad(tester);
      await tester.tap(editorField());
      await tester.pump();

      await vm.newDocument();
      await tester.pump();
      await tester.pump();

      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('abc');
      await tester.pump();
      expect(vm.text.text, 'abc');
    });

    testWidgets('typing reaches the editor after a file opens at startup', (
      tester,
    ) async {
      final documents = FakeDocumentRepository()
        ..files['/notes/start.txt'] = encodeText('from file', FileEncoding.ansi);
      final vm = await pumpNotepad(
        tester,
        documents: documents,
        initialPath: '/notes/start.txt',
      );
      await tester.pump();

      expect(vm.fileName, 'start.txt');
      expect(vm.text.text, 'from file');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('typed after load');
      await tester.pump();
      expect(vm.text.text, 'typed after load');
    });
  });

  group('F-05: text typed while a file loads is not replaced silently', () {
    testWidgets('edits made during the load are kept, and the save prompt decides', (
      tester,
    ) async {
      final documents = LoadingDocumentRepository();
      final vm = await pumpNotepad(
        tester,
        documents: documents,
        initialPath: '/data/big.txt',
      );
      await tester.enterText(editorField(), 'typed');
      await tester.pump();

      documents.finish('from file');
      await tester.pump();
      await tester.pump();

      expect(vm.modal, isA<MessageRequest>());
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(vm.text.text, 'typed');
      expect(vm.fileName, 'Untitled');
    });

    testWidgets('a file that loads without edits replaces the empty document', (
      tester,
    ) async {
      final documents = LoadingDocumentRepository();
      final vm = await pumpNotepad(
        tester,
        documents: documents,
        initialPath: '/data/big.txt',
      );

      documents.finish('from file');
      await tester.pump();
      await tester.pump();

      expect(vm.modal, isNull);
      expect(vm.text.text, 'from file');
      expect(vm.fileName, 'big.txt');
    });

    testWidgets('File > New during the load cancels the load', (tester) async {
      final documents = LoadingDocumentRepository();
      final vm = await pumpNotepad(
        tester,
        documents: documents,
        initialPath: '/data/big.txt',
      );

      await vm.newDocument();
      await tester.pump();
      documents.finish('from file');
      await tester.pump();
      await tester.pump();

      expect(vm.text.text, isEmpty);
      expect(vm.fileName, 'Untitled');
      expect(vm.modal, isNull);
    });
  });
}

bool _hasAncestor(BuildContext context, Type type) {
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget.runtimeType == type) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
