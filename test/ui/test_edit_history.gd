extends TestCase
## The undo list of a large document: what it records, what it joins, and what it forgets.

var history: EditHistory
var now := 0


func before_each() -> void:
	history = EditHistory.new()
	now = 1000
	history.clock = func() -> int: return now


func _lines(values: Array) -> PackedStringArray:
	return PackedStringArray(values)


func test_starts_empty_and_ignores_a_change_that_changes_nothing() -> void:
	assert_false(history.can_undo())
	history.record(3, _lines(["same"]), _lines(["same"]))
	assert_false(history.can_undo())


func test_typing_one_character_after_another_is_one_entry() -> void:
	history.record(5, _lines(["ab"]), _lines(["abc"]))
	now += 100
	history.record(5, _lines(["abc"]), _lines(["abcd"]))
	now += 100
	history.record(5, _lines(["abcd"]), _lines(["abcde"]))
	assert_eq(history.size(), 1)
	var entry := history.take()
	assert_eq(entry.removed, _lines(["ab"]))
	assert_eq(entry.inserted, _lines(["abcde"]))
	assert_eq(entry.line, 5)


func test_a_pause_starts_a_new_entry() -> void:
	history.record(5, _lines(["ab"]), _lines(["abc"]))
	now += 2000
	history.record(5, _lines(["abc"]), _lines(["abcd"]))
	assert_eq(history.size(), 2)


func test_typing_somewhere_else_starts_a_new_entry() -> void:
	history.record(5, _lines(["ab"]), _lines(["abc"]))
	history.record(6, _lines(["xy"]), _lines(["xyz"]))
	assert_eq(history.size(), 2)
	# The same line, but the edit does not start from what the last one made.
	history.record(6, _lines(["different"]), _lines(["different!"]))
	assert_eq(history.size(), 3)


func test_deleting_one_character_after_another_is_one_entry_and_typing_then_deleting_is_two() -> void:
	history.record(1, _lines(["abc"]), _lines(["ab"]))
	history.record(1, _lines(["ab"]), _lines(["a"]))
	assert_eq(history.size(), 1)
	history.record(1, _lines(["a"]), _lines(["ab"]))
	assert_eq(history.size(), 2)


func test_a_paste_is_never_joined_to_the_typing_before_it() -> void:
	history.record(2, _lines(["ab"]), _lines(["abc"]))
	history.record(2, _lines(["abc"]), _lines(["abc" + "x".repeat(200)]))
	assert_eq(history.size(), 2)


func test_a_change_over_several_lines_is_an_entry_of_its_own() -> void:
	history.record(2, _lines(["ab"]), _lines(["ab", "cd"]))
	history.record(3, _lines(["cd"]), _lines(["cde"]))
	assert_eq(history.size(), 2)


func test_the_oldest_entries_go_first_when_the_list_is_too_long() -> void:
	history.max_entries = 3
	for index in range(6):
		now += 5000
		history.record(index, _lines(["a"]), _lines(["b"]))
	assert_eq(history.size(), 3)
	assert_eq(history.take().line, 5)
	assert_eq(history.take().line, 4)
	assert_eq(history.take().line, 3)
	assert_null(history.take())


func test_the_oldest_entries_go_first_when_the_list_is_too_big() -> void:
	history.max_characters = 100
	history.record(0, _lines(["a".repeat(60)]), _lines(["b".repeat(60)]))
	now += 5000
	history.record(1, _lines(["c"]), _lines(["d"]))
	assert_eq(history.size(), 1)
	assert_eq(history.take().line, 1)


func test_clear_forgets_everything() -> void:
	history.record(0, _lines(["a"]), _lines(["b"]))
	history.clear()
	assert_false(history.can_undo())
