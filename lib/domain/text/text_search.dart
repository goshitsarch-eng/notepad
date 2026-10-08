import 'dart:math' as math;

/// A matched span [start, end) in UTF-16 code units.
class MatchRange {
  const MatchRange(this.start, this.end);

  final int start;
  final int end;
}

/// What Find, Find Next, Replace and Replace All look for.
class SearchOptions {
  const SearchOptions({
    this.query = '',
    this.matchCase = false,
    this.wholeWord = false,
    this.forward = true,
  });

  final String query;
  final bool matchCase;
  final bool wholeWord;
  final bool forward;

  SearchOptions copyWith({
    String? query,
    bool? matchCase,
    bool? wholeWord,
    bool? forward,
  }) {
    return SearchOptions(
      query: query ?? this.query,
      matchCase: matchCase ?? this.matchCase,
      wholeWord: wholeWord ?? this.wholeWord,
      forward: forward ?? this.forward,
    );
  }
}

/// The text after [TextSearch.replaceAll] and how many matches were replaced.
class ReplaceAllResult {
  const ReplaceAllResult(this.text, this.count);

  final String text;
  final int count;
}

/// Plain-text search with XP's Find options. Pure Dart, so it is unit tested directly.
abstract final class TextSearch {
  static final _wordCharacter = RegExp(r'[\p{L}\p{N}_]', unicode: true);

  /// Finds the next match, or the previous one when [SearchOptions.forward] is false.
  /// Forward searches look at or after [from]; backward searches end at or before it.
  /// Like XP Notepad, the search stops at the ends of the document and does not wrap.
  static MatchRange? find(
    String text,
    SearchOptions options, {
    required int from,
  }) {
    if (options.query.isEmpty) return null;
    final pattern = _pattern(options);
    final start = math.min(math.max(from, 0), text.length);
    if (options.forward) {
      for (final match in pattern.allMatches(text, start)) {
        if (_isAcceptable(text, match.start, match.end, options)) {
          return MatchRange(match.start, match.end);
        }
      }
      return null;
    }
    MatchRange? previous;
    for (final match in pattern.allMatches(text)) {
      if (match.end > start) break;
      if (_isAcceptable(text, match.start, match.end, options)) {
        previous = MatchRange(match.start, match.end);
      }
    }
    return previous;
  }

  /// Replaces every acceptable match in [text] with [replacement].
  static ReplaceAllResult replaceAll(
    String text,
    SearchOptions options,
    String replacement,
  ) {
    if (options.query.isEmpty) return ReplaceAllResult(text, 0);
    final buffer = StringBuffer();
    var copiedUpTo = 0;
    var count = 0;
    for (final match in _pattern(options).allMatches(text)) {
      if (!_isAcceptable(text, match.start, match.end, options)) continue;
      buffer
        ..write(text.substring(copiedUpTo, match.start))
        ..write(replacement);
      copiedUpTo = match.end;
      count++;
    }
    if (count == 0) return ReplaceAllResult(text, 0);
    buffer.write(text.substring(copiedUpTo));
    return ReplaceAllResult(buffer.toString(), count);
  }

  static RegExp _pattern(SearchOptions options) {
    return RegExp(
      RegExp.escape(options.query),
      caseSensitive: options.matchCase,
    );
  }

  static bool _isAcceptable(
    String text,
    int start,
    int end,
    SearchOptions options,
  ) {
    if (!options.wholeWord) return true;
    final before = start > 0 && _wordCharacter.hasMatch(text[start - 1]);
    final after = end < text.length && _wordCharacter.hasMatch(text[end]);
    return !before && !after;
  }
}
