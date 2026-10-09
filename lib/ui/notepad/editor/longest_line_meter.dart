import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/text/text_metrics.dart';

/// Measures the width of the longest line of a text, and remembers the answer for as long
/// as the text and style stay the same objects.
///
/// Laying a line out costs time in proportion to its length, and the text controller also
/// notifies when only the caret or selection moved. Without this, every arrow key in a
/// large document measured the longest line again.
class LongestLineMeter {
  String? _text;
  TextStyle? _style;
  double _width = 0;

  /// How many times a line has actually been laid out. Tests read it to check the cache.
  int computations = 0;

  double measure(String text, TextStyle style) {
    if (identical(text, _text) && style == _style) return _width;
    return _layOut(text, TextMetrics.longestLine(text), style);
  }

  /// The width of [line], which the caller has already found to be the longest. Used when
  /// the whole document is not at hand to search.
  double measureLine(String line, TextStyle style) {
    if (identical(line, _text) && style == _style) return _width;
    return _layOut(line, line, style);
  }

  double _layOut(String key, String line, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: line.isEmpty ? ' ' : line, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    computations++;
    _text = key;
    _style = style;
    _width = width;
    return width;
  }
}
