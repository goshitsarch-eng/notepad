import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

void main() {
  late FakeDocumentRepository documents;
  late FakeWindowService window;
  late FakeFileSystemService fileSystem;
  late FakePrintingService printing;
  late NotepadViewModel vm;
  String clipboard = '';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
            return null;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });

  setUp(() {
    clipboard = '';
    documents = FakeDocumentRepository();
    window = FakeWindowService();
    fileSystem = FakeFileSystemService();
    printing = FakePrintingService();
    vm = NotepadViewModel(
      documents: documents,
      settingsRepository: FakeSettingsRepository(),
      fileSystem: fileSystem,
      printing: printing,
      window: window,
      settings: const NotepadSettings(),
      clock: () => DateTime(2026, 10, 7, 15, 5),
    )..start();
  });

  tearDown(() => vm.dispose());

  void typeText(String value) {
    vm.text.value = TextEditingValue(text: value);
  }

  /// Lets awaited checks inside the view model run so that the next dialog is shown.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void select(int start, int end) {
    vm.text.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  /// Answers the dialog that the view model is waiting on.
  T answer<T extends ModalRequest<Object?>>() {
    final request = vm.modal;
    expect(request, isA<T>());
    return request as T;
  }

  group('document lifecycle', () {
    test('starts untitled and unmodified with the XP title', () {
      expect(vm.fileName, 'Untitled');
      expect(vm.isModified, isFalse);
      expect(vm.windowTitle, 'Untitled - Notepad');
      expect(window.handler, same(vm));
      expect(window.preventClose, isTrue);
      expect(window.title, 'Untitled - Notepad');
    });

    test(
      'typing marks the document modified; saving clears it and renames it',
      () async {
        typeText('hello');
        expect(vm.isModified, isTrue);

        final saving = vm.save();
        final dialog = answer<FileRequest>();
        expect(dialog.mode, FileDialogMode.save);
        dialog.complete(
          const FileChoice('/home/tester/notes.txt', FileEncoding.utf8),
        );
        expect(await saving, isTrue);

        expect(vm.isModified, isFalse);
        expect(vm.fileName, 'notes.txt');
        expect(vm.windowTitle, 'notes.txt - Notepad');
        expect(documents.writes.single.text, 'hello');
        expect(documents.writes.single.encoding, FileEncoding.utf8);
        expect(window.title, 'notes.txt - Notepad');
      },
    );

    test('opening a file loads its text and remembers its encoding', () async {
      documents.files['/home/tester/a.txt'] = encodeText(
        'first\nsecond',
        FileEncoding.unicode,
      );
      final opening = vm.openDocument();
      await settle();
      answer<FileRequest>().complete(
        const FileChoice('/home/tester/a.txt', FileEncoding.ansi),
      );
      await opening;

      expect(vm.text.text, 'first\nsecond');
      expect(vm.fileName, 'a.txt');
      expect(vm.isModified, isFalse);
      expect(vm.font.family, 'Lucida Console');
    });

    test('New asks about unsaved changes, and No discards them', () async {
      typeText('draft');
      final creating = vm.newDocument();
      final prompt = answer<MessageRequest>();
      expect(
        prompt.text,
        'The text in the Untitled file has changed.\n\nDo you want to save the changes?',
      );
      prompt.complete(MessageChoice.no);
      await creating;

      expect(vm.text.text, isEmpty);
      expect(vm.isModified, isFalse);
    });

    test('Cancel on the save prompt keeps the text and the window', () async {
      typeText('draft');
      final creating = vm.newDocument();
      answer<MessageRequest>().complete(MessageChoice.cancel);
      await creating;

      expect(vm.text.text, 'draft');
      expect(vm.isModified, isTrue);
    });

    test(
      'closing with unsaved changes asks first and can be cancelled',
      () async {
        typeText('draft');
        final closing = vm.requestExit();
        answer<MessageRequest>().complete(MessageChoice.cancel);
        await closing;
        expect(window.closed, isFalse);

        final leaving = vm.requestExit();
        answer<MessageRequest>().complete(MessageChoice.no);
        await leaving;
        expect(window.closed, isTrue);
      },
    );

    test(
      'printing hands the text and file name to the printing service',
      () async {
        typeText('print me');
        await vm.printDocument();
        expect(printing.printed, ['Untitled']);
      },
    );
  });

  group('editing', () {
    test('cut, copy and paste go through the clipboard', () async {
      typeText('hello world');
      select(6, 11);
      await vm.copy();
      expect(clipboard, 'world');

      await vm.cut();
      expect(vm.text.text, 'hello ');
      expect(clipboard, 'world');

      vm.text.selection = const TextSelection.collapsed(offset: 6);
      await vm.paste();
      expect(vm.text.text, 'hello world');
    });

    test('Time/Date inserts the XP form at the caret', () {
      typeText('at ');
      vm.text.selection = const TextSelection.collapsed(offset: 3);
      vm.insertTimeDate();
      expect(vm.text.text, 'at 3:05 PM 10/7/2026');
    });

    test('Select All selects everything and Delete removes the selection', () {
      typeText('abc');
      vm.selectAll();
      expect(vm.hasSelection, isTrue);
      vm.deleteSelection();
      expect(vm.text.text, isEmpty);
    });
  });

  group('find, replace and go to', () {
    test('Find Next selects each match, then reports when none is left', () {
      typeText('one two one');
      vm.text.selection = const TextSelection.collapsed(offset: 0);

      expect(vm.findNext(const SearchOptions(query: 'one')), isTrue);
      expect(vm.text.selection.baseOffset, 0);
      expect(vm.text.selection.extentOffset, 3);

      expect(vm.findNext(const SearchOptions(query: 'one')), isTrue);
      expect(vm.text.selection.baseOffset, 8);

      expect(vm.findNext(const SearchOptions(query: 'one')), isFalse);
      expect(answer<MessageRequest>().text, 'Cannot find "one"');
      answer<MessageRequest>().complete(MessageChoice.ok);
    });

    test('Replace All reports the count and rewrites the text', () {
      typeText('a a a');
      expect(
        vm.replaceAllMatches(const SearchOptions(query: 'a'), 'b'),
        isTrue,
      );
      expect(vm.text.text, 'b b b');
    });

    test('Replace swaps a selected match, then moves to the next one', () {
      typeText('x x');
      select(0, 1);
      expect(vm.replaceCurrent(const SearchOptions(query: 'x'), 'y'), isTrue);
      expect(vm.text.text, 'y x');
      expect(vm.text.selection.baseOffset, 2);
    });

    test('Go To clamps the line number to the document', () {
      typeText('a\nbc\nd');
      vm.goToLine(99);
      expect(vm.text.selection.baseOffset, 5);
      vm.goToLine(2);
      expect(vm.text.selection.baseOffset, 2);
    });
  });

  group('view options', () {
    test('Word Wrap is on by default and hides the status bar', () {
      expect(vm.wordWrap, isTrue);
      expect(vm.statusBarChecked, isTrue);
      expect(vm.statusBarVisible, isFalse);
    });

    test('Status Bar cannot be toggled while Word Wrap is on', () {
      vm.toggleStatusBar();
      expect(vm.statusBarChecked, isTrue);
    });

    test('turning Word Wrap off shows the status bar again', () {
      vm.toggleWordWrap();
      expect(vm.wordWrap, isFalse);
      expect(vm.statusBarVisible, isTrue);
    });

    test('the status text gives the caret line and column', () {
      typeText('ab\ncd');
      vm.text.selection = const TextSelection.collapsed(offset: 4);
      expect(vm.statusText, 'Ln 2, Col 2');
    });
  });

  group('menus', () {
    test('opening a menu and closing it updates the open index', () {
      vm.openMenuAt(1, byClick: true);
      expect(vm.openMenu, 1);
      expect(vm.menuOpenedByClick, isTrue);
      vm.closeMenu();
      expect(vm.openMenu, isNull);
    });

    test('losing window focus closes an open menu', () {
      vm.openMenuAt(0);
      vm.onActiveChanged(false);
      expect(vm.openMenu, isNull);
      expect(vm.isActive, isFalse);
    });
  });

  test('Find Next is enabled only after a search has been made', () {
    expect(vm.lastSearch.query, isEmpty);
    typeText('abc');
    vm.findNext(const SearchOptions(query: 'b'));
    expect(vm.lastSearch.query, 'b');
  });

  test('saving non-ANSI text as ANSI warns first, and Cancel keeps the file unsaved', () async {
    typeText('中文');
    final saving = vm.save();
    await settle();
    answer<FileRequest>().complete(
      const FileChoice('/home/tester/cjk.txt', FileEncoding.ansi),
    );
    await settle();
    expect(
      answer<MessageRequest>().text,
      contains('characters which will be lost'),
    );
    answer<MessageRequest>().complete(MessageChoice.cancel);

    expect(await saving, isFalse);
    expect(documents.writes, isEmpty);
    expect(vm.isModified, isTrue);
  });

  test('OK on the ANSI warning saves anyway', () async {
    typeText('中文');
    final saving = vm.save();
    await settle();
    answer<FileRequest>().complete(
      const FileChoice('/home/tester/cjk.txt', FileEncoding.ansi),
    );
    await settle();
    answer<MessageRequest>().complete(MessageChoice.ok);

    expect(await saving, isTrue);
    expect(documents.writes.single.text, '中文');
  });

  test('saving a file keeps the encoding it was opened with', () async {
    documents.files['/home/tester/wide.txt'] = Uint8List.fromList(
      encodeText('hi', FileEncoding.unicodeBigEndian),
    );
    final opening = vm.openDocument();
    await settle();
    answer<FileRequest>().complete(
      const FileChoice('/home/tester/wide.txt', FileEncoding.ansi),
    );
    await opening;

    expect(await vm.save(), isTrue);
    expect(documents.writes.single.encoding, FileEncoding.unicodeBigEndian);
    expect(documents.writes.single.text, 'hi');
  });
}
