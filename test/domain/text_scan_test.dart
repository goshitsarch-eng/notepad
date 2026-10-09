import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';
import 'package:xp_notepad/domain/text/text_scan.dart';

void main() {
  group('lineStart and lineEnd', () {
    const text = 'one\ntwo\n\nfour';

    test('a position inside a line belongs to that line', () {
      expect(TextScan.lineStart(text, 5), 4);
      expect(TextScan.lineEnd(text, 5), 7);
    });

    test('a position right after a line feed starts its own line', () {
      expect(TextScan.lineStart(text, 4), 4);
      expect(TextScan.lineStart(text, 8), 8);
    });

    test('a position right before a line feed is the end of its line', () {
      expect(TextScan.lineEnd(text, 3), 3);
      expect(TextScan.lineEnd(text, 7), 7);
    });

    test('an empty line starts and ends at the same place', () {
      expect(TextScan.lineStart(text, 8), 8);
      expect(TextScan.lineEnd(text, 8), 8);
    });

    test('the ends of the text and positions outside it are clamped', () {
      expect(TextScan.lineStart(text, 0), 0);
      expect(TextScan.lineStart(text, -5), 0);
      expect(TextScan.lineEnd(text, text.length), text.length);
      expect(TextScan.lineEnd(text, text.length + 9), text.length);
      expect(TextScan.lineStart(text, text.length + 9), 9);
      expect(TextScan.lineEnd(text, 9), text.length);
    });

    test('moving by characters lands on a line boundary', () {
      expect(TextScan.lineStartBefore(text, 6, 1), 4);
      expect(TextScan.lineStartBefore(text, 6, 3), 0);
      expect(TextScan.lineStartBefore(text, 6, 100), 0);
      expect(TextScan.lineEndAfter(text, 1, 3), 7);
      expect(TextScan.lineEndAfter(text, 1, 100), text.length);
    });
  });

  group('lineFeeds', () {
    test('counts the line feeds in a span', () {
      const text = 'a\nb\nc\n';
      expect(TextScan.lineFeeds(text, 0, text.length), 3);
      expect(TextScan.lineFeeds(text, 2, 4), 1);
      expect(TextScan.lineFeeds(text, 0, 1), 0);
      expect(TextScan.lineFeeds(text, 3, 99), 2);
      expect(TextScan.lineFeeds(text, -4, 2), 1);
    });
  });

  group('diff', () {
    String apply(String before, TextChange change, String after) =>
        before.replaceRange(
          change.start,
          change.oldEnd,
          after.substring(change.start, change.newEnd),
        );

    test('finds an insertion, a deletion and a replacement', () {
      const cases = [
        ['hello world', 'hello big world'],
        ['hello big world', 'hello world'],
        ['hello world', 'hello there'],
        ['abc', 'abc'],
        ['', 'abc'],
        ['abc', ''],
        ['aaaa', 'aaaaa'],
        ['aaaaa', 'aaaa'],
        ['abcabc', 'abcxabc'],
        ['x\ny\nz', 'x\nz'],
      ];
      for (final c in cases) {
        final change = TextScan.diff(c[0], c[1]);
        expect(apply(c[0], change, c[1]), c[1], reason: '${c[0]} -> ${c[1]}');
      }
    });

    test('keeps the changed span small', () {
      final change = TextScan.diff('hello world', 'hello big world');
      expect(change.removedLength, 0);
      expect(change.insertedLength, 4);
      expect(TextScan.diff('same', 'same').isEmpty, isTrue);
    });
  });

  group('agrees with TextMetrics', () {
    test('line counts and carets over a text with long and empty lines', () {
      final text = List.generate(
        200,
        (i) => i % 7 == 0 ? '' : 'line $i ${'x' * (i % 13)}',
      ).join('\n');
      for (var offset = 0; offset <= text.length; offset += 17) {
        final caret = TextMetrics.caretAt(text, offset);
        expect(
          TextScan.lineFeeds(text, 0, offset) + 1,
          caret.line,
          reason: 'line at $offset',
        );
        expect(
          offset - TextScan.lineStart(text, offset) + 1,
          caret.column,
          reason: 'column at $offset',
        );
      }
    });
  });
}
