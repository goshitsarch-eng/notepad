class_name PdfBuilder
extends RefCounted
## Lays the text out as a PDF on letter paper with the File > Page Setup margins, header and
## footer. Pure code, so the layout can be checked without a printer. The text is set in
## Courier, one of the fonts every PDF viewer has, so nothing is embedded.

const PAGE_WIDTH := 612.0
const PAGE_HEIGHT := 792.0
const POINTS_PER_INCH := 72.0
const BODY_SIZE := 10.0
const NOTE_SIZE := 9.0
## Courier's characters are 0.6 em wide.
const _COURIER_ADVANCE := 0.6
const _LEADING := 1.15
## The share of the type size above the baseline, for placing a line in its box.
const _ASCENT := 0.8


## Builds the PDF bytes. [param now] is a datetime dictionary that fills the `&d` and `&t`
## codes; it is a parameter so a test can fix it.
static func build(
		text: String, document_name: String, setup: PageSetup, now: Dictionary) -> PackedByteArray:
	var left := setup.left_inches * POINTS_PER_INCH
	var right := setup.right_inches * POINTS_PER_INCH
	var top := setup.top_inches * POINTS_PER_INCH
	var bottom := setup.bottom_inches * POINTS_PER_INCH
	var width := PAGE_WIDTH - left - right
	var note_height := NOTE_SIZE * _LEADING
	var body_leading := BODY_SIZE * _LEADING
	var body_height := PAGE_HEIGHT - top - bottom - 2.0 * note_height
	var lines_per_page := maxi(1, int(floor(body_height / body_leading)))
	var columns := maxi(1, int(floor(width / (BODY_SIZE * _COURIER_ADVANCE))))

	var lines := _wrap_lines(text, columns)
	var pages: Array = []
	var index := 0
	while index < lines.size() or pages.is_empty():
		pages.append(lines.slice(index, index + lines_per_page))
		index += lines_per_page

	var contents: Array[String] = []
	for page_index in range(pages.size()):
		var stream := PackedStringArray()
		var page_number := page_index + 1
		stream.append(_note(setup.header, document_name, page_number, now,
			left, width, PAGE_HEIGHT - top - NOTE_SIZE * _ASCENT))
		var y := PAGE_HEIGHT - top - note_height - BODY_SIZE * _ASCENT
		for line in pages[page_index]:
			if not (line as String).is_empty():
				stream.append(_text_at(left, y, line, BODY_SIZE))
			y -= body_leading
		stream.append(_note(setup.footer, document_name, page_number, now,
			left, width, bottom + note_height - NOTE_SIZE * _ASCENT))
		contents.append("".join(stream))
	return _assemble(contents, document_name)


## The lines of [param text], each at most [param columns] characters, with tabs expanded.
## A line that is too long is broken after its last space that fits, or in the middle of a
## word when it has none.
static func _wrap_lines(text: String, columns: int) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var line := PrintText.expand_tabs(raw)
		while line.length() > columns:
			var cut := line.rfind(" ", columns)
			if cut <= 0:
				out.append(line.substr(0, columns))
				line = line.substr(columns)
			else:
				out.append(line.substr(0, cut))
				line = line.substr(cut + 1)
		out.append(line)
	return out


## The header or footer [param template] as drawing commands, with its parts aligned left,
## centre and right. Centred text alone spans the page; left and right parts share the
## width in thirds.
static func _note(
		template: String, document_name: String, page: int, now: Dictionary,
		left: float, width: float, baseline: float) -> String:
	var line := PrintText.expand_header_footer(template, document_name, page, now)
	var advance := NOTE_SIZE * _COURIER_ADVANCE
	var commands := PackedStringArray()
	if line.left.is_empty() and line.right.is_empty():
		var x := left + (width - line.center.length() * advance) / 2.0
		commands.append(_text_at(x, baseline, line.center, NOTE_SIZE))
		return "".join(commands)
	var third := width / 3.0
	commands.append(_text_at(left, baseline, line.left, NOTE_SIZE))
	commands.append(_text_at(
		left + third + (third - line.center.length() * advance) / 2.0,
		baseline, line.center, NOTE_SIZE))
	commands.append(_text_at(
		left + width - line.right.length() * advance, baseline, line.right, NOTE_SIZE))
	return "".join(commands)


static func _text_at(x: float, y: float, text: String, size: float) -> String:
	if text.is_empty():
		return ""
	return "BT /F1 %s Tf %s %s Td <%s> Tj ET\n" % [
		_number(size), _number(x), _number(y), TextCodec.encode_ansi(text).hex_encode().to_upper()]


static func _number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")


static func _assemble(contents: Array[String], document_name: String) -> PackedByteArray:
	# Objects: 1 catalog, 2 page tree, 3 font, 4 information, then a page and its content
	# stream for each page.
	var count := contents.size()
	var objects: Array[String] = []
	var page_refs := PackedStringArray()
	for index in range(count):
		page_refs.append("%d 0 R" % (5 + index * 2))
	objects.append("<< /Type /Catalog /Pages 2 0 R >>")
	objects.append("<< /Type /Pages /Kids [%s] /Count %d >>" % [" ".join(page_refs), count])
	objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>")
	objects.append("<< /Title <%s> /Producer (XP Notepad) >>" % _utf16_hex(document_name))
	for index in range(count):
		objects.append(
			"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
			+ "/Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R >>" % (6 + index * 2))
		objects.append("<< /Length %d >>\nstream\n%sendstream" % [contents[index].length(), contents[index]])

	var out := "%PDF-1.4\n"
	var offsets := PackedInt32Array()
	for index in range(objects.size()):
		offsets.append(out.length())
		out += "%d 0 obj\n%s\nendobj\n" % [index + 1, objects[index]]
	var xref_at := out.length()
	out += "xref\n0 %d\n0000000000 65535 f \n" % (objects.size() + 1)
	for offset in offsets:
		out += "%010d 00000 n \n" % offset
	out += "trailer\n<< /Size %d /Root 1 0 R /Info 4 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [
		objects.size() + 1, xref_at]
	return out.to_ascii_buffer()


static func _utf16_hex(text: String) -> String:
	var bytes := PackedByteArray([0xFE, 0xFF])
	var utf16 := text.to_utf16_buffer()
	for index in range(0, utf16.size(), 2):
		bytes.append(utf16[index + 1])
		bytes.append(utf16[index])
	return bytes.hex_encode().to_upper()
