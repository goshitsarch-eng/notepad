import 'dart:convert';
import 'dart:math' as math;
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

/// Reads [bytes]. With no [encoding] it is detected the way Notepad does: byte order marks
/// first, then UTF-16 with no mark, then valid UTF-8 that has non-ASCII bytes, and ANSI
/// (Windows-1252) otherwise. With an [encoding], which is what the Open dialog's Encoding
/// list gives, the file is read as that, unless it has a byte order mark: as in XP, the
/// mark says what the file is.
TextFile readText(Uint8List bytes, {FileEncoding? encoding}) {
  final used = _byteOrderMark(bytes) ?? encoding ?? detectEncoding(bytes);
  return TextFile(decodeText(bytes, used), used);
}

FileEncoding detectEncoding(Uint8List bytes) {
  final marked = _byteOrderMark(bytes);
  if (marked != null) return marked;
  final utf16 = _guessUtf16WithoutMark(bytes);
  if (utf16 != null) return utf16;
  if (_hasHighByte(bytes) && _isValidUtf8(bytes)) return FileEncoding.utf8;
  return FileEncoding.ansi;
}

FileEncoding? _byteOrderMark(Uint8List bytes) {
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
  return null;
}

/// How much of a file is looked at to tell UTF-16 without a byte order mark.
const _utf16SampleBytes = 4096;

/// Recognises UTF-16 that has no byte order mark by its zero bytes. Text in a Latin or
/// Cyrillic script has a zero in the high byte of many of its characters, so in the file
/// the zero bytes sit at every other place, all odd (little endian) or all even (big
/// endian). Other text files have no zero bytes at all, and UTF-32 and binary data have
/// them at both kinds of place, so a file that fits is UTF-16 with very little room for
/// doubt. A file that holds mostly Chinese, Japanese or Korean has hardly any zero bytes
/// and cannot be told this way. The user chooses its encoding in the Open dialog.
FileEncoding? _guessUtf16WithoutMark(Uint8List bytes) {
  final length = math.min(bytes.length, _utf16SampleBytes) & ~1;
  if (length < 2) return null;
  var evenZeros = 0;
  var oddZeros = 0;
  for (var i = 0; i < length; i += 2) {
    if (bytes[i] == 0) evenZeros++;
    if (bytes[i + 1] == 0) oddZeros++;
  }
  final pairs = length ~/ 2;
  final stray = pairs ~/ 100;
  final little = oddZeros * 10 >= pairs && evenZeros <= stray;
  final big = evenZeros * 10 >= pairs && oddZeros <= stray;
  if (little == big) return null;
  final cut = bytes.length > length;
  return _looksLikeUtf16Text(bytes, length, bigEndian: big, cut: cut)
      ? (big ? FileEncoding.unicodeBigEndian : FileEncoding.unicode)
      : null;
}

/// True when the first [length] bytes read as UTF-16 text: surrogates come in pairs, and
/// the only control characters are the ones a text file has. [cut] is set when the sample
/// ends before the file does, so a pair may be split at its end.
bool _looksLikeUtf16Text(
  Uint8List bytes,
  int length, {
  required bool bigEndian,
  required bool cut,
}) {
  final data = ByteData.sublistView(bytes, 0, length);
  final endian = bigEndian ? Endian.big : Endian.little;
  final units = length ~/ 2;
  for (var i = 0; i < units; i++) {
    final unit = data.getUint16(i * 2, endian);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 == units) {
        if (cut) continue;
        return false;
      }
      final next = data.getUint16((i + 1) * 2, endian);
      if (next < 0xDC00 || next > 0xDFFF) return false;
      i++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    } else if (unit < 0x20 &&
        unit != 0x09 &&
        unit != 0x0A &&
        unit != 0x0C &&
        unit != 0x0D) {
      return false;
    }
  }
  return true;
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
