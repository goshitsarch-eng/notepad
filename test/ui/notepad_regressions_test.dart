import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/utils/result.dart';

import '../support/fakes.dart';

/// A document store whose writes wait for [gate], so a test can change text during a save.
class GatedDocumentRepository implements DocumentRepository {
  final Map<String, Uint8List> files = {};
  Completer<void>? gate;

  @override
  Future<Result<TextFile>> read(String path, {FileEncoding? encoding}) async {
    final bytes = files[path];
    if (bytes == null) return Failure<TextFile>(StateError('missing $path'));
    return Success(readText(bytes, encoding: encoding));
  }

  @override
  Future<Result<void>> write(
    String path,
    String text,
    FileEncoding encoding,
  ) async {
    await gate?.future;
    files[path] = encodeText(text, encoding);
    return const Success<void>(null);
  }
}

/// Lets the window's settle timer and the view model's awaits run.
Future<void> pause([int milliseconds = 250]) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return call.method == 'Clipboard.getData' ? {'text': ''} : null;
        });
  });

  group('window size', () {
    late FakeWindowService window;
    late FakeSettingsRepository settings;
    late NotepadViewModel vm;

    setUp(() {
      window = FakeWindowService();
      settings = FakeSettingsRepository();
      vm = NotepadViewModel(
        documents: FakeDocumentRepository(),
        settingsRepository: settings,
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: window,
        settings: const NotepadSettings(),
      )..start();
    });

    tearDown(() => vm.dispose());

    test('exit while maximized keeps the last normal size', () async {
      window.size = (width: 700.0, height: 500.0);
      vm.onResized();
      await pause();

      window.maximized = true;
      window.size = (width: 1728.0, height: 992.0);
      await vm.requestExit();

      expect(settings.saved?.windowWidth, 700);
      expect(settings.saved?.windowHeight, 500);
    });

    test('a window dragged below the minimum is brought back to it', () async {
      window.size = (width: 300.0, height: 200.0);
      vm.onResized();
      await pause();

      expect(window.size.width, kMinimumWindowSize.width);
      expect(window.size.height, kMinimumWindowSize.height);
    });

    test('a resize that is still going does not act until it settles', () async {
      window.size = (width: 300.0, height: 200.0);
      vm.onResized();
      await pause(50);
      vm.onResized();
      await pause(50);
      // Still inside the settle window, so the size has not been corrected yet.
      expect(window.size.width, 300);
      await pause(250);
      expect(window.size.width, kMinimumWindowSize.width);
    });
  });

  group('one dialog at a time', () {
    late FakeWindowService window;
    late NotepadViewModel vm;

    setUp(() {
      window = FakeWindowService();
      vm = NotepadViewModel(
        documents: FakeDocumentRepository(),
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: window,
        settings: const NotepadSettings(),
      )..start();
    });

    tearDown(() => vm.dispose());

    test('a second dialog does not replace the one already open', () async {
      unawaited(vm.showAbout());
      await pause(10);
      final open = vm.modal;
      unawaited(vm.showHelp());
      await pause(10);
      expect(vm.modal, same(open));
      expect(vm.modal, isA<AboutRequest>());
    });

    test('a close request is ignored while a dialog is open', () async {
      unawaited(vm.showAbout());
      await pause(10);
      vm.onCloseRequested();
      await pause(10);
      expect(vm.modal, isA<AboutRequest>());
      expect(window.closed, isFalse);
    });

    test('a missing file says it cannot be found', () async {
      final documents = FakeDocumentRepository();
      final missing = NotepadViewModel(
        documents: documents,
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: FakeWindowService(),
        settings: const NotepadSettings(),
      )..start(initialPath: '/home/tester/notes/gone.txt');
      addTearDown(missing.dispose);
      await pause(10);

      final request = missing.modal;
      expect(request, isA<MessageRequest>());
      expect(
        (request! as MessageRequest).text,
        'Cannot find "gone.txt". Make sure the path and file name are correct.',
      );
    });
  });

  group('window title', () {
    test('opening a file puts its name in the window title', () async {
      final window = FakeWindowService();
      final documents = FakeDocumentRepository()
        ..files['/home/tester/notes.txt'] = encodeText('x', FileEncoding.ansi);
      final vm = NotepadViewModel(
        documents: documents,
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: window,
        settings: const NotepadSettings(),
      )..start(initialPath: '/home/tester/notes.txt');
      addTearDown(vm.dispose);
      await pause(10);

      expect(window.title, 'notes.txt - Notepad');
    });

    test('New puts Untitled back in the window title', () async {
      final window = FakeWindowService();
      final documents = FakeDocumentRepository()
        ..files['/home/tester/notes.txt'] = encodeText('x', FileEncoding.ansi);
      final vm = NotepadViewModel(
        documents: documents,
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: window,
        settings: const NotepadSettings(),
      )..start(initialPath: '/home/tester/notes.txt');
      addTearDown(vm.dispose);
      await pause(10);

      await vm.newDocument();
      expect(window.title, 'Untitled - Notepad');
    });
  });

  group('saving', () {
    test('typing during a save leaves the document modified', () async {
      final documents = GatedDocumentRepository()
        ..files['/home/tester/a.txt'] = encodeText('one', FileEncoding.ansi);
      final vm = NotepadViewModel(
        documents: documents,
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: FakeWindowService(),
        settings: const NotepadSettings(),
      )..start(initialPath: '/home/tester/a.txt');
      addTearDown(vm.dispose);
      await pause(10);

      documents.gate = Completer<void>();
      vm.text.value = const TextEditingValue(text: 'one two');
      final save = vm.save();
      vm.text.value = const TextEditingValue(text: 'one two three');
      documents.gate!.complete();
      expect(await save, isTrue);

      // The file holds "one two", so the later edit must still count as unsaved.
      expect(vm.isModified, isTrue);
    });

    test('a save with no edits in between is clean afterwards', () async {
      final documents = GatedDocumentRepository()
        ..files['/home/tester/b.txt'] = encodeText('one', FileEncoding.ansi);
      final vm = NotepadViewModel(
        documents: documents,
        settingsRepository: FakeSettingsRepository(),
        fileSystem: FakeFileSystemService(),
        printing: FakePrintingService(),
        window: FakeWindowService(),
        settings: const NotepadSettings(),
      )..start(initialPath: '/home/tester/b.txt');
      addTearDown(vm.dispose);
      await pause(10);

      vm.text.value = const TextEditingValue(text: 'changed');
      expect(vm.isModified, isTrue);
      expect(await vm.save(), isTrue);
      expect(vm.isModified, isFalse);
    });
  });
}
