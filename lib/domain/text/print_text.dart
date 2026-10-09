import 'package:xp_notepad/domain/text/time_date.dart';

/// A header or footer line after its codes are filled in, split by alignment.
class HeaderFooterLine {
  const HeaderFooterLine({this.left = '', this.center = '', this.right = ''});

  final String left;
  final String center;
  final String right;

  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty;
}

/// Fills in the codes Notepad's Page Setup accepts in a header or footer:
/// `&f` the file name, `&p` the page number, `&d` the date, `&t` the time, `&&` an
/// ampersand, and `&l`, `&c` and `&r`, which align the text after them left, centre or
/// right. Text is centred until a code says otherwise. Codes may be upper or lower case.
/// An `&` followed by anything else is kept as typed.
HeaderFooterLine expandHeaderFooter(
  String template, {
  required String fileName,
  required int page,
  required DateTime now,
}) {
  final sections = {
    'l': StringBuffer(),
    'c': StringBuffer(),
    'r': StringBuffer(),
  };
  var current = sections['c']!;
  var i = 0;
  while (i < template.length) {
    final char = template[i];
    if (char != '&' || i + 1 >= template.length) {
      current.write(char);
      i++;
      continue;
    }
    final code = template[i + 1];
    switch (code.toLowerCase()) {
      case 'f':
        current.write(fileName);
      case 'p':
        current.write(page);
      case 'd':
        current.write(formatShortDate(now));
      case 't':
        current.write(formatShortTime(now));
      case '&':
        current.write('&');
      case 'l' || 'c' || 'r':
        current = sections[code.toLowerCase()]!;
      default:
        current.write('&$code');
    }
    i += 2;
  }
  return HeaderFooterLine(
    left: sections['l'].toString(),
    center: sections['c'].toString(),
    right: sections['r'].toString(),
  );
}

/// Replaces each tab in [line] with spaces up to the next tab stop, [tabWidth] columns
/// apart, so tab-separated columns line up in the monospaced printout as they do on screen.
String expandTabs(String line, {int tabWidth = 8}) {
  if (!line.contains('\t')) return line;
  final out = StringBuffer();
  var column = 0;
  for (final unit in line.runes) {
    if (unit == 0x09) {
      final spaces = tabWidth - column % tabWidth;
      out.write(' ' * spaces);
      column += spaces;
    } else {
      out.writeCharCode(unit);
      column++;
    }
  }
  return out.toString();
}
