import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

String _line(int i) =>
    'line ${i.toString().padLeft(6, '0')} ${'abcdefghij' * (i % 3)}';

String _document(int lines) => List.generate(lines, _line).join('\n');

int _offsetOfLine(String text, int line) =>
    TextMetrics.lineStart(text, line + 1);

/// Editing a large document through a window of it, as the view model sees it.
void main() {
  late FakeDocumentRepository documents;
  late NotepadViewModel vm;
  var clipboard = '';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  setUp(() {
    clipboard = '';
    documents = FakeDocumentRepository();
  });

  tearDown(() => vm.dispose());

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<NotepadViewModel> open(String text) async {
    documents.files['/big.txt'] = encodeText(text, FileEncoding.utf8);
    vm = NotepadViewModel(
      documents: documents,
      settingsRepository: FakeSettingsRepository(),
      fileSystem: FakeFileSystemService(),
      printing: FakePrintingService(),
      window: FakeWindowService(),
      settings: const NotepadSettings(),
    )..start(initialPath: '/big.txt');
    await settle();
    return vm;
  }

  /// What the editor does when the user types in the window.
  void typeInWindow(String inserted, {int at = -1}) {
    final view = vm.windowed!.view;
    final position = at < 0 ? view.selection.baseOffset : at;
    view.value = TextEditingValue(
      text: view.text.replaceRange(position, position, inserted),
      selection: TextSelection.collapsed(offset: position + inserted.length),
    );
  }

  group('which documents are edited through a window', () {
    test('a small document is edited as a whole', () async {
      await open(_document(100));
      expect(vm.windowed, isNull);
      expect(vm.text.text, _document(100));
    });

    test(
      'a document of kWindowedDocumentCharacters or more is windowed',
      () async {
        final text = _document(7000);
        expect(text.length, greaterThan(kWindowedDocumentCharacters));
        await open(text);
        expect(vm.windowed, isNotNull);
        expect(vm.text.text, text);
        expect(vm.windowed!.view.text.length, lessThan(40000));
      },
    );

    test('opening another document replaces the window', () async {
      await open(_document(7000));
      final first = vm.windowed!;
      final other = _document(8000).replaceAll('line', 'text');
      documents.files['/other.txt'] = encodeText(other, FileEncoding.utf8);
      final generation = vm.editorGeneration;
      unawaited(vm.openDocument());
      await settle();
      (vm.modal! as FileRequest).complete(
        const FileChoice('/other.txt', FileEncoding.utf8),
      );
      await settle();
      expect(vm.text.text, other);
      expect(vm.windowed, isNotNull);
      expect(vm.windowed, isNot(same(first)));
      expect(vm.windowed!.view.text.startsWith('text 000000'), isTrue);
      expect(vm.editorGeneration, greaterThan(generation));
    });

    test(
      'opening a small document after a large one drops the window',
      () async {
        await open(_document(7000));
        documents.files['/small.txt'] = encodeText('hello', FileEncoding.utf8);
        unawaited(vm.openDocument());
        await settle();
        (vm.modal! as FileRequest).complete(
          const FileChoice('/small.txt', FileEncoding.utf8),
        );
        await settle();
        expect(vm.text.text, 'hello');
        expect(vm.windowed, isNull);
      },
    );

    test('a paste that makes a document large starts a window', () async {
      await open(_document(50));
      expect(vm.windowed, isNull);
      final generation = vm.editorGeneration;
      clipboard = _document(8000);
      await vm.paste();
      expect(vm.windowed, isNotNull);
      expect(vm.editorGeneration, greaterThan(generation));
      expect(vm.text.text.length, greaterThan(kWindowedDocumentCharacters));
    });

    test('a document that shrinks goes back to editing as a whole', () async {
      await open(_document(7000));
      expect(vm.windowed, isNotNull);
      vm.selectAll();
      vm.deleteSelection();
      expect(vm.text.text, '');
      expect(vm.windowed, isNull);
    });

    test('a document near the limit does not flip back and forth', () async {
      final text = _document(7000);
      await open(text);
      final window = vm.windowed;
      // Drop just under the size that starts a window, but above the one that ends it.
      final cut = text.length - kWindowedDocumentCharacters + 100;
      vm.text.selection = TextSelection(baseOffset: 0, extentOffset: cut);
      vm.deleteSelection();
      expect(vm.text.text.length, lessThan(kWindowedDocumentCharacters));
      expect(vm.windowed, same(window));
    });
  });

  group('editing', () {
    test(
      'typing in the window changes the document and marks it modified',
      () async {
        final text = _document(7000);
        await open(text);
        expect(vm.isModified, isFalse);
        final caret = _offsetOfLine(text, 3);
        vm.text.selection = TextSelection.collapsed(offset: caret);
        typeInWindow('hello');
        expect(vm.text.text, text.replaceRange(caret, caret, 'hello'));
        expect(vm.isModified, isTrue);
      },
    );

    test('the status bar counts lines in the whole document', () async {
      final text = _document(7000);
      await open(text);
      final target = _offsetOfLine(text, 5000) + 6;
      vm.text.selection = TextSelection.collapsed(offset: target);
      final expected = TextMetrics.caretAt(text, target);
      expect(vm.statusText, 'Ln ${expected.line}, Col ${expected.column}');
      expect(vm.caret.line, 5001);
    });

    test('paste, cut and time and date act on the document', () async {
      final text = _document(7000);
      await open(text);
      final caret = _offsetOfLine(text, 2000);
      vm.text.selection = TextSelection.collapsed(offset: caret);
      clipboard = 'PASTED';
      await vm.paste();
      expect(vm.text.text, text.replaceRange(caret, caret, 'PASTED'));
      expect(vm.windowed!.view.text.contains('PASTED'), isTrue);

      vm.text.selection = TextSelection(
        baseOffset: caret,
        extentOffset: caret + 6,
      );
      await vm.cut();
      expect(vm.text.text, text);
      expect(clipboard, 'PASTED');
    });

    test('select all and copy copies the whole document', () async {
      final text = _document(7000);
      await open(text);
      vm.selectAll();
      await vm.copy();
      expect(clipboard, text);
    });

    test('select all, then typing a letter replaces everything', () async {
      final text = _document(7000);
      await open(text);
      vm.selectAll();
      // The whole window is selected, so a typed letter replaces the window's text.
      vm.windowed!.view.value = const TextEditingValue(
        text: 'q',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(vm.text.text, 'q');
      vm.undo();
      expect(vm.text.text, text);
    });

    test('ctrl+home and ctrl+end go to the ends of the document', () async {
      final text = _document(7000);
      await open(text);
      final reveal = vm.revealSerial.value;
      vm.moveToDocumentEdge(end: true);
      expect(vm.text.selection, TextSelection.collapsed(offset: text.length));
      expect(vm.revealSerial.value, greaterThan(reveal));
      vm.moveToDocumentEdge(end: false, extend: true);
      expect(
        vm.text.selection,
        TextSelection(baseOffset: text.length, extentOffset: 0),
      );
      vm.moveToDocumentEdge(end: false);
      expect(vm.text.selection, const TextSelection.collapsed(offset: 0));
    });
  });

  group('undo', () {
    test('undoes typing, and says so in canUndo', () async {
      final text = _document(7000);
      await open(text);
      expect(vm.canUndo, isFalse);
      final caret = _offsetOfLine(text, 3) + 4;
      vm.text.selection = TextSelection.collapsed(offset: caret);
      typeInWindow('abc');
      expect(vm.canUndo, isTrue);
      final reveal = vm.revealSerial.value;
      vm.undo();
      expect(vm.text.text, text);
      expect(vm.text.selection, TextSelection.collapsed(offset: caret));
      expect(vm.revealSerial.value, greaterThan(reveal));
      expect(vm.canUndo, isFalse);
    });

    test('undoes a paste', () async {
      final text = _document(7000);
      await open(text);
      vm.text.selection = TextSelection.collapsed(
        offset: _offsetOfLine(text, 100),
      );
      clipboard = 'zzz\nzzz';
      await vm.paste();
      expect(vm.text.text, isNot(text));
      vm.undo();
      expect(vm.text.text, text);
    });

    test('undoes a replace all', () async {
      final text = _document(7000);
      await open(text);
      expect(
        vm.replaceAllMatches(const SearchOptions(query: 'line'), 'LINE'),
        isTrue,
      );
      expect(vm.text.text.startsWith('LINE'), isTrue);
      vm.undo();
      expect(vm.text.text, text);
    });
  });

  group('find and go to', () {
    test('find next far from the window selects the match', () async {
      final text = _document(7000);
      await open(text);
      final found = vm.findNext(const SearchOptions(query: 'line 006500 '));
      expect(found, isTrue);
      final start = _offsetOfLine(text, 6500);
      expect(
        vm.text.selection,
        TextSelection(baseOffset: start, extentOffset: start + 12),
      );
    });

    test('go to a line far away puts the caret there', () async {
      final text = _document(7000);
      await open(text);
      vm.goToLine(4321);
      expect(vm.text.selection.baseOffset, _offsetOfLine(text, 4320));
      expect(vm.caret.line, 4321);
    });
  });

  group('saving', () {
    test(
      'saves the whole document with the edits made in the window',
      () async {
        final text = _document(7000);
        await open(text);
        final caret = _offsetOfLine(text, 3);
        vm.text.selection = TextSelection.collapsed(offset: caret);
        typeInWindow('EDIT');
        expect(await vm.save(), isTrue);
        expect(
          documents.writes.single.text,
          text.replaceRange(caret, caret, 'EDIT'),
        );
        expect(vm.isModified, isFalse);
      },
    );
  });
}
