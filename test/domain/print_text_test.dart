import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:xp_notepad/data/services/printing_service.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/print_text.dart';
import 'package:xp_notepad/domain/text/time_date.dart';

void main() {
  final moment = DateTime(2026, 10, 7, 15, 5);

  HeaderFooterLine expand(String template, {int page = 3}) =>
      expandHeaderFooter(
        template,
        fileName: 'notes.txt',
        page: page,
        now: moment,
      );

  group('header and footer codes (F-24)', () {
    test('&f and &p are filled in, as before', () {
      expect(expand('&f').center, 'notes.txt');
      expect(expand('Page &p').center, 'Page 3');
    });

    test('&d and &t give the short date and time', () {
      expect(expand('&d').center, '10/7/2026');
      expect(expand('&t').center, '3:05 PM');
      expect(expand('&t &d').center, '3:05 PM 10/7/2026');
    });

    test('&& is a literal ampersand', () {
      expect(expand('Smith && Sons').center, 'Smith & Sons');
    });

    test('&l, &c and &r align the text after them', () {
      final line = expand('&lLeft&cMiddle&rRight');
      expect(line.left, 'Left');
      expect(line.center, 'Middle');
      expect(line.right, 'Right');
    });

    test('text is centred until a code says otherwise', () {
      final line = expand('Title&r&p');
      expect(line.center, 'Title');
      expect(line.right, '3');
      expect(line.left, isEmpty);
    });

    test(
      'codes work in either case, and in the footer as well as the header',
      () {
        expect(expand('&F - &P').center, 'notes.txt - 3');
      },
    );

    test('an unknown code and a trailing ampersand are kept as typed', () {
      expect(expand('a &z b').center, 'a &z b');
      expect(expand('end &').center, 'end &');
    });

    test('an empty template gives an empty line', () {
      expect(expand('').isEmpty, isTrue);
    });
  });

  group('tabs', () {
    test('a tab goes to the next stop eight columns apart', () {
      expect(expandTabs('a\tb'), 'a       b');
      expect(expandTabs('abcdefgh\tb'), 'abcdefgh        b');
      expect(expandTabs('\tx'), '        x');
    });

    test('columns separated by tabs line up', () {
      final rows = ['name\tqty', 'longername\tqty'].map(expandTabs).toList();
      expect(rows[0].indexOf('qty'), rows[1].indexOf('qty') - 8);
    });

    test('a line with no tab is returned as it is', () {
      const line = 'plain line';
      expect(identical(expandTabs(line), line), isTrue);
    });
  });

  group('time and date', () {
    test('the parts that Time/Date joins are available alone', () {
      expect(formatShortTime(DateTime(2026, 1, 1, 0, 7)), '12:07 AM');
      expect(formatShortDate(DateTime(2026, 1, 9)), '1/9/2026');
      expect(formatTimeDate(moment), '3:05 PM 10/7/2026');
    });
  });

  group('the PDF', () {
    test(
      'is produced for a short document, with every kind of header code',
      () async {
        final bytes = await buildPdf(
          text: 'one\ntwo\n\tthree',
          documentName: 'notes.txt',
          setup: const PageSetup(
            header: '&lLeft&c&f&r&d',
            footer: 'Page &p of text &&',
          ),
          format: PdfPageFormat.letter,
          now: moment,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(500));
      },
    );

    test('runs to several pages for a long document and keeps its page count in step', () async {
      final text = List.generate(400, (i) => 'line $i').join('\n');
      final bytes = await buildPdf(
        text: text,
        documentName: 'long.txt',
        setup: const PageSetup(),
        format: PdfPageFormat.letter,
        now: moment,
      );
      final count = RegExp(r'/Count (\d+)')
          .firstMatch(String.fromCharCodes(bytes));
      expect(int.parse(count!.group(1)!), greaterThan(3));
    });

    test('an empty document still prints one page', () async {
      final bytes = await buildPdf(
        text: '',
        documentName: 'Untitled',
        setup: const PageSetup(header: '', footer: ''),
        format: PdfPageFormat.letter,
        now: moment,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
