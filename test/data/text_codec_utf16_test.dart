import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';

/// UTF-16 text with no byte order mark, which some programs write, and opening a file as
/// a chosen encoding. A file that can be told from its bytes is read as what it is. For
/// the rest the Open dialog lets the user say.
Uint8List _utf16(String text, {required bool bigEndian, bool bom = false}) {
  final units = text.codeUnits;
  final data = ByteData((bom ? 2 : 0) + units.length * 2);
  final endian = bigEndian ? Endian.big : Endian.little;
  var at = 0;
  if (bom) {
    data.setUint16(0, 0xFEFF, endian);
    at = 2;
  }
  for (final unit in units) {
    data.setUint16(at, unit, endian);
    at += 2;
  }
  return data.buffer.asUint8List();
}

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

const _english = 'The quick brown fox jumps over the lazy dog.\nSecond line.\n';

void main() {
  group('detectEncoding finds UTF-16 without a byte order mark', () {
    test('little endian English text', () {
      expect(
        detectEncoding(_utf16(_english, bigEndian: false)),
        FileEncoding.unicode,
      );
    });

    test('big endian English text', () {
      expect(
        detectEncoding(_utf16(_english, bigEndian: true)),
        FileEncoding.unicodeBigEndian,
      );
    });

    test('Cyrillic and accented text, which has fewer zero bytes', () {
      const text = 'Привет, мир! Это проверка текста.\nÉcole, café, naïve.\n';
      expect(
        detectEncoding(_utf16(text, bigEndian: false)),
        FileEncoding.unicode,
      );
      expect(
        detectEncoding(_utf16(text, bigEndian: true)),
        FileEncoding.unicodeBigEndian,
      );
    });

    test('with Windows line ends, which are control characters too', () {
      final text = _english.replaceAll('\n', '\r\n');
      expect(
        detectEncoding(_utf16(text, bigEndian: false)),
        FileEncoding.unicode,
      );
    });

    test('where the first look ends in the middle of a surrogate pair', () {
      // The emoji's two halves lie either side of the 4096 bytes that are examined.
      final text = '${'a' * 2047}😀${'b' * 100}';
      final bytes = _utf16(text, bigEndian: false);
      expect(bytes.length, greaterThan(4096));
      expect(detectEncoding(bytes), FileEncoding.unicode);
    });

    test('a short text', () {
      expect(
        detectEncoding(_utf16('Hi!', bigEndian: false)),
        FileEncoding.unicode,
      );
      expect(
        detectEncoding(_utf16('ab', bigEndian: true)),
        FileEncoding.unicodeBigEndian,
      );
    });

    test('a long file is judged from its start', () {
      final text = '$_english${'more text here\n' * 5000}';
      expect(
        detectEncoding(_utf16(text, bigEndian: false)),
        FileEncoding.unicode,
      );
    });

    test('and decodes to the same text', () {
      final file = readText(_utf16(_english, bigEndian: false));
      expect(file.encoding, FileEncoding.unicode);
      expect(file.text, _english);
      final big = readText(_utf16(_english, bigEndian: true));
      expect(big.encoding, FileEncoding.unicodeBigEndian);
      expect(big.text, _english);
    });
  });

  group('detectEncoding does not mistake other files for UTF-16', () {
    test('plain ANSI, UTF-8 and empty files', () {
      expect(detectEncoding(Uint8List(0)), FileEncoding.ansi);
      expect(detectEncoding(_bytes([0x41])), FileEncoding.ansi);
      expect(detectEncoding(_bytes(utf8.encode(_english))), FileEncoding.ansi);
      expect(
        detectEncoding(_bytes(utf8.encode('Привет, мир, как дела?'))),
        FileEncoding.utf8,
      );
      expect(
        detectEncoding(_bytes([0x63, 0x61, 0x66, 0xE9, 0x20, 0x6F, 0x6E])),
        FileEncoding.ansi,
      );
    });

    test('a text with a few stray zero bytes', () {
      final bytes = List<int>.from(utf8.encode(_english * 40));
      bytes[100] = 0;
      bytes[501] = 0;
      expect(detectEncoding(_bytes(bytes)), FileEncoding.ansi);
    });

    test('data with zero bytes at both kinds of places', () {
      final bytes = List<int>.generate(
        2000,
        (i) => i % 3 == 0 ? 0 : 0x41 + i % 20,
      );
      expect(detectEncoding(_bytes(bytes)), FileEncoding.ansi);
    });

    test('UTF-32, whose zero bytes are not at one kind of place', () {
      final bytes = <int>[];
      for (final unit in _english.codeUnits) {
        bytes.addAll([unit, 0, 0, 0]);
      }
      expect(detectEncoding(_bytes(bytes)), FileEncoding.ansi);
    });

    test('a run of zero bytes', () {
      expect(detectEncoding(Uint8List(64)), FileEncoding.ansi);
    });

    test('UTF-16 that is not well formed is left alone', () {
      // A lone high surrogate in the middle of English text.
      final units = [..._english.codeUnits, 0xD800, ..._english.codeUnits];
      final data = ByteData(units.length * 2);
      for (var i = 0; i < units.length; i++) {
        data.setUint16(i * 2, units[i], Endian.little);
      }
      expect(detectEncoding(data.buffer.asUint8List()), FileEncoding.ansi);
    });

    test('text with control characters that no text file has', () {
      final text = 'Some English text\x1B[31m in colour.\n';
      expect(detectEncoding(_utf16(text, bigEndian: false)), FileEncoding.ansi);
    });

    test('files with a byte order mark are unchanged', () {
      expect(
        detectEncoding(_utf16(_english, bigEndian: false, bom: true)),
        FileEncoding.unicode,
      );
      expect(
        detectEncoding(_utf16(_english, bigEndian: true, bom: true)),
        FileEncoding.unicodeBigEndian,
      );
    });
  });

  group('readText with a chosen encoding', () {
    test('reads a file with no byte order mark as the encoding asked for', () {
      // Japanese text in UTF-16 has hardly any zero bytes, so it cannot be recognised.
      const text = '日本語のテキストです。\n';
      final bytes = _utf16(text, bigEndian: false);
      expect(detectEncoding(bytes), isNot(FileEncoding.unicode));
      final file = readText(bytes, encoding: FileEncoding.unicode);
      expect(file.encoding, FileEncoding.unicode);
      expect(file.text, text);
    });

    test('a byte order mark wins over the choice, as in XP', () {
      final bytes = _utf16(_english, bigEndian: true, bom: true);
      final file = readText(bytes, encoding: FileEncoding.ansi);
      expect(file.encoding, FileEncoding.unicodeBigEndian);
      expect(file.text, _english);
    });

    test('ANSI can be forced on a UTF-8 file, which then shows its bytes', () {
      final bytes = _bytes(utf8.encode('café'));
      expect(readText(bytes).text, 'café');
      final forced = readText(bytes, encoding: FileEncoding.ansi);
      expect(forced.encoding, FileEncoding.ansi);
      expect(forced.text, 'cafÃ©');
    });

    test('UTF-8 can be forced on a file that does not look like it', () {
      final bytes = _bytes([0x61, 0x62, 0x63]);
      final file = readText(bytes, encoding: FileEncoding.utf8);
      expect(file.encoding, FileEncoding.utf8);
      expect(file.text, 'abc');
    });

    test('no choice detects as before', () {
      final bytes = _bytes(utf8.encode('café'));
      expect(readText(bytes).encoding, FileEncoding.utf8);
    });
  });
}
