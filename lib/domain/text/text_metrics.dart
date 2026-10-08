/// 1-based line and column of a caret, as the status bar shows them.
class CaretPosition {
  const CaretPosition(this.line, this.column);

  final int line;
  final int column;
}

/// Line and offset arithmetic over plain text. Offsets count UTF-16 code units.
abstract final class TextMetrics {
  static const _lineFeed = 0x0A;

  static CaretPosition caretAt(String text, int offset) {
    final end = offset < 0 ? 0 : (offset > text.length ? text.length : offset);
    var line = 1;
    var lineStart = 0;
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == _lineFeed) {
        line++;
        lineStart = i + 1;
      }
    }
    return CaretPosition(line, end - lineStart + 1);
  }

  static int lineCount(String text) {
    var count = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == _lineFeed) count++;
    }
    return count;
  }

  /// Offset where [line] (1-based) starts. Lines past the end resolve to the last line.
  static int lineStart(String text, int line) {
    var current = 1;
    var offset = 0;
    while (current < line) {
      final next = text.indexOf('\n', offset);
      if (next < 0) break;
      offset = next + 1;
      current++;
    }
    return offset;
  }

  /// The longest line of [text], without its line feed.
  static String longestLine(String text) {
    var bestStart = 0;
    var bestEnd = 0;
    var start = 0;
    while (true) {
      final newline = text.indexOf('\n', start);
      final end = newline < 0 ? text.length : newline;
      if (end - start > bestEnd - bestStart) {
        bestStart = start;
        bestEnd = end;
      }
      if (newline < 0) break;
      start = newline + 1;
    }
    return text.substring(bestStart, bestEnd);
  }
}
