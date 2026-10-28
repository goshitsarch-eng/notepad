extends TestCase
## Port of text_codec_utf16_test.dart: UTF-16 text with no byte order mark, which some
## programs write, and opening a file as a chosen encoding. A file that can be told from
## its bytes is read as what it is. For the rest the Open dialog lets the user say.

const ENGLISH := "The quick brown fox jumps over the lazy dog.\nSecond line.\n"


## UTF-16 bytes of [param text] (Godot strings hold code points, so a character beyond
## U+FFFF becomes a surrogate pair, as in Dart's code units).
func _utf16(text: String, big_endian: bool, bom: bool = false) -> PackedByteArray:
	var body := text.to_utf16_buffer()
	if big_endian:
		for index in range(0, body.size(), 2):
			var low := body[index]
			body[index] = body[index + 1]
			body[index + 1] = low
	var out := PackedByteArray()
	if bom:
		out.append_array(PackedByteArray([0xFE, 0xFF]) if big_endian else PackedByteArray([0xFF, 0xFE]))
	out.append_array(body)
	return out


func _bytes(values: Array) -> PackedByteArray:
	return PackedByteArray(values)


# ---- detectEncoding finds UTF-16 without a byte order mark ----

func test_detects_little_endian_english_text() -> void:
	assert_eq(TextCodec.detect_encoding(_utf16(ENGLISH, false)), FileEncoding.UNICODE)


func test_detects_big_endian_english_text() -> void:
	assert_eq(TextCodec.detect_encoding(_utf16(ENGLISH, true)), FileEncoding.UNICODE_BIG_ENDIAN)


func test_detects_cyrillic_and_accented_text_which_has_fewer_zero_bytes() -> void:
	var text := "Привет, мир! Это проверка текста.\nÉcole, café, naïve.\n"
	assert_eq(TextCodec.detect_encoding(_utf16(text, false)), FileEncoding.UNICODE)
	assert_eq(TextCodec.detect_encoding(_utf16(text, true)), FileEncoding.UNICODE_BIG_ENDIAN)


func test_detects_text_with_windows_line_ends_which_are_control_characters_too() -> void:
	var text := ENGLISH.replace("\n", "\r\n")
	assert_eq(TextCodec.detect_encoding(_utf16(text, false)), FileEncoding.UNICODE)


func test_detects_where_the_first_look_ends_in_the_middle_of_a_surrogate_pair() -> void:
	# The emoji's two halves lie either side of the 4096 bytes that are examined.
	var text := "a".repeat(2047) + "\U01F600" + "b".repeat(100)
	var bytes := _utf16(text, false)
	assert_true(bytes.size() > 4096)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.UNICODE)


func test_detects_a_short_text() -> void:
	assert_eq(TextCodec.detect_encoding(_utf16("Hi!", false)), FileEncoding.UNICODE)
	assert_eq(TextCodec.detect_encoding(_utf16("ab", true)), FileEncoding.UNICODE_BIG_ENDIAN)


func test_a_long_file_is_judged_from_its_start() -> void:
	var text := ENGLISH + "more text here\n".repeat(5000)
	assert_eq(TextCodec.detect_encoding(_utf16(text, false)), FileEncoding.UNICODE)


func test_and_decodes_to_the_same_text() -> void:
	var file := TextCodec.read_text(_utf16(ENGLISH, false))
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, ENGLISH)
	var big := TextCodec.read_text(_utf16(ENGLISH, true))
	assert_eq(big.encoding, FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(big.text, ENGLISH)


# ---- detectEncoding does not mistake other files for UTF-16 ----

func test_plain_ansi_utf8_and_empty_files() -> void:
	assert_eq(TextCodec.detect_encoding(PackedByteArray()), FileEncoding.ANSI)
	assert_eq(TextCodec.detect_encoding(_bytes([0x41])), FileEncoding.ANSI)
	assert_eq(TextCodec.detect_encoding(ENGLISH.to_utf8_buffer()), FileEncoding.ANSI)
	assert_eq(TextCodec.detect_encoding("Привет, мир, как дела?".to_utf8_buffer()), FileEncoding.UTF8)
	assert_eq(TextCodec.detect_encoding(_bytes([0x63, 0x61, 0x66, 0xE9, 0x20, 0x6F, 0x6E])), FileEncoding.ANSI)


func test_a_text_with_a_few_stray_zero_bytes() -> void:
	var bytes := (ENGLISH.repeat(40)).to_utf8_buffer()
	bytes[100] = 0
	bytes[501] = 0
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_data_with_zero_bytes_at_both_kinds_of_places() -> void:
	var bytes := PackedByteArray()
	for i in range(2000):
		bytes.append(0 if i % 3 == 0 else 0x41 + i % 20)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_utf32_whose_zero_bytes_are_not_at_one_kind_of_place() -> void:
	var bytes := PackedByteArray()
	for character in ENGLISH:
		bytes.append_array(_bytes([character.unicode_at(0), 0, 0, 0]))
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_a_run_of_zero_bytes() -> void:
	var bytes := PackedByteArray()
	bytes.resize(64)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_utf16_that_is_not_well_formed_is_left_alone() -> void:
	# A lone high surrogate in the middle of English text.
	var english := ENGLISH.to_utf16_buffer()
	var bytes := english.duplicate()
	bytes.append_array(_bytes([0x00, 0xD8]))
	bytes.append_array(english)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_text_with_control_characters_that_no_text_file_has() -> void:
	var text := "Some English text" + char(0x1B) + "[31m in colour.\n"
	assert_eq(TextCodec.detect_encoding(_utf16(text, false)), FileEncoding.ANSI)


func test_files_with_a_byte_order_mark_are_unchanged() -> void:
	assert_eq(TextCodec.detect_encoding(_utf16(ENGLISH, false, true)), FileEncoding.UNICODE)
	assert_eq(TextCodec.detect_encoding(_utf16(ENGLISH, true, true)), FileEncoding.UNICODE_BIG_ENDIAN)


# ---- detectEncoding leaves NUL-terminated text alone ----
# ASCII with a NUL here and there has zero bytes at one kind of place too. In UTF-16 text
# those zeros are the high bytes of letters; here the other bytes at the same places are
# letters, which no UTF-16 text of an alphabetic script has.
#
# Godot-specific: a Godot String cannot hold a NUL, so the samples are lists of parts that
# are joined with NUL bytes, and the decoded text, which the Dart test compared with the
# input, has each NUL read as a space.

func _joined_with_nul(parts: Array, trailing_nul: bool) -> PackedByteArray:
	var bytes := PackedByteArray()
	for index in range(parts.size()):
		if index > 0:
			bytes.append(0)
		bytes.append_array((parts[index] as String).to_ascii_buffer())
	if trailing_nul:
		bytes.append(0)
	return bytes


func _check_nul_terminated(parts: Array, trailing_nul: bool) -> void:
	var bytes := _joined_with_nul(parts, trailing_nul)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)
	var expected := " ".join(PackedStringArray(parts)) + (" " if trailing_nul else "")
	assert_eq(TextCodec.read_text(bytes).text, expected)


