/// Encodings Notepad can save, in the order the Save As "Encoding" list shows them.
enum FileEncoding {
  ansi('ANSI'),
  unicode('Unicode'),
  unicodeBigEndian('Unicode big endian'),
  utf8('UTF-8');

  const FileEncoding(this.label);

  final String label;
}
