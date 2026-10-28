class_name PrintText
extends RefCounted
## What the printed page needs from the text: header and footer codes, and tab stops.


## Fills in the codes Notepad's Page Setup accepts in a header or footer:
## `&f` the file name, `&p` the page number, `&d` the date, `&t` the time, `&&` an
## ampersand, and `&l`, `&c` and `&r`, which align the text after them left, centre or
## right. Text is centred until a code says otherwise. Codes may be upper or lower case.
## An `&` followed by anything else is kept as typed. [param now] is a datetime dictionary.
static func expand_header_footer(
		template: String, file_name: String, page: int, now: Dictionary) -> HeaderFooterLine:
	var sections := {"l": "", "c": "", "r": ""}
	var current := "c"
	var index := 0
	while index < template.length():
		var character := template[index]
		if character != "&" or index + 1 >= template.length():
			sections[current] += character
			index += 1
			continue
		var code := template[index + 1]
		match code.to_lower():
			"f":
				sections[current] += file_name
			"p":
				sections[current] += str(page)
			"d":
				sections[current] += TimeDate.format_short_date(now)
			"t":
				sections[current] += TimeDate.format_short_time(now)
			"&":
				sections[current] += "&"
			"l", "c", "r":
				current = code.to_lower()
			_:
				sections[current] += "&" + code
		index += 2
	return HeaderFooterLine.new(sections["l"], sections["c"], sections["r"])


## Replaces each tab in [param line] with spaces up to the next tab stop, [param tab_width]
## columns apart, so tab-separated columns line up in the monospaced printout as they do on
## screen.
static func expand_tabs(line: String, tab_width: int = 8) -> String:
	if not line.contains("\t"):
		return line
	var out := PackedStringArray()
	var column := 0
	for index in range(line.length()):
		var character := line[index]
		if character == "\t":
			var spaces := tab_width - column % tab_width
			out.append(" ".repeat(spaces))
			column += spaces
		else:
			out.append(character)
			column += 1
	return "".join(out)