func test_nul_terminated_one_word_and_its_nul() -> void:
	_check_nul_terminated(["hello"], true)


func test_nul_terminated_a_sentence_and_its_nul() -> void:
	_check_nul_terminated(["Hello, world!"], true)


func test_nul_terminated_paths_from_find_print0() -> void:
	_check_nul_terminated(["a/b", "c/d"], true)


func test_nul_terminated_two_settings() -> void:
	_check_nul_terminated(["key=1", "k2=2"], true)


func test_nul_terminated_four_bytes() -> void:
	_check_nul_terminated(["ab", "c"], false)


func test_nul_terminated_twenty_bytes() -> void:
	_check_nul_terminated(["twenty bytes of text"], true)


func test_nul_terminated_a_long_list_of_names() -> void:
	var names: Array = []
	for i in range(60):
		names.append("file%d.txt" % i)
	_check_nul_terminated(names, false)


# ---- detectEncoding still finds UTF-16 text of other kinds ----

func _check_other_kind(text: String) -> void:
	assert_eq(TextCodec.detect_encoding(_utf16(text, false)), FileEncoding.UNICODE)
	assert_eq(TextCodec.detect_encoding(_utf16(text, true)), FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(TextCodec.read_text(_utf16(text, false)).text, text)


func test_still_finds_greek() -> void:
	_check_other_kind("Καλημέρα κόσμε, αυτό είναι ένα κείμενο.\n")


func test_still_finds_hebrew() -> void:
	_check_other_kind("שלום עולם, זה טקסט לדוגמה.\n")


func test_still_finds_hindi() -> void:
	_check_other_kind("नमस्ते दुनिया, यह एक परीक्षण है।\n")


func test_still_finds_curly_quotes_dashes_and_the_euro_sign() -> void:
	_check_other_kind("“Quoted” — it costs €5.\n")


func test_still_finds_an_emoji_among_words() -> void:
	_check_other_kind("Fine work \U01F600 on this one, thank you.\n")


# ---- readText with a chosen encoding ----

func test_reads_a_file_with_no_byte_order_mark_as_the_encoding_asked_for() -> void:
	# Japanese text in UTF-16 has hardly any zero bytes, so it cannot be recognised.
	var text := "日本語のテキストです。\n"
	var bytes := _utf16(text, false)
	assert_ne(TextCodec.detect_encoding(bytes), FileEncoding.UNICODE)
	var file := TextCodec.read_text(bytes, FileEncoding.UNICODE)
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, text)


func test_a_byte_order_mark_wins_over_the_choice_as_in_xp() -> void:
	var bytes := _utf16(ENGLISH, true, true)
	var file := TextCodec.read_text(bytes, FileEncoding.ANSI)
	assert_eq(file.encoding, FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(file.text, ENGLISH)


func test_ansi_can_be_forced_on_a_utf8_file_which_then_shows_its_bytes() -> void:
	var bytes := "café".to_utf8_buffer()
	assert_eq(TextCodec.read_text(bytes).text, "café")
	var forced := TextCodec.read_text(bytes, FileEncoding.ANSI)
	assert_eq(forced.encoding, FileEncoding.ANSI)
	assert_eq(forced.text, "cafÃ©")


func test_utf8_can_be_forced_on_a_file_that_does_not_look_like_it() -> void:
	var file := TextCodec.read_text(_bytes([0x61, 0x62, 0x63]), FileEncoding.UTF8)
	assert_eq(file.encoding, FileEncoding.UTF8)
	assert_eq(file.text, "abc")


func test_no_choice_detects_as_before() -> void:
	assert_eq(TextCodec.read_text("café".to_utf8_buffer()).encoding, FileEncoding.UTF8)
	assert_eq(TextCodec.read_text("café".to_utf8_buffer(), FileEncoding.DETECT).encoding, FileEncoding.UTF8)
