extends TestCase
## Port of print_text_test.dart. The Dart tests called buildPdf; PdfBuilder.build is the
## GDScript equivalent. The PDF writes each string as hex-encoded WinAnsi inside `<...> Tj`,
## so the tests decode those strings to see what is printed.

const MOMENT := {"year": 2026, "month": 10, "day": 7, "hour": 15, "minute": 5, "second": 0}


func _expand(template: String, page: int = 3) -> HeaderFooterLine:
	return PrintText.expand_header_footer(template, "notes.txt", page, MOMENT)


func _moment(year: int, month: int, day: int, hour: int, minute: int) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}


## Every string the PDF draws, in order.
func _drawn_strings(pdf: PackedByteArray) -> PackedStringArray:
	var found := PackedStringArray()
	var pattern := RegEx.create_from_string("<([0-9A-Fa-f]*)> Tj")
	for hit in pattern.search_all(pdf.get_string_from_ascii()):
		var hex: String = hit.get_string(1)
		var bytes := PackedByteArray()
		for index in range(0, hex.length(), 2):
			bytes.append(hex.substr(index, 2).hex_to_int())
		found.append(bytes.get_string_from_ascii())
	return found


func _page_count(pdf: PackedByteArray) -> int:
	var hit := RegEx.create_from_string("/Count (\\d+)").search(pdf.get_string_from_ascii())
	return -1 if hit == null else hit.get_string(1).to_int()


func _starts_with_pdf_marker(pdf: PackedByteArray) -> bool:
	return pdf.slice(0, 5).get_string_from_ascii() == "%PDF-"


func _ends_with_eof(pdf: PackedByteArray) -> bool:
	return pdf.get_string_from_ascii().strip_edges().ends_with("%%EOF")


# ---- header and footer codes (F-24) ----


func test_f_and_p_are_filled_in_as_before() -> void:
	assert_eq(_expand("&f").center, "notes.txt")
	assert_eq(_expand("Page &p").center, "Page 3")


func test_d_and_t_give_the_short_date_and_time() -> void:
	assert_eq(_expand("&d").center, "10/7/2026")
	assert_eq(_expand("&t").center, "3:05 PM")
	assert_eq(_expand("&t &d").center, "3:05 PM 10/7/2026")


func test_double_ampersand_is_a_literal_ampersand() -> void:
	assert_eq(_expand("Smith && Sons").center, "Smith & Sons")


func test_l_c_and_r_align_the_text_after_them() -> void:
	var line := _expand("&lLeft&cMiddle&rRight")
	assert_eq(line.left, "Left")
	assert_eq(line.center, "Middle")
	assert_eq(line.right, "Right")


func test_text_is_centred_until_a_code_says_otherwise() -> void:
	var line := _expand("Title&r&p")
	assert_eq(line.center, "Title")
	assert_eq(line.right, "3")
	assert_eq(line.left, "")


func test_codes_work_in_either_case_and_in_the_footer_as_well_as_the_header() -> void:
	assert_eq(_expand("&F - &P").center, "notes.txt - 3")


func test_an_unknown_code_and_a_trailing_ampersand_are_kept_as_typed() -> void:
	assert_eq(_expand("a &z b").center, "a &z b")
	assert_eq(_expand("end &").center, "end &")


func test_an_empty_template_gives_an_empty_line() -> void:
	assert_true(_expand("").is_empty())


# ---- tabs ----


func test_a_tab_goes_to_the_next_stop_eight_columns_apart() -> void:
	assert_eq(PrintText.expand_tabs("a\tb"), "a       b")
	assert_eq(PrintText.expand_tabs("abcdefgh\tb"), "abcdefgh        b")
	assert_eq(PrintText.expand_tabs("\tx"), "        x")


func test_columns_separated_by_tabs_line_up() -> void:
	var rows: Array[String] = []
	for row in ["name\tqty", "longername\tqty"]:
		rows.append(PrintText.expand_tabs(row))
	assert_eq(rows[0].find("qty"), rows[1].find("qty") - 8)


func test_a_line_with_no_tab_is_returned_as_it_is() -> void:
	# Dart checked object identity; strings have none here, so equality is the check.
	var line := "plain line"
	assert_eq(PrintText.expand_tabs(line), line)


# ---- time and date ----


func test_the_parts_that_time_date_joins_are_available_alone() -> void:
	assert_eq(TimeDate.format_short_time(_moment(2026, 1, 1, 0, 7)), "12:07 AM")
	assert_eq(TimeDate.format_short_date(_moment(2026, 1, 9, 0, 0)), "1/9/2026")
	assert_eq(TimeDate.format_time_date(MOMENT), "3:05 PM 10/7/2026")


# ---- the PDF ----


func test_the_pdf_is_produced_for_a_short_document_with_every_kind_of_header_code() -> void:
	var setup := PageSetup.new("&lLeft&c&f&r&d", "Page &p of text &&")
	var bytes := PdfBuilder.build("one\ntwo\n\tthree", "notes.txt", setup, MOMENT)
	assert_true(_starts_with_pdf_marker(bytes), "starts with %PDF-")
	assert_true(_ends_with_eof(bytes), "ends with %%EOF")
	assert_true(bytes.size() > 500, "the file is more than a skeleton")
	assert_eq(_page_count(bytes), 1)
	var drawn := _drawn_strings(bytes)
	# The header codes: left, centre and right parts.
	assert_contains(drawn, "Left")
	assert_contains(drawn, "notes.txt")
	assert_contains(drawn, "10/7/2026")
	# The footer, with the page number and the literal ampersand.
	assert_contains(drawn, "Page 1 of text &")
	# The body, with the tab expanded to the next stop.
	assert_contains(drawn, "one")
	assert_contains(drawn, "two")
	assert_contains(drawn, "        three")


func test_runs_to_several_pages_for_a_long_document_and_keeps_its_page_count_in_step() -> void:
	var lines := PackedStringArray()
	for index in range(400):
		lines.append("line %d" % index)
	var bytes := PdfBuilder.build("\n".join(lines), "long.txt", PageSetup.new(), MOMENT)
	assert_true(_starts_with_pdf_marker(bytes), "starts with %PDF-")
	assert_true(_ends_with_eof(bytes), "ends with %%EOF")
	var count := _page_count(bytes)
	assert_true(count > 3, "more than three pages, got %d" % count)

	var drawn := _drawn_strings(bytes)
	# The footer ("Page &p") steps up by one on every page, in order.
	var footers := PackedStringArray()
	var headers := PackedStringArray()
	for text in drawn:
		if text.begins_with("Page "):
			footers.append(text)
		elif text == "long.txt":
			headers.append(text)
	var expected := PackedStringArray()
	for page in range(1, count + 1):
		expected.append("Page %d" % page)
	assert_eq(footers, expected, "page numbers step up from 1 to the page count")
	assert_eq(headers.size(), count, "the header (the file name) is on every page")
	# Nothing is lost on the way.
	assert_contains(drawn, "line 0")
	assert_contains(drawn, "line 399")


func test_an_empty_document_still_prints_one_page() -> void:
	var bytes := PdfBuilder.build("", "Untitled", PageSetup.new("", ""), MOMENT)
	assert_true(_starts_with_pdf_marker(bytes), "starts with %PDF-")
	assert_true(_ends_with_eof(bytes), "ends with %%EOF")
	assert_eq(_page_count(bytes), 1)
