extends TestCase
## Port of text_codec_test.dart, plus the Godot-specific decisions: a Godot String cannot
## hold a NUL or a lone surrogate, so a NUL is read as a space and a lone surrogate as U+FFFD.

const SAMPLE := "héllo\nwörld \U01F600"


func _bytes(values: Array) -> PackedByteArray:
	return PackedByteArray(values)


# ---- detectEncoding ----

func test_byte_order_marks_decide_first() -> void:
	assert_eq(TextCodec.detect_encoding(_bytes([0xFF, 0xFE, 0x41, 0x00])), FileEncoding.UNICODE)
	assert_eq(TextCodec.detect_encoding(_bytes([0xFE, 0xFF, 0x00, 0x41])), FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(TextCodec.detect_encoding(_bytes([0xEF, 0xBB, 0xBF, 0x41])), FileEncoding.UTF8)


func test_plain_ascii_is_ansi_the_xp_default() -> void:
	assert_eq(TextCodec.detect_encoding("hello".to_utf8_buffer()), FileEncoding.ANSI)


func test_valid_utf8_with_non_ascii_bytes_is_utf8() -> void:
	assert_eq(TextCodec.detect_encoding("café".to_utf8_buffer()), FileEncoding.UTF8)


func test_invalid_utf8_with_high_bytes_falls_back_to_ansi() -> void:
	assert_eq(TextCodec.detect_encoding(_bytes([0x63, 0x61, 0x66, 0xE9])), FileEncoding.ANSI)


# ---- ANSI (Windows-1252) ----

func test_decodes_the_0x80_to_0x9f_range_through_the_cp1252_table() -> void:
	assert_eq(TextCodec.decode_text(_bytes([0x41, 0x80, 0xE9]), FileEncoding.ANSI), "A€é")
	assert_eq(TextCodec.decode_text(_bytes([0x93, 0x94]), FileEncoding.ANSI), "“”")


func test_encodes_table_characters_and_writes_question_mark_for_characters_ansi_lacks() -> void:
	assert_bytes(TextCodec.encode_text("€é", FileEncoding.ANSI), [0x80, 0xE9])
	assert_bytes(TextCodec.encode_text("中", FileEncoding.ANSI), [0x3F])


# ---- canEncodeAnsi ----

func test_can_encode_ansi_accepts_text_that_windows_1252_can_hold() -> void:
	assert_true(TextCodec.can_encode_ansi("café € “quoted”"))


func test_can_encode_ansi_rejects_characters_outside_windows_1252() -> void:
	assert_false(TextCodec.can_encode_ansi("中文"))
	assert_false(TextCodec.can_encode_ansi("smile \U01F600"))


# ---- line endings ----

func test_crlf_on_disk_becomes_lf_in_the_editor_and_back() -> void:
	assert_eq(TextCodec.decode_text("a\r\nb".to_utf8_buffer(), FileEncoding.ANSI), "a\nb")
	assert_bytes(TextCodec.encode_text("a\nb", FileEncoding.ANSI), Array("a\r\nb".to_utf8_buffer()))


# ---- UTF-16 and UTF-8 round trips ----

func test_unicode_utf16_le_writes_ff_fe_and_reads_back() -> void:
	var bytes := TextCodec.encode_text(SAMPLE, FileEncoding.UNICODE)
	assert_bytes(bytes.slice(0, 2), [0xFF, 0xFE])
	var file := TextCodec.read_text(bytes)
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, SAMPLE)


func test_unicode_big_endian_writes_fe_ff_and_reads_back() -> void:
	var bytes := TextCodec.encode_text(SAMPLE, FileEncoding.UNICODE_BIG_ENDIAN)
	assert_bytes(bytes.slice(0, 2), [0xFE, 0xFF])
	var file := TextCodec.read_text(bytes)
	assert_eq(file.encoding, FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(file.text, SAMPLE)


func test_utf8_writes_a_byte_order_mark_and_reads_back() -> void:
	var bytes := TextCodec.encode_text(SAMPLE, FileEncoding.UTF8)
	assert_bytes(bytes.slice(0, 3), [0xEF, 0xBB, 0xBF])
	var file := TextCodec.read_text(bytes)
	assert_eq(file.encoding, FileEncoding.UTF8)
	assert_eq(file.text, SAMPLE)


# ---- damaged UTF-16 ----

func test_a_trailing_odd_byte_shows_as_u_fffd_instead_of_being_dropped() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00, 0x41]))
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, "a�")


func test_a_complete_utf16_file_has_no_replacement_character() -> void:
	assert_eq(TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00])).text, "a")


# ---- Godot-specific: NUL bytes become spaces in every encoding ----

func test_nul_bytes_become_spaces_in_ansi() -> void:
	assert_eq(TextCodec.decode_text(_bytes([0x61, 0x00, 0x62, 0x00]), FileEncoding.ANSI), "a b ")
	assert_eq(TextCodec.decode_text(_bytes([0x00, 0x00]), FileEncoding.ANSI), "  ")


