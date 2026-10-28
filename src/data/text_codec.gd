class_name TextCodec
extends RefCounted
## Reads and writes the encodings Notepad knows: ANSI (Windows-1252), UTF-16 in both byte
## orders and UTF-8, with the byte order marks and line ends XP uses.
##
## Godot's own decoders stop at a NUL, and a Godot string can hold neither a NUL nor a lone
## surrogate, both of which a file may contain. Each NUL is therefore read as a space, as
## Windows Notepad reads it, and a lone surrogate as U+FFFD.

const REPLACEMENT := "�"

## Windows-1252 characters for bytes 0x80 to 0x9F. Undefined bytes map to themselves.
const _CP1252_HIGH: Array[int] = [
	0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
	0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F,
	0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
	0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
]

## How much of a file is looked at to tell UTF-16 without a byte order mark.
const _UTF16_SAMPLE_BYTES := 4096

static var _cp1252_reverse: Dictionary = {}


static func _reverse_table() -> Dictionary:
	if _cp1252_reverse.is_empty():
		for index in range(_CP1252_HIGH.size()):
			_cp1252_reverse[_CP1252_HIGH[index]] = 0x80 + index
	return _cp1252_reverse


## Reads [param bytes]. With no [param encoding] it is detected the way Notepad does: byte
## order marks first, then UTF-16 with no mark, then valid UTF-8 that has non-ASCII bytes,
## and ANSI (Windows-1252) otherwise. With an [param encoding], which is what the Open
## dialog's Encoding list gives, the file is read as that, unless it has a byte order mark:
## as in XP, the mark says what the file is.
static func read_text(bytes: PackedByteArray, encoding: int = FileEncoding.DETECT) -> TextFile:
	var used := _byte_order_mark(bytes)
	if used < 0:
		used = encoding if encoding >= 0 else detect_encoding(bytes)
	return TextFile.new(decode_text(bytes, used), used)


static func detect_encoding(bytes: PackedByteArray) -> int:
	var marked := _byte_order_mark(bytes)
	if marked >= 0:
		return marked
	var utf16 := _guess_utf16_without_mark(bytes)
	if utf16 >= 0:
		return utf16
	if _has_high_byte(bytes) and _is_valid_utf8(bytes):
		return FileEncoding.UTF8
	return FileEncoding.ANSI


## The encoding a byte order mark names, or -1 when the bytes start with none.
static func _byte_order_mark(bytes: PackedByteArray) -> int:
	if bytes.size() >= 2 and bytes[0] == 0xFF and bytes[1] == 0xFE:
		return FileEncoding.UNICODE
	if bytes.size() >= 2 and bytes[0] == 0xFE and bytes[1] == 0xFF:
		return FileEncoding.UNICODE_BIG_ENDIAN
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		return FileEncoding.UTF8
	return -1


