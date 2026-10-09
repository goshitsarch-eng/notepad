import 'dart:math' as math;

/// Line and difference arithmetic over plain text, used to edit a large document through a
/// small window of it. Offsets count UTF-16 code units, like every other offset here.
abstract final class TextScan {
  static const _lineFeed = 0x0A;

  /// Start of the line that contains the position [offset]: just after the line feed before
  /// it, or 0. A position right after a line feed starts its own line.
  static int lineStart(String text, int offset) {
    if (offset <= 0) return 0;
    final end = offset > text.length ? text.length : offset;
    final feed = text.lastIndexOf('\n', end - 1);
    return feed < 0 ? 0 : feed + 1;
  }

  /// End of the line that contains the position [offset]: the index of the next line feed, or
  /// the length of the text.
  static int lineEnd(String text, int offset) {
    if (offset >= text.length) return text.length;
    final feed = text.indexOf('\n', offset < 0 ? 0 : offset);
    return feed < 0 ? text.length : feed;
  }

  /// The start of the line [characters] before [offset], or the start of the text.
  static int lineStartBefore(String text, int offset, int characters) =>
      lineStart(text, math.max(0, offset - characters));

  /// The end of the line [characters] after [offset], or the end of the text.
  static int lineEndAfter(String text, int offset, int characters) =>
      lineEnd(text, math.min(text.length, offset + characters));

  /// How many line feeds lie in [start, end).
  static int lineFeeds(String text, int start, int end) {
    var count = 0;
    final stop = end > text.length ? text.length : end;
    for (var i = start < 0 ? 0 : start; i < stop; i++) {
      if (text.codeUnitAt(i) == _lineFeed) count++;
    }
    return count;
  }

  /// The smallest span of [before] that has to be replaced to get [after].
  static TextChange diff(String before, String after) {
    final shortest = math.min(before.length, after.length);
    var prefix = 0;
    while (prefix < shortest &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    final room = shortest - prefix;
    while (suffix < room &&
        before.codeUnitAt(before.length - 1 - suffix) ==
            after.codeUnitAt(after.length - 1 - suffix)) {
      suffix++;
    }
    return TextChange(
      start: prefix,
      oldEnd: before.length - suffix,
      newEnd: after.length - suffix,
    );
  }
}

/// One replacement: the span [start, oldEnd) of the old text became [start, newEnd) of
/// the new text.
class TextChange {
  const TextChange({
    required this.start,
    required this.oldEnd,
    required this.newEnd,
  });

  final int start;
  final int oldEnd;
  final int newEnd;

  bool get isEmpty => start == oldEnd && start == newEnd;

  int get removedLength => oldEnd - start;

  int get insertedLength => newEnd - start;
}
