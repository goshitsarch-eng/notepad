import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/utils/result.dart';

import '../support/fakes.dart';

/// A repository whose reads wait for the test, to model a slow disk.
class _GatedReads extends FakeDocumentRepository {
  final gate = Completer<void>();

  @override
  Future<Result<TextFile>> read(String path, {FileEncoding? encoding}) async {
    await gate.future;
    return super.read(path, encoding: encoding);
  }
}

/// A message that is ready while another dialog is open waits its turn. It used to be
/// dropped and counted as the answer No, so a file the user asked for silently did not
/// open, or an error went unreported.
void main() {
  late _GatedReads documents;
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
    documents = _GatedReads();
    vm = NotepadViewModel(
      documents: documents,
      settingsRepository: FakeSettingsRepository(),
      fileSystem: FakeFileSystemService(),
      printing: FakePrintingService(),
      window: FakeWindowService(),
      settings: const NotepadSettings(),
    );
  });

  tearDown(() => vm.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Starts opening [path] with the read held back, then opens About on top.
  Future<AboutRequest> aboutDuringRead(String path) async {
    vm.start(initialPath: path);
    await settle();
    unawaited(vm.showAbout());
    await settle();
    return vm.modal! as AboutRequest;
  }

  test(
    'an error found while About is open is shown when About closes',
    () async {
      // The file is not there, so the read ends in an error to report.
      final about = await aboutDuringRead('/missing.txt');
      documents.gate.complete();
      await settle();
      expect(vm.modal, same(about), reason: 'About is still the one on screen');

      about.complete(null);
      await settle();
      final message = vm.modal;
      expect(message, isA<MessageRequest>());
      expect((message! as MessageRequest).text, contains('missing.txt'));
      message.complete(MessageChoice.ok);
      await settle();
      expect(vm.modal, isNull);
    },
  );

  test(
    'the question about a large file waits, and Yes opens the file',
    () async {
      final big = 'a' * (kLargeDocumentCharacters + 1);
      documents.files['/big.txt'] = encodeText(big, FileEncoding.ansi);
      final about = await aboutDuringRead('/big.txt');
      documents.gate.complete();
      await settle();
      expect(vm.modal, same(about));

      about.complete(null);
      await settle();
      final question = vm.modal! as MessageRequest;
      expect(question.text, contains('"big.txt" is large'));
      question.complete(MessageChoice.yes);
      await settle();
      expect(vm.text.text.length, big.length);
      expect(vm.fileName, 'big.txt');
      expect(vm.modal, isNull);
    },
  );

  test(
    'the question about a large file waits, and No leaves things as they are',
    () async {
      documents.files['/big.txt'] = encodeText(
        'a' * (kLargeDocumentCharacters + 1),
        FileEncoding.ansi,
      );
      final about = await aboutDuringRead('/big.txt');
      documents.gate.complete();
      await settle();
      about.complete(null);
      await settle();
      (vm.modal! as MessageRequest).complete(MessageChoice.no);
      await settle();
      expect(vm.text.text.length, 0);
      expect(vm.fileName, 'Untitled');
    },
  );

  test('a question that is no longer wanted is not asked', () async {
    documents.files['/big.txt'] = encodeText(
      'a' * (kLargeDocumentCharacters + 1),
      FileEncoding.ansi,
    );
    final about = await aboutDuringRead('/big.txt');
    documents.gate.complete();
    await settle();
    // While About is open the user starts a new document, which replaces the request.
    await vm.newDocument();
    about.complete(null);
    await settle();
    expect(
      vm.modal,
      isNull,
      reason: 'the question belongs to an open that was replaced',
    );
    expect(vm.text.text, '');
  });

  test(
    'a Yes to a question about an open that was replaced does nothing',
    () async {
      documents.files['/big.txt'] = encodeText(
        'a' * (kLargeDocumentCharacters + 1),
        FileEncoding.ansi,
      );
      vm.start(initialPath: '/big.txt');
      documents.gate.complete();
      await settle();
      final question = vm.modal! as MessageRequest;
      // Something else replaces the document while the question is on screen.
      await vm.newDocument();
      question.complete(MessageChoice.yes);
      await settle();
      expect(vm.text.text.length, 0);
      expect(vm.fileName, 'Untitled');
    },
  );

  test('dialogs shown one after another each get their turn', () async {
    final first = vm.showAbout();
    await settle();
    final about = vm.modal! as AboutRequest;
    final second = vm.showHelp();
    final third = vm.showAbout();
    await settle();
    expect(vm.modal, same(about));
    about.complete(null);
    await settle();
    expect(vm.modal, isA<HelpRequest>());
    (vm.modal! as HelpRequest).complete(null);
    await settle();
    expect(vm.modal, isA<AboutRequest>());
    (vm.modal! as AboutRequest).complete(null);
    await Future.wait([first, second, third]);
    await settle();
    expect(vm.modal, isNull);
  });

  test('a dialog asked for while nothing is open appears at once', () {
    unawaited(vm.showAbout());
    expect(vm.modal, isA<AboutRequest>());
    (vm.modal! as AboutRequest).complete(null);
  });
}
