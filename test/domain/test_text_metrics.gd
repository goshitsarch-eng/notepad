extends TestCase
## Port of text_metrics_test.dart. The offsets count code points; the column counts UTF-16
## units, so the last test is an addition that guards that difference.

# ---- TextMetrics.caret_at ----


func test_reports_1_based_line_and_column() -> void:
	assert_eq(TextMetrics.caret_at("ab\ncd", 0), Vector2i(1, 1))
	assert_eq(TextMetrics.caret_at("ab\ncd", 4), Vector2i(2, 2))


func test_clamps_offsets_outside_the_text() -> void:
	assert_eq(TextMetrics.caret_at("ab", 99), Vector2i(1, 3))
	assert_eq(TextMetrics.caret_at("ab", -1), Vector2i(1, 1))


func test_a_character_beyond_the_basic_plane_takes_two_columns() -> void:
	# U+1F600 is one code point but two UTF-16 units.
	assert_eq(TextMetrics.caret_at("a\U01F600b", 3), Vector2i(1, 5))
	assert_eq(TextMetrics.caret_at("a\U01F600\nb", 4), Vector2i(2, 2))


# ---- TextMetrics lines ----


func test_line_count_counts_line_feeds_plus_one() -> void:
	assert_eq(TextMetrics.line_count(""), 1)
	assert_eq(TextMetrics.line_count("a\nb\n"), 3)


func test_line_start_resolves_a_1_based_line_and_clamps_past_the_end() -> void:
	var text := "a\nbc\nd"
	assert_eq(TextMetrics.line_start(text, 1), 0)
	assert_eq(TextMetrics.line_start(text, 2), 2)
	assert_eq(TextMetrics.line_start(text, 3), 5)
	assert_eq(TextMetrics.line_start(text, 99), 5)