## Recognises UTF-16 that has no byte order mark by its zero bytes. Text in a Latin or
## Cyrillic script has a zero in the high byte of many of its characters, so in the file
## the zero bytes sit at every other place, all odd (little endian) or all even (big
## endian). Other text files have no zero bytes at all, and UTF-32 and binary data have
## them at both kinds of place, so a file that fits is UTF-16 with very little room for
## doubt. The other bytes at those places are the high bytes of the other characters, and
## in text of an alphabetic script they are small: Latin, Greek, Cyrillic, Hebrew, Arabic
## and the Indian scripts all lie below U+2C00, together with punctuation and symbols. A
## file whose bytes there are letters or digits is ASCII with a NUL here and there, such
## as the output of `find -print0`, and is left alone. A file that holds mostly Chinese,
## Japanese or Korean has hardly any zero bytes and cannot be told this way either. The
## user chooses its encoding in the Open dialog.
static func _guess_utf16_without_mark(bytes: PackedByteArray) -> int:
	var length := mini(bytes.size(), _UTF16_SAMPLE_BYTES) & ~1
	if length < 2:
		return -1
	# For each byte order: zeros where the high bytes are, zeros where they are not, and
	# high bytes that no alphabetic script has.
	var little_high := 0
	var little_low := 0
	var little_bad := 0
	var big_high := 0
	var big_low := 0
	var big_bad := 0
	for index in range(0, length, 2):
		var first := bytes[index]
		var second := bytes[index + 1]
		# Little endian: the second byte is the high one.
		if second == 0:
			little_high += 1
		if first == 0 and not _is_low_surrogate_high_byte(second):
			little_low += 1
		if not _is_plausible_high_byte(second):
			little_bad += 1
		# Big endian: the first byte is the high one.
		if first == 0:
			big_high += 1
		if second == 0 and not _is_low_surrogate_high_byte(first):
			big_low += 1
		if not _is_plausible_high_byte(first):
			big_bad += 1
	var pairs := length / 2
	var stray := pairs / 100
	var little := little_high * 10 >= pairs and little_low <= stray and little_bad <= stray
	var big := big_high * 10 >= pairs and big_low <= stray and big_bad <= stray
	if little == big:
		return -1
	var cut := bytes.size() > length
	if _looks_like_utf16_text(bytes, length, big, cut):
		return FileEncoding.UNICODE_BIG_ENDIAN if big else FileEncoding.UNICODE
	return -1


## The high byte of a UTF-16 unit in text of an alphabetic script, with punctuation and
## symbols: zero, up to 0x2B, or a surrogate half, which is how characters beyond U+FFFF
## such as emoji are written.
static func _is_plausible_high_byte(byte: int) -> bool:
	return byte <= 0x2B or (byte >= 0xD8 and byte <= 0xDF)


## A low surrogate has a high byte of 0xDC to 0xDF, and its low byte can be zero, as in
## U+1F600, which is 0xD83D 0xDE00. That zero does not say the file is not UTF-16.
static func _is_low_surrogate_high_byte(byte: int) -> bool:
	return byte >= 0xDC and byte <= 0xDF


## True when the first [param length] bytes read as UTF-16 text: surrogates come in pairs,
## and the only control characters are the ones a text file has. [param cut] is set when
## the sample ends before the file does, so a pair may be split at its end.
static func _looks_like_utf16_text(
		bytes: PackedByteArray, length: int, big_endian: bool, cut: bool) -> bool:
	var units := length / 2
	var index := 0
	while index < units:
		var unit := _unit_at(bytes, index * 2, big_endian)
		if unit >= 0xD800 and unit <= 0xDBFF:
			if index + 1 == units:
				if cut:
					index += 1
					continue
				return false
			var next := _unit_at(bytes, (index + 1) * 2, big_endian)
			if next < 0xDC00 or next > 0xDFFF:
				return false
			index += 1
		elif unit >= 0xDC00 and unit <= 0xDFFF:
			return false
		elif unit < 0x20 and unit != 0x09 and unit != 0x0A and unit != 0x0C and unit != 0x0D:
			return false
		index += 1
	return true


static func _unit_at(bytes: PackedByteArray, position: int, big_endian: bool) -> int:
	if big_endian:
		return (bytes[position] << 8) | bytes[position + 1]
	return bytes[position] | (bytes[position + 1] << 8)


## Decodes [param bytes] as [param encoding], skipping a matching byte order mark, and
## converts CRLF line ends to LF for the editor.
static func decode_text(bytes: PackedByteArray, encoding: int) -> String:
	var text: String
	match encoding:
		FileEncoding.ANSI:
			text = _decode_ansi(bytes)
		FileEncoding.UNICODE:
			text = _decode_utf16(bytes, false)
		FileEncoding.UNICODE_BIG_ENDIAN:
			text = _decode_utf16(bytes, true)
		_:
			text = _decode_utf8(bytes)
	return text.replace("\r\n", "\n")


