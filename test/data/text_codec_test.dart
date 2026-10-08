import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('detectEncoding', () {
    test('byte order marks decide first', () {
      expect(
        detectEncoding(_bytes([0xFF, 0xFE, 0x41, 0x00])),
        FileEncoding.unicode,
      );
      expect(
        detectEncoding(_bytes([0xFE, 0xFF, 0x00, 0x41])),
        FileEncoding.unicodeBigEndian,
      );
      expect(
        detectEncoding(_bytes([0xEF, 0xBB, 0xBF, 0x41])),
        FileEncoding.utf8,
      );
    });

    test('plain ASCII is ANSI, the XP default', () {
      expect(detectEncoding(_bytes(utf8.encode('hello'))), FileEncoding.ansi);
    });

    test('valid UTF-8 with non-ASCII bytes is UTF-8', () {
      expect(detectEncoding(_bytes(utf8.encode('café'))), FileEncoding.utf8);
    });

    test('invalid UTF-8 with high bytes falls back to ANSI', () {
      expect(
        detectEncoding(_bytes([0x63, 0x61, 0x66, 0xE9])),
        FileEncoding.ansi,
      );
    });
  });

  group('ANSI (Windows-1252)', () {
    test('decodes the 0x80 to 0x9F range through the cp1252 table', () {
      expect(decodeText(_bytes([0x41, 0x80, 0xE9]), FileEncoding.ansi), 'A€é');
      expect(decodeText(_bytes([0x93, 0x94]), FileEncoding.ansi), '“”');
    });

    test('encodes table characters and writes ? for characters ANSI lacks', () {
      expect(encodeText('€é', FileEncoding.ansi), _bytes([0x80, 0xE9]));
      expect(encodeText('中', FileEncoding.ansi), _bytes([0x3F]));
    });
  });

  group('canEncodeAnsi', () {
    test('accepts text that Windows-1252 can hold', () {
      expect(canEncodeAnsi('café € “quoted”'), isTrue);
    });

    test('rejects characters outside Windows-1252', () {
      expect(canEncodeAnsi('中文'), isFalse);
      expect(canEncodeAnsi('smile 😀'), isFalse);
    });
  });

  group('line endings', () {
    test('CRLF on disk becomes LF in the editor and back', () {
      expect(
        decodeText(_bytes(utf8.encode('a\r\nb')), FileEncoding.ansi),
        'a\nb',
      );
      expect(
        encodeText('a\nb', FileEncoding.ansi),
        _bytes(utf8.encode('a\r\nb')),
      );
    });
  });

  group('UTF-16 and UTF-8 round trips', () {
    const sample = 'héllo\nwörld 😀';

    test('Unicode (UTF-16 LE) writes FF FE and reads back', () {
      final bytes = encodeText(sample, FileEncoding.unicode);
      expect(bytes.sublist(0, 2), _bytes([0xFF, 0xFE]));
      final file = readText(bytes);
      expect(file.encoding, FileEncoding.unicode);
      expect(file.text, sample);
    });

    test('Unicode big endian writes FE FF and reads back', () {
      final bytes = encodeText(sample, FileEncoding.unicodeBigEndian);
      expect(bytes.sublist(0, 2), _bytes([0xFE, 0xFF]));
      final file = readText(bytes);
      expect(file.encoding, FileEncoding.unicodeBigEndian);
      expect(file.text, sample);
    });

    test('UTF-8 writes a byte order mark and reads back', () {
      final bytes = encodeText(sample, FileEncoding.utf8);
      expect(bytes.sublist(0, 3), _bytes([0xEF, 0xBB, 0xBF]));
      final file = readText(bytes);
      expect(file.encoding, FileEncoding.utf8);
      expect(file.text, sample);
    });
  });

  group('damaged UTF-16', () {
    test('a trailing odd byte shows as U+FFFD instead of being dropped', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x61, 0x00, 0x41]);
      final file = readText(bytes);
      expect(file.encoding, FileEncoding.unicode);
      expect(file.text, 'a\uFFFD');
    });

    test('a complete UTF-16 file has no replacement character', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x61, 0x00]);
      expect(readText(bytes).text, 'a');
    });
  });
}
