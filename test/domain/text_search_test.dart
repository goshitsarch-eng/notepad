import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/domain/text/text_search.dart';

void main() {
  group('TextSearch.find', () {
    test('forward search starts at the given offset', () {
      const options = SearchOptions(query: 'bc');
      final first = TextSearch.find('abcabc', options, from: 0);
      expect((first?.start, first?.end), (1, 3));
      final second = TextSearch.find('abcabc', options, from: 2);
      expect((second?.start, second?.end), (4, 6));
      expect(TextSearch.find('abcabc', options, from: 5), isNull);
    });

    test('match case controls case folding', () {
      const insensitive = SearchOptions(query: 'HELLO');
      final match = TextSearch.find('Hello hello', insensitive, from: 0);
      expect((match?.start, match?.end), (0, 5));

      const sensitive = SearchOptions(query: 'HELLO', matchCase: true);
      expect(TextSearch.find('Hello hello', sensitive, from: 0), isNull);
      final lower = TextSearch.find(
        'Hello hello',
        const SearchOptions(query: 'hello', matchCase: true),
        from: 0,
      );
      expect(lower?.start, 6);
    });

    test('whole word skips matches inside longer words', () {
      const options = SearchOptions(query: 'cat', wholeWord: true);
      final match = TextSearch.find('cat catalog cat', options, from: 1);
      expect((match?.start, match?.end), (12, 15));
    });

    test('backward search finds the previous match before the offset', () {
      const options = SearchOptions(query: 'bc', forward: false);
      final first = TextSearch.find('abcabc', options, from: 6);
      expect((first?.start, first?.end), (4, 6));
      final second = TextSearch.find('abcabc', options, from: 4);
      expect((second?.start, second?.end), (1, 3));
      expect(TextSearch.find('abcabc', options, from: 2), isNull);
    });

    test('query characters are matched literally', () {
      final match = TextSearch.find(
        'x (a) y',
        const SearchOptions(query: '(a)'),
        from: 0,
      );
      expect((match?.start, match?.end), (2, 5));
    });

    test('an empty query finds nothing', () {
      expect(TextSearch.find('text', const SearchOptions(), from: 0), isNull);
    });

    test('an offset past the end is clamped instead of throwing', () {
      expect(
        TextSearch.find('abc', const SearchOptions(query: 'a'), from: 99),
        isNull,
      );
    });
  });

  group('TextSearch.replaceAll', () {
    test('replaces every match and counts them', () {
      final result = TextSearch.replaceAll(
        'a-a-a',
        const SearchOptions(query: 'a'),
        'b',
      );
      expect(result.text, 'b-b-b');
      expect(result.count, 3);
    });

    test('whole word leaves embedded matches alone', () {
      const options = SearchOptions(query: 'in', wholeWord: true);
      final result = TextSearch.replaceAll('in inside in', options, 'out');
      expect(result.text, 'out inside out');
      expect(result.count, 2);
    });

    test('reports zero when nothing matches', () {
      final result = TextSearch.replaceAll(
        'abc',
        const SearchOptions(query: 'z'),
        'y',
      );
      expect(result.text, 'abc');
      expect(result.count, 0);
    });
  });
}
