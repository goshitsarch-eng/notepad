import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/utils/result.dart';

import '../support/fakes.dart';

/// Regressions found in the second audit, at the level of the view model.
/// A repository whose writes wait for the test, to model a slow disk.
class _GatedWrites extends FakeDocumentRepository {
  Completer<void>? gate;

  @override
  Future<Result<void>> write(
    String path,
    String text,
    FileEncoding encoding,
  ) async {
    await gate?.future;
    return super.write(path, text, encoding);
  }
}

void main() {
  late FakeDocumentRepository documents;
  late FakeFileSystemService fileSystem;
  late NotepadViewModel vm;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.getData' ? {'text': ''} : null,
        );
  });

  setUp(() {
    documents = FakeDocumentRepository();
    fileSystem = FakeFileSystemService();
    vm = NotepadViewModel(
      documents: documents,
      settingsRepository: FakeSettingsRepository(),
      fileSystem: fileSystem,
      printing: FakePrintingService(),
      window: FakeWindowService(),
      settings: const NotepadSettings(),
    )..start();
  });

  tearDown(() => vm.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void type(String value) => vm.text.value = TextEditingValue(text: value);

  T dialog<T extends ModalRequest<Object?>>() {
    expect(vm.modal, isA<T>());
    return vm.modal! as T;
  }

  /// The save prompt, answered, and the number of times it has been shown so far.
  int prompts = 0;
  Future<void> answerSavePrompts(MessageChoice choice) async {
    // Runs until the file dialog or the end of the open is reached.
    for (var i = 0; i < 8; i++) {
      await settle();
      final request = vm.modal;
      if (request is MessageRequest &&
          request.text.contains('Do you want to save the changes?')) {
        prompts++;
        request.complete(choice);
      } else {
        return;
      }
    }
  }

  group('File > Open asks about unsaved changes once', () {
    setUp(() {
      prompts = 0;
      documents.files['/home/tester/a.txt'] = encodeText(
        'from disk',
        FileEncoding.ansi,
      );
    });

    test(
      'answering No, then choosing a file, opens it without a second prompt',
      () async {
        type('unsaved');
        final opening = vm.openDocument();
        await answerSavePrompts(MessageChoice.no);
        dialog<FileRequest>().complete(
          const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
        );
        await settle();
        await settle();
        await answerSavePrompts(MessageChoice.no);
        await opening;

        expect(prompts, 1);
        expect(vm.text.text, 'from disk');
        expect(vm.fileName, 'a.txt');
        expect(vm.isModified, isFalse);
      },
    );

    test(
      'answering Yes saves, then opens the file with no second prompt',
      () async {
        type('unsaved');
        vm.text.selection = const TextSelection.collapsed(offset: 0);
        final opening = vm.openDocument();
        await settle();
        // Yes: the document has no name yet, so Save As is shown.
        (vm.modal! as MessageRequest).complete(MessageChoice.yes);
        await settle();
        dialog<FileRequest>().complete(
          const FileChoice('/home/tester/mine.txt', FileEncoding.ansi),
        );
        await settle();
        await settle();
        dialog<FileRequest>().complete(
          const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
        );
        await settle();
        await settle();
        await opening;

        expect(documents.writes.single.text, 'unsaved');
        expect(vm.modal, isNull);
        expect(vm.text.text, 'from disk');
      },
    );

    test('Cancel on the prompt opens nothing', () async {
      type('unsaved');
      final opening = vm.openDocument();
      await answerSavePrompts(MessageChoice.cancel);
      await opening;

      expect(vm.modal, isNull);
      expect(vm.text.text, 'unsaved');
    });

    test(
      'text typed while the file is read still gets its own prompt',
      () async {
        type('unsaved');
        final opening = vm.openDocument();
        await answerSavePrompts(MessageChoice.no);
        final request = dialog<FileRequest>();
        request.complete(
          const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
        );
        // The choice is delivered, but the read has not finished: the user keeps typing.
        type('unsaved, and more');
        await settle();
        await settle();
        await answerSavePrompts(MessageChoice.cancel);
        await opening;

        expect(
          prompts,
          2,
          reason:
              'the extra typing is new text the user has not agreed to lose',
        );
        expect(vm.text.text, 'unsaved, and more');
      },
    );
  });

  test('text typed while the save before an open is still running gets its own prompt', () async {
    final gated = _GatedWrites();
    final slow = NotepadViewModel(
      documents: gated,
      settingsRepository: FakeSettingsRepository(),
      fileSystem: fileSystem,
      printing: FakePrintingService(),
      window: FakeWindowService(),
      settings: const NotepadSettings(),
    )..start();
    addTearDown(slow.dispose);
    gated.files['/home/tester/b.txt'] = encodeText('other', FileEncoding.ansi);

    // A document that has a name and unsaved changes.
    slow.text.value = const TextEditingValue(text: 'first');
    final naming = slow.saveAs();
    await settle();
    (slow.modal! as FileRequest).complete(
      const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
    );
    await naming;
    slow.text.value = const TextEditingValue(text: 'second');

    // Open, answer Yes, and keep typing while the write is in flight.
    gated.gate = Completer<void>();
    final opening = slow.openDocument();
    await settle();
    (slow.modal! as MessageRequest).complete(MessageChoice.yes);
    await settle();
    slow.text.value = const TextEditingValue(
      text: 'second, and more typed during the save',
    );
    gated.gate!.complete();
    await settle();
    await settle();
    (slow.modal! as FileRequest).complete(
      const FileChoice('/home/tester/b.txt', FileEncoding.ansi),
    );
    await settle();
    await settle();

    // The typing is in no file, so replacing it needs a prompt of its own.
    expect(slow.modal, isA<MessageRequest>());
    expect(
      (slow.modal! as MessageRequest).text,
      contains('Do you want to save the changes?'),
    );
    (slow.modal! as MessageRequest).complete(MessageChoice.cancel);
    await opening;
    expect(slow.text.text, 'second, and more typed during the save');
  });

  group('error messages give the reason (F-12)', () {
    String lastMessage() => dialog<MessageRequest>().text;

    test('an unreadable file says why', () async {
      documents.readFailures['/home/tester/secret.txt'] =
          const FileSystemException(
            'Cannot open file',
            '/home/tester/secret.txt',
            OSError('Permission denied', 13),
          );
      final opening = vm.openDocument();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/secret.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();

      expect(lastMessage(), 'Cannot open "secret.txt".\n\nPermission denied');
      (vm.modal! as MessageRequest).complete(MessageChoice.ok);
      await opening;
    });

    test('a file that is too large says so', () async {
      documents.readFailures['/home/tester/huge.txt'] =
          const FileSystemException(
            'The file is too large. Notepad opens files up to 64 MB',
            '/home/tester/huge.txt',
          );
      final opening = vm.openDocument();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/huge.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();

      expect(lastMessage(), contains('too large'));
      expect(lastMessage(), contains('64 MB'));
      (vm.modal! as MessageRequest).complete(MessageChoice.ok);
      await opening;
    });

    test('a missing file keeps the XP wording', () async {
      documents.readFailures['/home/tester/gone.txt'] = PathNotFoundException(
        '/home/tester/gone.txt',
        const OSError('No such file or directory', 2),
      );
      final opening = vm.openDocument();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/gone.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();

      expect(
        lastMessage(),
        'Cannot find "gone.txt". Make sure the path and file name are correct.',
      );
      (vm.modal! as MessageRequest).complete(MessageChoice.ok);
      await opening;
    });

    test('a save that fails names the folder and the reason', () async {
      documents.writeFailure = const FileSystemException(
        'Cannot open file',
        '/readonly/a.txt',
        OSError('Read-only file system', 30),
      );
      type('text');
      final saving = vm.saveAs();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/readonly/a.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();

      expect(
        lastMessage(),
        'Cannot save "a.txt" in "/readonly".\n\nRead-only file system',
      );
      (vm.modal! as MessageRequest).complete(MessageChoice.ok);
      expect(await saving, isFalse);
      expect(
        vm.isModified,
        isTrue,
        reason: 'a failed save leaves the document unsaved',
      );
    });

    test('an error with no usable reason still gives a message', () async {
      documents.writeFailure = StateError('no reason a person could use');
      type('text');
      final saving = vm.saveAs();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();

      expect(lastMessage(), 'Cannot save "a.txt" in "/home/tester".');
      (vm.modal! as MessageRequest).complete(MessageChoice.ok);
      await saving;
    });
  });

  group('a large file is opened only when the user agrees', () {
    // Typing in a document this size takes seconds per key, so the user is told first.
    final big = 'a' * (kLargeDocumentCharacters + 1);

    Future<MessageRequest> openBig() async {
      documents.files['/home/tester/big.txt'] = encodeText(
        big,
        FileEncoding.ansi,
      );
      final opening = vm.openDocument();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/big.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();
      addTearDown(() async => opening);
      return dialog<MessageRequest>();
    }

    test('the warning says what is wrong and offers Yes and No', () async {
      final warning = await openBig();

      expect(warning.text, contains('"big.txt" is large'));
      expect(warning.text, contains('very slow'));
      expect(warning.choices, [MessageChoice.yes, MessageChoice.no]);
      expect(warning.icon, MessageIcon.warning);
      warning.complete(MessageChoice.no);
    });

    test('Yes opens the file', () async {
      final warning = await openBig();
      warning.complete(MessageChoice.yes);
      await settle();
      await settle();

      expect(vm.modal, isNull);
      expect(vm.text.text.length, big.length);
      expect(vm.fileName, 'big.txt');
    });

    test('No leaves the current document alone', () async {
      type('my notes');
      final opening = vm.openDocument();
      await settle();
      (vm.modal! as MessageRequest).complete(
        MessageChoice.no,
      ); // discard my notes
      await settle();
      documents.files['/home/tester/big.txt'] = encodeText(
        big,
        FileEncoding.ansi,
      );
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/big.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();
      dialog<MessageRequest>().complete(MessageChoice.no);
      await opening;

      expect(
        vm.text.text,
        'my notes',
        reason: 'declining the big file keeps what was there',
      );
      expect(vm.fileName, 'Untitled');
      expect(vm.isModified, isTrue);
    });

    test('a file just under the limit opens with no warning', () async {
      final fine = 'a' * kLargeDocumentCharacters;
      documents.files['/home/tester/fine.txt'] = encodeText(
        fine,
        FileEncoding.ansi,
      );
      final opening = vm.openDocument();
      await settle();
      dialog<FileRequest>().complete(
        const FileChoice('/home/tester/fine.txt', FileEncoding.ansi),
      );
      await settle();
      await settle();
      await opening;

      expect(vm.modal, isNull);
      expect(vm.fileName, 'fine.txt');
    });
  });

  group('the file dialogs start where the user was', () {
    test('Save As starts in the last folder used', () async {
      final saving = vm.saveAs();
      await settle();
      expect(dialog<FileRequest>().startDirectory, '/home/tester');
      dialog<FileRequest>().complete(null);
      await saving;
    });
  });
}
