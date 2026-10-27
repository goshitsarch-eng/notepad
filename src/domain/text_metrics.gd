class_name TextMetrics
extends RefCounted
## Line and offset arithmetic over plain text. Offsets count characters (Unicode code
## points), but the column a caret reports counts UTF-16 units, as the status bar of XP
## Notepad does, so a character beyond U+FFFF takes two columns.


## The length of [param text] in UTF-16 units.
static func utf16_length(text: String) -> int:
	var length := text.length()
	if length == 0:
		return 0
	# Most text has no character beyond U+FFFF, which UTF-8 shows as a four-byte sequence.
	var extra := 0
	var bytes := text.to_utf8_buffer()
	if bytes.size() > length:
		for index in range(length):
			if text.unicode_at(index) > 0xFFFF:
				extra += 1
	return length + extra


## 1-based line and column of [param offset], as the status bar shows them. The result is
## a Vector2i of (line, column).
static func caret_at(text: String, offset: int) -> Vector2i:
	var end := clampi(offset, 0, text.length())
	var line := 1
	var line_start := 0
	var cursor := 0
	while true:
		var feed := text.find("\n", cursor)
		if feed < 0 or feed >= end:
			break
		line += 1
		line_start = feed + 1
		cursor = feed + 1
	return Vector2i(line, utf16_length(text.substr(line_start, end - line_start)) + 1)


static func line_count(text: String) -> int:
	return text.count("\n") + 1


## Offset where [param line] (1-based) starts. Lines past the end resolve to the last line.
static func line_start(text: String, line: int) -> int:
	var current := 1
	var offset := 0
	while current < line:
		var next := text.find("\n", offset)
		if next < 0:
			break
		offset = next + 1
		current += 1
	return offset
