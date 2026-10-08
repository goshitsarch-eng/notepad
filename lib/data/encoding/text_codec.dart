import 'dart:convert';
import 'dart:typed_data';

import 'package:xp_notepad/domain/models/file_encoding.dart';

/// A file that has been read: its text (with LF line ends) and the encoding it used.
class TextFile {
  const TextFile(this.text, this.encoding);

  final String text;
  final FileEncoding encoding;
}

/// Windows-1252 characters for bytes 0x80 to 0x9F. Undefined bytes map to themselves.
const _cp1252High = <int>[
  0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, //
  0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178, //
];

final _cp1252Reverse = {
  for (var i = 0; i < _cp1252High.length; i++) _cp1252High[i]: 0x80 + i,
};

/// Reads [bytes], detecting the encoding the way Notepad does: byte order marks first,
/// then valid UTF-8 that has non-ASCII bytes, and ANSI (Windows-1252) otherwise.
TextFile readText(Uint8List bytes) {
  final encoding = detectEncoding(bytes);
  return TextFile(decodeText(bytes, encoding), encoding);
}

FileEncoding detectEncoding(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return FileEncoding.unicode;
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return FileEncoding.unicodeBigEndian;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return FileEncoding.utf8;
  }
  if (_hasHighByte(bytes) && _isValidUtf8(bytes)) return FileEncoding.utf8;
  return FileEncoding.ansi;
}

/// Decodes [bytes] as [encoding], skipping a matching byte order mark, and converts
/// CRLF line ends to LF for the editor.
String decodeText(Uint8List bytes, FileEncoding encoding) {
  final text = switch (encoding) {
    FileEncoding.ansi => _decodeAnsi(bytes),
    FileEncoding.unicode => _decodeUtf16(bytes, bigEndian: false),
    FileEncoding.unicodeBigEndian => _decodeUtf16(bytes, bigEndian: true),
    FileEncoding.utf8 => utf8.decode(_skipUtf8Bom(bytes), allowMalformed: true),
  };
  return text.replaceAll('\r\n', '\n');
}

/// True when every character of [text] exists in Windows-1252, so ANSI can hold it unchanged.
bool canEncodeAnsi(String text) {
  for (final rune in text.runes) {
    if (rune < 0x80 || (rune >= 0xA0 && rune <= 0xFF)) continue;
    if (_cp1252Reverse.containsKey(rune)) continue;
    return false;
  }
  return true;
}

/// Encodes [text] for [encoding] with a byte order mark where XP writes one, and CRLF
/// line ends. Characters ANSI cannot hold are written as '?', as Notepad does.
Uint8List encodeText(String text, FileEncoding encoding) {
  final crlf = text.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
  return switch (encoding) {
    FileEncoding.ansi => _encodeAnsi(crlf),
    FileEncoding.unicode => _encodeUtf16(crlf, bigEndian: false),
    FileEncoding.unicodeBigEndian => _encodeUtf16(crlf, bigEndian: true),
    FileEncoding.utf8 => Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(crlf),
    ]),
  };
}

bool _hasHighByte(Uint8List bytes) {
  for (final byte in bytes) {
    if (byte >= 0x80) return true;
  }
  return false;
}

bool _isValidUtf8(Uint8List bytes) {
  try {
    utf8.decode(bytes);
    return true;
  } on FormatException {
    return false;
  }
}

Uint8List _skipUtf8Bom(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  return hasBom ? Uint8List.sublistView(bytes, 3) : bytes;
}

String _decodeAnsi(Uint8List bytes) {
  final units = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final byte = bytes[i];
    units[i] = byte >= 0x80 && byte < 0xA0 ? _cp1252High[byte - 0x80] : byte;
  }
  return String.fromCharCodes(units);
}

String _decodeUtf16(Uint8List bytes, {required bool bigEndian}) {
  final hasBom =
      bytes.length >= 2 &&
      (bigEndian
          ? bytes[0] == 0xFE && bytes[1] == 0xFF
          : bytes[0] == 0xFF && bytes[1] == 0xFE);
  final start = hasBom ? 2 : 0;
  final data = ByteData.sublistView(bytes);
  final count = (bytes.length - start) ~/ 2;
  final oddByte = (bytes.length - start).isOdd;
  // A final byte with no partner is shown as U+FFFD, so the file's damage is visible.
  final units = Uint16List(oddByte ? count + 1 : count);
  final endian = bigEndian ? Endian.big : Endian.little;
  for (var i = 0; i < count; i++) {
    units[i] = data.getUint16(start + i * 2, endian);
  }
  if (oddByte) units[count] = 0xFFFD;
  return String.fromCharCodes(units);
}

Uint8List _encodeAnsi(String text) {
  final bytes = <int>[];
  for (final rune in text.runes) {
    if (rune < 0x80 || (rune >= 0xA0 && rune <= 0xFF)) {
      bytes.add(rune);
    } else {
      bytes.add(_cp1252Reverse[rune] ?? 0x3F);
    }
  }
  return Uint8List.fromList(bytes);
}

Uint8List _encodeUtf16(String text, {required bool bigEndian}) {
  final units = text.codeUnits;
  final endian = bigEndian ? Endian.big : Endian.little;
  final data = ByteData(2 + units.length * 2)..setUint16(0, 0xFEFF, endian);
  for (var i = 0; i < units.length; i++) {
    data.setUint16(2 + i * 2, units[i], endian);
  }
  return data.buffer.asUint8List();
}
