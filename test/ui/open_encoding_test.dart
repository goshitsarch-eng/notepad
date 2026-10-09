import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/dialogs/file_dialog.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

/// The Open dialog's Encoding list, which XP has and this app lacked, and what the view
/// model does with the choice.
Uint8List _utf16LittleEndianWithoutMark(String text) {
  final data = ByteData(text.length * 2);
  for (var i = 0; i < text.length; i++) {
    data.setUint16(i * 2, text.codeUnitAt(i), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late FakeDocumentRepository documents;
  late FakeFileSystemService fileSystem;

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
    documents = FakeDocumentRepository();
    fileSystem = FakeFileSystemService();
    tester.view
      ..physicalSize = const Size(600, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: documents,
          settings: FakeSettingsRepository(),
          fileSystem: fileSystem,
          printing: FakePrintingService(),
          window: FakeWindowService(),
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

  /// The file the dialog named does not exist in the fake, so the open ends in a message.
  /// It is closed so that the open can finish.
  Future<void> finish(
    WidgetTester tester,
    NotepadViewModel vm,
    Future<void> opening,
  ) async {
    await frames(tester);
    if (vm.modal case final MessageRequest message) {
      message.complete(MessageChoice.ok);
    }
    await opening;
  }

  Finder encodingList() => find.byWidgetPredicate(
    (w) => w is XpComboBox<FileEncoding?> && w.semanticLabel == 'Encoding',
  );

  group('the Open dialog', () {
    testWidgets('has an Encoding list that starts on detecting by itself', (
      tester,
    ) async {
      final vm = await pump(tester);
      final opening = vm.openDocument();
      await frames(tester);

      expect(encodingList(), findsOneWidget);
      expect(find.text('Encoding:'), findsOneWidget);
      expect(find.text('Detect automatically'), findsOneWidget);

      (vm.modal! as FileRequest).complete(null);
      await opening;
    });

    testWidgets('answers with no encoding when none was chosen', (
      tester,
    ) async {
      final vm = await pump(tester);
      final opening = vm.openDocument();
      await frames(tester);
      final request = vm.modal! as FileRequest;
      FileChoice? chosen;
      unawaited(request.result.then((choice) => chosen = choice));

      await tester.enterText(
        find
            .descendant(
              of: find.byType(FileDialog),
              matching: find.byType(EditableText),
            )
            .first,
        'notes.txt',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await frames(tester);

      expect(chosen!.path, '/home/tester/notes.txt');
      expect(chosen!.openAs, isNull);
      await finish(tester, vm, opening);
    });

    testWidgets('answers with the encoding the user chose', (tester) async {
      final vm = await pump(tester);
      final opening = vm.openDocument();
      await frames(tester);
      final request = vm.modal! as FileRequest;
      FileChoice? chosen;
      unawaited(request.result.then((choice) => chosen = choice));

      await tester.tap(encodingList());
      await frames(tester);
      await tester.tap(find.text('Unicode').last);
      await frames(tester);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(FileDialog),
              matching: find.byType(EditableText),
            )
            .first,
        'notes.txt',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await frames(tester);

      expect(chosen!.openAs, FileEncoding.unicode);
      await finish(tester, vm, opening);
    });

    testWidgets(
      'keeps the choice when a file is opened by double clicking it',
      (tester) async {
        final vm = await pump(tester);
        fileSystem.listings['/home/tester'] = [
          DirectoryEntry(
            name: 'report.txt',
            path: '/home/tester/report.txt',
            isDirectory: false,
            size: 12,
            modified: DateTime(2026, 10, 9),
          ),
        ];
        final opening = vm.openDocument();
        await frames(tester);
        final request = vm.modal! as FileRequest;
        FileChoice? chosen;
        unawaited(request.result.then((choice) => chosen = choice));

        await tester.tap(encodingList());
        await frames(tester);
        await tester.tap(find.text('UTF-8').last);
        await frames(tester);
        await tester.tap(find.text('report.txt'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('report.txt'));
        await frames(tester);

        expect(chosen!.path, '/home/tester/report.txt');
        expect(chosen!.openAs, FileEncoding.utf8);
        await finish(tester, vm, opening);
      },
    );

    testWidgets('Save As keeps its own list, which has no automatic choice', (
      tester,
    ) async {
      final vm = await pump(tester);
      final saving = vm.saveAs();
      await frames(tester);

      expect(find.byType(XpComboBox<FileEncoding>), findsOneWidget);
      expect(find.text('Detect automatically'), findsNothing);

      (vm.modal! as FileRequest).complete(null);
      await saving;
    });
  });

  group('opening as a chosen encoding', () {
    testWidgets('reads the file as that encoding and keeps it for saving', (
      tester,
    ) async {
      final vm = await pump(tester);
      // Japanese UTF-16 with no mark: nothing in it says what it is.
      const text = '日本語のテキストです。\n';
      documents.files['/home/tester/jp.txt'] = _utf16LittleEndianWithoutMark(
        text,
      );
      final opening = vm.openDocument();
      await frames(tester);
      (vm.modal! as FileRequest).complete(
        const FileChoice(
          '/home/tester/jp.txt',
          FileEncoding.ansi,
          openAs: FileEncoding.unicode,
        ),
      );
      await opening;
      await frames(tester);

      expect(vm.text.text, text);
      expect(documents.readEncodings.last, FileEncoding.unicode);
      // Saving writes it back in the encoding it was opened as.
      await vm.save();
      expect(documents.writes.last.encoding, FileEncoding.unicode);
    });

    testWidgets('detects by itself when no encoding is chosen', (tester) async {
      final vm = await pump(tester);
      documents.files['/home/tester/a.txt'] = encodeText(
        'café',
        FileEncoding.utf8,
      );
      final opening = vm.openDocument();
      await frames(tester);
      (vm.modal! as FileRequest).complete(
        const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
      );
      await opening;
      await frames(tester);

      expect(vm.text.text, 'café');
      expect(documents.readEncodings.last, isNull);
    });
  });
}
