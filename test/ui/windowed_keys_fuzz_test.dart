import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';

import '../support/fakes.dart';

String _line(int i) =>
    'line ${i.toString().padLeft(6, '0')} ${'abcdefghij' * (i % 3)}';

String _document(int lines) => List.generate(lines, _line).join('\n');

/// Random keys, scrolling, clicks and typing through the real text box of a large
/// document. The text may change only the way the keys that were typed say. The tests of
/// WindowedText alone cannot find a key that Flutter's own actions answer with a stale
/// copy of the window, which is how holding Down once overwrote part of a document.
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
    WidgetTester tester,
    String text, {
    required bool wordWrap,
  }) async {
    tester.view
      ..physicalSize = const Size(700, 404)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final documents = FakeDocumentRepository()
      ..files['/big.txt'] = encodeText(text, FileEncoding.utf8);
    await tester.pumpWidget(
      XpNotepadApp(
        dependencies: AppDependencies(
          documents: documents,
          settings: FakeSettingsRepository(),
          fileSystem: FakeFileSystemService(),
          printing: FakePrintingService(),
          window: FakeWindowService(),
        ),
        settings: NotepadSettings(wordWrap: wordWrap),
        initialPath: '/big.txt',
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    return Provider.of<NotepadViewModel>(
      tester.element(find.byType(NotepadScreen)),
      listen: false,
    );
  }

  const navigation = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
  ];

  Future<void> frames(WidgetTester tester, [int count = 2]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump();
    }
  }

  for (final wordWrap in [false, true]) {
    for (var seed = 0; seed < 6; seed++) {
      testWidgets('random keys never change the text but as typed (seed $seed, '
          '${wordWrap ? 'word wrap' : 'no wrap'})', (tester) async {
        final random = math.Random(seed * 7919 + (wordWrap ? 1 : 0));
        var model = _document(7000);
        final vm = await pumpNotepad(tester, model, wordWrap: wordWrap);
        expect(vm.windowed, isNotNull);
        await tester.tapAt(const Offset(300, 200));
        await frames(tester);
        // Where the click put the caret decides where typing starts.
        final log = <String>[];

        for (var step = 0; step < 90; step++) {
          final choice = random.nextInt(100);
          if (choice < 40) {
            // A key that moves the caret, held down for a while or pressed once.
            final key = navigation[random.nextInt(navigation.length)];
            final times = random.nextInt(4) == 0 ? 1 + random.nextInt(25) : 1;
            final shift = random.nextInt(5) == 0;
            log.add('${key.keyLabel} x$times${shift ? ' +shift' : ''}');
            if (shift) {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
            }
            for (var i = 0; i < times; i++) {
              await tester.sendKeyEvent(key);
              // Sometimes the next key comes before the frame that builds the box.
              if (random.nextInt(3) != 0) await tester.pump();
            }
            if (shift) {
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
            }
          } else if (choice < 55) {
            final position = tester
                .state<ScrollableState>(
                  find
                      .byWidgetPredicate(
                        (w) => w is Scrollable && w.axis == Axis.vertical,
                      )
                      .first,
                )
                .position;
            final target = random.nextDouble() * position.maxScrollExtent;
            log.add(
              'scroll to ${target.round()} of ${position.maxScrollExtent.round()}',
            );
            position.jumpTo(target);
          } else if (choice < 65) {
            final x = 20.0 + random.nextInt(600);
            final y = 60.0 + random.nextInt(280);
            log.add('tap $x,$y');
            await tester.tapAt(Offset(x, y));
          } else if (choice < 85) {
            // Typing a letter. The key goes first, as it does on a keyboard, and it
            // brings the window back to a caret that was scrolled away from.
            final window = vm.windowed!;
            await tester.sendKeyDownEvent(
              LogicalKeyboardKey.keyQ,
              character: 'q',
            );
            await frames(tester);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
            if (window.selectionClamped) {
              log.add(
                'typing skipped: the selection reaches outside the window',
              );
            } else {
              final selection = vm.text.selection;
              final view = window.view.value;
              final from = view.selection.start;
              final to = view.selection.end;
              final typed = view.text.replaceRange(from, to, 'q');
              log.add('type q over ${selection.start}-${selection.end}');
              tester.testTextInput.updateEditingValue(
                TextEditingValue(
                  text: typed,
                  selection: TextSelection.collapsed(offset: from + 1),
                ),
              );
              model = model.replaceRange(selection.start, selection.end, 'q');
            }
          } else {
            final window = vm.windowed!;
            final backspace = random.nextBool();
            final key = backspace
                ? LogicalKeyboardKey.backspace
                : LogicalKeyboardKey.delete;
            log.add(backspace ? 'backspace' : 'delete');
            // A key that edits brings the window back to the caret first, as the editor
            // does, and then edits.
            if (window.caretOutside) {
              window.teleportTo(vm.text.selection.extentOffset);
              await frames(tester);
            }
            final selection = vm.text.selection;
            if (!window.selectionClamped &&
                selection.isValid &&
                !_atWindowEdge(window, selection)) {
              await tester.sendKeyEvent(key);
              var from = selection.start;
              var to = selection.end;
              if (selection.isCollapsed) {
                if (backspace) {
                  if (from == 0) continue;
                  from -= 1;
                } else {
                  if (to >= model.length) continue;
                  to += 1;
                }
              }
              model = model.replaceRange(from, to, '');
            }
          }
          await frames(tester);
          if (vm.text.text.length != model.length || vm.text.text != model) {
            fail(
              'step $step (${log.last}): the text is ${vm.text.text.length} '
              'characters, expected ${model.length}.\nSteps so far:\n'
              '${log.join('\n')}',
            );
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

/// True when the caret is so close to an edge of the window that a key which deletes
/// would have to act on text the window does not hold.
bool _atWindowEdge(WindowedText window, TextSelection selection) {
  return selection.start <= window.start + 1 || selection.end >= window.end - 1;
}
