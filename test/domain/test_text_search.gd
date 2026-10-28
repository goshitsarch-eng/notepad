extends TestCase
## Port of text_search_test.dart. A match is a MatchRange or null.


func _span(match_range: MatchRange) -> Array:
	return [] if match_range == null else [match_range.start, match_range.end]


# ---- TextSearch.find ----


func test_forward_search_starts_at_the_given_offset() -> void:
	var options := SearchOptions.new("bc")
	assert_eq(_span(TextSearch.find("abcabc", options, 0)), [1, 3])
	assert_eq(_span(TextSearch.find("abcabc", options, 2)), [4, 6])
	assert_null(TextSearch.find("abcabc", options, 5))


func test_match_case_controls_case_folding() -> void:
	var insensitive := SearchOptions.new("HELLO")
	assert_eq(_span(TextSearch.find("Hello hello", insensitive, 0)), [0, 5])

	var sensitive := SearchOptions.new("HELLO", true)
	assert_null(TextSearch.find("Hello hello", sensitive, 0))
	var lower := TextSearch.find("Hello hello", SearchOptions.new("hello", true), 0)
	assert_not_null(lower)
	if lower != null:
		assert_eq(lower.start, 6)


func test_whole_word_skips_matches_inside_longer_words() -> void:
	var options := SearchOptions.new("cat", false, true)
	assert_eq(_span(TextSearch.find("cat catalog cat", options, 1)), [12, 15])


func test_backward_search_finds_the_previous_match_before_the_offset() -> void:
	var options := SearchOptions.new("bc", false, false, false)
	assert_eq(_span(TextSearch.find("abcabc", options, 6)), [4, 6])
	assert_eq(_span(TextSearch.find("abcabc", options, 4)), [1, 3])
	assert_null(TextSearch.find("abcabc", options, 2))


func test_query_characters_are_matched_literally() -> void:
	var found := TextSearch.find("x (a) y", SearchOptions.new("(a)"), 0)
	assert_eq(_span(found), [2, 5])


func test_an_empty_query_finds_nothing() -> void:
	assert_null(TextSearch.find("text", SearchOptions.new(), 0))


func test_an_offset_past_the_end_is_clamped_instead_of_throwing() -> void:
	assert_null(TextSearch.find("abc", SearchOptions.new("a"), 99))


# ---- TextSearch.replace_all ----


func test_replaces_every_match_and_counts_them() -> void:
	var result := TextSearch.replace_all("a-a-a", SearchOptions.new("a"), "b")
	assert_eq(result.text, "b-b-b")
	assert_eq(result.count, 3)


func test_whole_word_leaves_embedded_matches_alone() -> void:
	var options := SearchOptions.new("in", false, true)
	var result := TextSearch.replace_all("in inside in", options, "out")
	assert_eq(result.text, "out inside out")
	assert_eq(result.count, 2)


func test_reports_zero_when_nothing_matches() -> void:
	var result := TextSearch.replace_all("abc", SearchOptions.new("z"), "y")
	assert_eq(result.text, "abc")
	assert_eq(result.count, 0)