func test_nul_bytes_become_spaces_in_utf8_with_and_without_a_mark() -> void:
	assert_eq(TextCodec.decode_text(_bytes([0x61, 0x00, 0x62]), FileEncoding.UTF8), "a b")
	var marked := TextCodec.read_text(_bytes([0xEF, 0xBB, 0xBF, 0x61, 0x00, 0xC3, 0xA9, 0x00]))
	assert_eq(marked.encoding, FileEncoding.UTF8)
	assert_eq(marked.text, "a é ")


func test_nul_units_become_spaces_in_utf16_little_endian() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00, 0x00, 0x00, 0x62, 0x00]))
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, "a b")


func test_nul_units_become_spaces_in_utf16_big_endian() -> void:
	var file := TextCodec.read_text(_bytes([0xFE, 0xFF, 0x00, 0x61, 0x00, 0x00, 0x00, 0x62]))
	assert_eq(file.encoding, FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(file.text, "a b")


func test_a_nul_does_not_cut_the_text_after_it() -> void:
	# Godot's own decoders stop at a NUL; the codec must not.
	assert_eq(TextCodec.decode_text(_bytes([0x61, 0x00, 0x62, 0x63]), FileEncoding.ANSI), "a bc")
	assert_eq(TextCodec.decode_text(_bytes([0x61, 0x00, 0x62, 0x63]), FileEncoding.UTF8), "a bc")
	assert_eq(TextCodec.decode_text(_bytes([0x61, 0x00, 0x00, 0x00, 0x62, 0x00]), FileEncoding.UNICODE), "a b")


func test_nul_bytes_still_count_for_detection() -> void:
	# Detection works on bytes, so NULs keep their meaning there.
	var bytes := _bytes([0x61, 0x00, 0x62, 0x00, 0x63, 0x00])
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.UNICODE)
	assert_eq(TextCodec.read_text(bytes).text, "abc")


# ---- Godot-specific: lone surrogates become U+FFFD ----

func test_a_lone_high_surrogate_in_utf16_becomes_u_fffd() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00, 0x00, 0xD8, 0x62, 0x00]))
	assert_eq(file.text, "a�b")


func test_a_lone_low_surrogate_in_utf16_becomes_u_fffd() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00, 0x00, 0xDC, 0x62, 0x00]))
	assert_eq(file.text, "a�b")


func test_a_high_surrogate_at_the_end_becomes_u_fffd() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x61, 0x00, 0x3D, 0xD8]))
	assert_eq(file.text, "a�")


func test_a_high_surrogate_followed_by_a_letter_keeps_the_letter() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x3D, 0xD8, 0x62, 0x00]))
	assert_eq(file.text, "�b")


func test_two_high_surrogates_in_a_row_are_two_replacements() -> void:
	var file := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x3D, 0xD8, 0x3D, 0xD8, 0x00, 0xDE]))
	# The second high surrogate pairs with the low one that follows it.
	assert_eq(file.text, "�\U01F600")


func test_a_lone_surrogate_in_big_endian_becomes_u_fffd() -> void:
	var file := TextCodec.read_text(_bytes([0xFE, 0xFF, 0x00, 0x61, 0xD8, 0x00, 0x00, 0x62]))
	assert_eq(file.text, "a�b")


func test_a_valid_surrogate_pair_still_reads_as_one_character() -> void:
	# U+1F600 is D83D DE00; the low half's low byte is zero, which is not a NUL unit.
	var little := TextCodec.read_text(_bytes([0xFF, 0xFE, 0x3D, 0xD8, 0x00, 0xDE]))
	assert_eq(little.text, "\U01F600")
	var big := TextCodec.read_text(_bytes([0xFE, 0xFF, 0xD8, 0x3D, 0xDE, 0x00]))
	assert_eq(big.text, "\U01F600")


func test_a_lone_surrogate_is_not_detected_as_utf16_without_a_mark() -> void:
	# The Dart test 'UTF-16 that is not well formed is left alone', built from bytes.
	var english := "The quick brown fox jumps over the lazy dog.\nSecond line.\n".to_utf16_buffer()
	var bytes := english.duplicate()
	bytes.append_array(_bytes([0x00, 0xD8]))
	bytes.append_array(english)
	assert_eq(TextCodec.detect_encoding(bytes), FileEncoding.ANSI)


func test_a_surrogate_encoded_in_utf8_becomes_replacement_characters() -> void:
	# ED A0 80 is a surrogate written as UTF-8, which is not well formed. Each byte of it
	# is replaced, so the damage is visible and nothing is lost after it.
	var file := TextCodec.read_text(_bytes([0xEF, 0xBB, 0xBF, 0x61, 0xED, 0xA0, 0x80, 0x62]))
	assert_eq(file.encoding, FileEncoding.UTF8)
	assert_eq(file.text.substr(0, 1), "a")
	assert_eq(file.text.substr(file.text.length() - 1), "b")
	assert_true(file.text.contains("�"))


func test_text_with_the_replacement_character_itself_round_trips() -> void:
	# ANSI is left out: Windows-1252 has no U+FFFD, so it is written as '?' there.
	for encoding in [FileEncoding.UNICODE, FileEncoding.UNICODE_BIG_ENDIAN, FileEncoding.UTF8]:
		var bytes := TextCodec.encode_text("a�b", encoding)
		assert_eq(TextCodec.read_text(bytes).text, "a�b", "encoding %d" % encoding)