## True when every character of [param text] exists in Windows-1252, so ANSI can hold it
## unchanged.
static func can_encode_ansi(text: String) -> bool:
	if _is_ascii(text):
		return true
	var reverse := _reverse_table()
	for code in _code_points(text):
		if code < 0x80 or (code >= 0xA0 and code <= 0xFF):
			continue
		if reverse.has(code):
			continue
		return false
	return true


## Encodes [param text] for [param encoding] with a byte order mark where XP writes one,
## and CRLF line ends. Characters ANSI cannot hold are written as '?', as Notepad does.
static func encode_text(text: String, encoding: int) -> PackedByteArray:
	var crlf := text.replace("\r\n", "\n").replace("\n", "\r\n")
	match encoding:
		FileEncoding.ANSI:
			return _encode_ansi(crlf)
		FileEncoding.UNICODE:
			return _encode_utf16(crlf, false)
		FileEncoding.UNICODE_BIG_ENDIAN:
			return _encode_utf16(crlf, true)
	var out := PackedByteArray([0xEF, 0xBB, 0xBF])
	out.append_array(crlf.to_utf8_buffer())
	return out


# ---- Decoding ----

static func _decode_ansi(bytes: PackedByteArray) -> String:
	# Every byte becomes the character with its number, which is Latin-1. Windows-1252
	# differs only in the range 0x80 to 0x9F.
	var text := _without_nul(bytes).get_string_from_ascii()
	for index in range(_CP1252_HIGH.size()):
		var mapped := _CP1252_HIGH[index]
		if mapped != 0x80 + index:
			text = text.replace(char(0x80 + index), char(mapped))
	return text


static func _decode_utf8(bytes: PackedByteArray) -> String:
	var body := bytes
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		body = bytes.slice(3)
	if not _is_valid_utf8(body):
		body = _repair_utf8(body)
	return _without_nul(body).get_string_from_utf8()


## [param bytes] with each NUL byte made a space, because the native decoders stop at a NUL
## and a Godot string cannot hold one. Windows Notepad shows a NUL as a space too.
static func _without_nul(bytes: PackedByteArray) -> PackedByteArray:
	var at := bytes.find(0)
	if at < 0:
		return bytes
	var copy := bytes.duplicate()
	while at >= 0:
		copy[at] = 0x20
		at = copy.find(0, at + 1)
	return copy


static func _decode_utf16(bytes: PackedByteArray, big_endian: bool) -> String:
	var has_mark := false
	if bytes.size() >= 2:
		if big_endian:
			has_mark = bytes[0] == 0xFE and bytes[1] == 0xFF
		else:
			has_mark = bytes[0] == 0xFF and bytes[1] == 0xFE
	var start := 2 if has_mark else 0
	var body_length := bytes.size() - start
	var count := body_length / 2
	var odd_byte := body_length % 2 == 1
	var units := bytes.slice(start, start + count * 2)
	var text := _decode_utf16_units(units, big_endian)
	# A final byte with no partner is shown as U+FFFD, so the file's damage is visible.
	return text + REPLACEMENT if odd_byte else text


## Decodes whole UTF-16 units. A unit of zero is a NUL character, which is shown as a space,
## and a surrogate with no partner cannot be held by a Godot string, so it is shown as
## U+FFFD.
static func _decode_utf16_units(units: PackedByteArray, big_endian: bool) -> String:
	var length := units.size()
	var little := units
	if big_endian:
		little = PackedByteArray()
		little.resize(length)
		for index in range(0, length, 2):
			little[index] = units[index + 1]
			little[index + 1] = units[index]
	var index := 0
	while index < length:
		var high := little[index + 1]
		if high == 0:
			if little[index] == 0:
				little[index] = 0x20
		elif high >= 0xD8 and high <= 0xDF:
			if high <= 0xDB and index + 3 < length \
					and little[index + 3] >= 0xDC and little[index + 3] <= 0xDF:
				index += 4
				continue
			little[index] = 0xFD
			little[index + 1] = 0xFF
		index += 2
	return little.get_string_from_utf16()


# ---- Encoding ----

