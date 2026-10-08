import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';

void main() {
  group('TextMetrics.caretAt', () {
    test('reports 1-based line and column', () {
      final origin = TextMetrics.caretAt('ab\ncd', 0);
      expect((origin.line, origin.column), (1, 1));
      final afterC = TextMetrics.caretAt('ab\ncd', 4);
      expect((afterC.line, afterC.column), (2, 2));
    });

    test('clamps offsets outside the text', () {
      final past = TextMetrics.caretAt('ab', 99);
      expect((past.line, past.column), (1, 3));
      final negative = TextMetrics.caretAt('ab', -1);
      expect((negative.line, negative.column), (1, 1));
    });
  });

  group('TextMetrics lines', () {
    test('lineCount counts line feeds plus one', () {
      expect(TextMetrics.lineCount(''), 1);
      expect(TextMetrics.lineCount('a\nb\n'), 3);
    });

    test('lineStart resolves a 1-based line and clamps past the end', () {
      const text = 'a\nbc\nd';
      expect(TextMetrics.lineStart(text, 1), 0);
      expect(TextMetrics.lineStart(text, 2), 2);
      expect(TextMetrics.lineStart(text, 3), 5);
      expect(TextMetrics.lineStart(text, 99), 5);
    });

    test('longestLine returns the widest line without its line feed', () {
      expect(TextMetrics.longestLine('ab\ncdef\ng'), 'cdef');
      expect(TextMetrics.longestLine(''), '');
    });
  });
}
