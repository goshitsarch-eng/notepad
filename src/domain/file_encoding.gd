class_name FileEncoding
extends RefCounted
## Encodings Notepad can save, in the order the Save As "Encoding" list shows them.

enum { ANSI, UNICODE, UNICODE_BIG_ENDIAN, UTF8 }

## Stands for "no encoding chosen": the Open dialog then detects it from the file.
const DETECT := -1

const ALL: Array[int] = [ANSI, UNICODE, UNICODE_BIG_ENDIAN, UTF8]


static func label(encoding: int) -> String:
	match encoding:
		ANSI:
			return "ANSI"
		UNICODE:
			return "Unicode"
		UNICODE_BIG_ENDIAN:
			return "Unicode big endian"
		UTF8:
			return "UTF-8"
	return ""