## [param text] as Windows-1252 bytes, with '?' for a character the code page lacks.
static func encode_ansi(text: String) -> PackedByteArray:
	return _encode_ansi(text)


static func _encode_ansi(text: String) -> PackedByteArray:
	if _is_ascii(text):
		return text.to_ascii_buffer()
	var reverse := _reverse_table()
	var codes := _code_points(text)
	var out := PackedByteArray()
	out.resize(codes.size())
	for index in range(codes.size()):
		var code := codes[index]
		if code < 0x80 or (code >= 0xA0 and code <= 0xFF):
			out[index] = code
		else:
			out[index] = reverse.get(code, 0x3F)
	return out


static func _encode_utf16(text: String, big_endian: bool) -> PackedByteArray:
	var body := text.to_utf16_buffer()
	var out := PackedByteArray()
	if big_endian:
		out.resize(2 + body.size())
		out[0] = 0xFE
		out[1] = 0xFF
		for index in range(0, body.size(), 2):
			out[2 + index] = body[index + 1]
			out[3 + index] = body[index]
		return out
	out.append(0xFF)
	out.append(0xFE)
	out.append_array(body)
	return out


# ---- Scanning ----

## True when [param text] has only ASCII characters, which UTF-8 writes as one byte each.
static func _is_ascii(text: String) -> bool:
	return text.to_utf8_buffer().size() == text.length()


## The characters of [param text] as numbers.
static func _code_points(text: String) -> PackedInt32Array:
	return text.to_utf32_buffer().to_int32_array()


static func _has_high_byte(bytes: PackedByteArray) -> bool:
	for index in range(bytes.size()):
		if bytes[index] >= 0x80:
			return true
	return false


## The length of the well formed UTF-8 sequence that starts at [param index], or 0 when
## there is none. Overlong forms, surrogates and values beyond U+10FFFF are not well formed.
static func _utf8_sequence_length(bytes: PackedByteArray, index: int, size: int) -> int:
	var lead := bytes[index]
	if lead < 0x80:
		return 1
	if lead >= 0xC2 and lead <= 0xDF:
		if index + 1 < size and (bytes[index + 1] & 0xC0) == 0x80:
			return 2
		return 0
	if lead >= 0xE0 and lead <= 0xEF:
		if index + 2 >= size:
			return 0
		var second := bytes[index + 1]
		if (second & 0xC0) != 0x80 or (bytes[index + 2] & 0xC0) != 0x80:
			return 0
		if lead == 0xE0 and second < 0xA0:
			return 0
		if lead == 0xED and second > 0x9F:
			return 0
		return 3
	if lead >= 0xF0 and lead <= 0xF4:
		if index + 3 >= size:
			return 0
		var second := bytes[index + 1]
		if (second & 0xC0) != 0x80 or (bytes[index + 2] & 0xC0) != 0x80 \
				or (bytes[index + 3] & 0xC0) != 0x80:
			return 0
		if lead == 0xF0 and second < 0x90:
			return 0
		if lead == 0xF4 and second > 0x8F:
			return 0
		return 4
	return 0


static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var size := bytes.size()
	var index := 0
	while index < size:
		if bytes[index] < 0x80:
			index += 1
			continue
		var length := _utf8_sequence_length(bytes, index, size)
		if length == 0:
			return false
		index += length
	return true


## [param bytes] with each byte that is not part of a well formed sequence replaced by
## U+FFFD, so that a file read as UTF-8 by choice shows where it is not.
static func _repair_utf8(bytes: PackedByteArray) -> PackedByteArray:
	var size := bytes.size()
	var out := PackedByteArray()
	var run_start := 0
	var index := 0
	while index < size:
		var length := _utf8_sequence_length(bytes, index, size)
		if length == 0:
			out.append_array(bytes.slice(run_start, index))
			out.append(0xEF)
			out.append(0xBF)
			out.append(0xBD)
			index += 1
			run_start = index
			continue
		index += length
	out.append_array(bytes.slice(run_start))
	return out
