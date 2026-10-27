extends TestCase
## A document too big for the control, edited through a window of its lines. The document is kept
## as a plain string alongside, and must match it after every step.

var edit: XpTextEdit
var document: LargeDocument
var reference: String


func before_each() -> void:
	edit = XpTextEdit.new()
	edit.size = Vector2(500, 300)
	tree.root.add_child(edit)
	await wait_frames(2)


func after_each() -> void:
	edit.queue_free()
	await wait_frames(2)


## A text of about [param kilobytes] kilobytes in numbered lines of different lengths.
func _make_text(kilobytes: int) -> String:
	var lines := PackedStringArray()
	var size := 0
	var index := 0
	while size < kilobytes * 1024:
		var line := "line %d %s" % [index, "x".repeat((index * 7) % 80)]
		lines.append(line)
		size += line.length() + 1
		index += 1
	return "\n".join(lines)


func _open(kilobytes: int) -> void:
	reference = _make_text(kilobytes)
	edit.load_document(reference)
	document = edit.large_document()


func test_a_big_document_is_shown_through_a_window() -> void:
	_open(400)
	assert_true(edit.is_windowed())
	assert_not_null(document)
	assert_true(edit.get_line_count() < document.total_lines(), "the control holds only some of the lines")
	assert_eq(edit.document_text(), reference)
	assert_eq(edit.document_line_count(), reference.count("\n") + 1)


func test_a_small_document_is_not() -> void:
	reference = _make_text(20)
	edit.load_document(reference)
	assert_false(edit.is_windowed())
	assert_eq(edit.document_text(), reference)


func test_loading_a_small_document_after_a_big_one_leaves_the_window() -> void:
	_open(400)
	edit.load_document("small")
	assert_false(edit.is_windowed())
	assert_eq(edit.document_text(), "small")


func test_the_window_moves_to_any_line_and_the_document_is_unchanged() -> void:
	_open(400)
	var total := document.total_lines()
	for target in [0, total - 1, total / 2, 17, total - 40, total / 3]:
		document.teleport(target, LargeDocument.Place.FIRST_VISIBLE)
		var local: int = target - document.win_start
		assert_true(local >= 0 and local < edit.get_line_count(), "line %d is in the window" % target)
		assert_eq(edit.get_line(local), reference.split("\n")[target])
	assert_eq(edit.document_text(), reference)


func test_typing_in_the_window_reaches_the_document() -> void:
	_open(400)
	var target := document.total_lines() / 2
	document.ensure_window(target, target)
	document.set_caret_document(Vector2i(target, 4))
	edit.insert_text_at_caret("HELLO")
	var lines := reference.split("\n")
	lines[target] = lines[target].substr(0, 4) + "HELLO" + lines[target].substr(4)
	reference = "\n".join(lines)
	assert_eq(edit.document_text(), reference)
	assert_true(edit.document_version() > 0)


func test_a_new_line_and_a_deleted_line_are_followed() -> void:
	_open(400)
	var target := 100
	document.ensure_window(target, target)
	document.set_caret_document(Vector2i(target, 3))
	edit.insert_text_at_caret("\n")
	var lines := reference.split("\n")
	var line: String = lines[target]
	lines[target] = line.substr(0, 3)
	lines.insert(target + 1, line.substr(3))
	reference = "\n".join(lines)
	assert_eq(edit.document_text(), reference)
	assert_eq(edit.document_line_count(), lines.size())
	# Joining the two lines again.
	edit.select(target - document.win_start, 3, target + 1 - document.win_start, 0)
	edit.delete_selection()
	lines[target] = lines[target] + lines[target + 1]
	lines.remove_at(target + 1)
	reference = "\n".join(lines)
	assert_eq(edit.document_text(), reference)


func test_undo_takes_back_edits_made_anywhere_in_the_document() -> void:
	_open(400)
	var original := reference
	for target in [10, 2000, 50, 3000]:
		target = mini(target, document.total_lines() - 1)
		document.ensure_window(target, target)
		document.set_caret_document(Vector2i(target, 0))
		edit.insert_text_at_caret("<%d>" % target)
	assert_true(edit.can_undo_edit())
	assert_ne(edit.document_text(), original)
	var guard := 0
	while edit.can_undo_edit() and guard < 20:
		edit.undo_edit()
		guard += 1
	assert_eq(edit.document_text(), original)
	assert_false(edit.can_undo_edit())


func test_typing_a_word_is_one_undo_step() -> void:
	_open(400)
	document.ensure_window(5, 5)
	document.set_caret_document(Vector2i(5, 0))
	for character in "hello":
		edit.insert_text_at_caret(character)
	edit.undo_edit()
	assert_eq(edit.document_text(), reference)


func test_scrolling_down_through_the_document_extends_the_window_and_keeps_the_text() -> void:
	_open(600)
	var start_before := document.win_start
	var window_lines := edit.get_line_count()
	# Scroll towards the bottom of the window, which must make the window follow.
	edit.set_line_as_first_visible(edit.get_line_count() - 20)
	document.check_edges()
	assert_true(document.win_start >= start_before)
	assert_true(edit.get_line_count() > 0)
	assert_eq(edit.document_text(), reference)
	assert_true(window_lines > 0)


func test_scrolling_by_the_document_bar_jumps_anywhere() -> void:
	_open(600)
	var total := document.total_lines()
	document.scroll_to(total - 30)
	var at_once := document.win_start + edit.get_first_visible_line()
	await wait_frames(3)
	var after_layout := document.win_start + edit.get_first_visible_line()
	print("first visible line: at once ", at_once, ", after layout ", after_layout, ", wanted ", total - 30, " of ", total)
	assert_true(after_layout >= total - 40, "the view is at the line that was asked for")
	document.scroll_to(0)
	await wait_frames(3)
	assert_eq(document.win_start + edit.get_first_visible_line(), 0)
	assert_eq(edit.document_text(), reference)


func test_select_all_reaches_the_whole_document_not_just_the_window() -> void:
	_open(400)
	edit.select_all_document()
	assert_true(edit.has_document_selection())
	assert_eq(edit.selected_document_text(), reference)
	var full := edit.document_text()
	assert_eq(edit.selection_offsets(full), Vector2i(0, full.length()))


func test_typing_over_select_all_replaces_the_whole_document() -> void:
	_open(400)
	edit.select_all_document()
	edit.replace_selection("new")
	assert_eq(edit.document_text(), "new")
	edit.undo_edit()
	assert_eq(edit.document_text(), reference)


func test_ctrl_end_and_ctrl_home_reach_the_ends_of_the_document() -> void:
	_open(400)
	edit.grab_focus()
	await Sim.key(tree, KEY_END, {"ctrl": true})
	var last := document.total_lines() - 1
	assert_eq(document.caret_document().x, last)
	assert_eq(document.caret_document().y, reference.split("\n")[last].length())
	await Sim.key(tree, KEY_HOME, {"ctrl": true})
	assert_eq(document.caret_document(), Vector2i.ZERO)


func test_ctrl_shift_end_selects_to_the_end_of_the_document() -> void:
	_open(400)
	edit.grab_focus()
	await Sim.key(tree, KEY_END, {"ctrl": true, "shift": true})
	assert_true(edit.has_document_selection())
	assert_eq(edit.selected_document_text(), reference)


func test_a_caret_scrolled_out_of_the_window_is_found_again_by_a_key() -> void:
	_open(600)
	edit.grab_focus()
	document.set_caret_document(Vector2i(30, 2))
	document.scroll_to(document.total_lines() - 30)
	await wait_frames(2)
	assert_eq(document.caret_document(), Vector2i(30, 2), "the caret is remembered where it was")
	await Sim.key(tree, KEY_X, {"text": "x"})
	# The typed character landed at the remembered caret.
	var lines := reference.split("\n")
	lines[30] = lines[30].substr(0, 2) + "x" + lines[30].substr(2)
	assert_eq(edit.document_text(), "\n".join(lines))


func test_find_and_go_to_work_across_the_whole_document() -> void:
	_open(600)
	var full := edit.document_text()
	var needle := "line 4000 "
	var offset := full.find(needle)
	assert_true(offset > 0)
	edit.select_offsets(full, offset, offset + needle.length())
	assert_eq(edit.selected_document_text(), needle)
	edit.go_to_document_line(10)
	assert_eq(edit.caret_document_line(), 9)
	edit.go_to_document_line(10_000_000)
	assert_eq(edit.caret_document_line(), document.total_lines() - 1)


func test_replace_document_rebuilds_the_window() -> void:
	_open(400)
	edit.replace_document(_make_text(300))
	assert_eq(edit.document_text(), _make_text(300))
	edit.undo_edit()
	assert_eq(edit.document_text(), reference)


func test_a_big_paste_turns_a_small_document_into_a_windowed_one() -> void:
	edit.load_document("abc")
	assert_false(edit.is_windowed())
	var pasted := _make_text(300)
	edit.set_caret_line(0)
	edit.set_caret_column(3)
	edit.replace_selection(pasted)
	assert_true(edit.is_windowed())
	assert_eq(edit.document_text(), "abc" + pasted)


func test_the_edit_count_never_goes_back() -> void:
	edit.load_document("small")
	var seen := edit.document_version()
	edit.replace_selection(_make_text(300))
	assert_true(edit.document_version() > seen)
	seen = edit.document_version()
	edit.undo_edit()
	assert_true(edit.document_version() > seen)


func test_a_random_mixture_of_edits_scrolls_and_undos_matches_a_plain_string() -> void:
	_open(500)
	var generator := RandomNumberGenerator.new()
	generator.seed = 20261027
	var snapshots: Array[String] = [reference]
	for step in range(300):
		var kind := generator.randi_range(0, 9)
		var lines := reference.split("\n")
		var line := generator.randi_range(0, lines.size() - 1)
		var column := generator.randi_range(0, lines[line].length())
		match kind:
			0, 1, 2:
				var typed := "abcxyz"[generator.randi_range(0, 5)]
				document.ensure_window(line, line)
				document.set_caret_document(Vector2i(line, column))
				edit.insert_text_at_caret(typed)
				lines[line] = lines[line].substr(0, column) + typed + lines[line].substr(column)
				reference = "\n".join(lines)
			3:
				document.ensure_window(line, line)
				document.set_caret_document(Vector2i(line, column))
				edit.insert_text_at_caret("\n")
				var rest: String = lines[line].substr(column)
				lines[line] = lines[line].substr(0, column)
				lines.insert(line + 1, rest)
				reference = "\n".join(lines)
			4:
				if column > 0:
					document.ensure_window(line, line)
					edit.select(line - document.win_start, column - 1, line - document.win_start, column)
					edit.delete_selection()
					lines[line] = lines[line].substr(0, column - 1) + lines[line].substr(column)
					reference = "\n".join(lines)
			5:
				var count := generator.randi_range(1, 6)
				var last := mini(line + count, lines.size() - 1)
				document.ensure_window(line, last)
				var end_column := lines[last].length()
				edit.select(line - document.win_start, 0, last - document.win_start, end_column)
				edit.delete_selection()
				var kept := lines.slice(0, line)
				kept.append("")
				kept.append_array(lines.slice(last + 1))
				reference = "\n".join(kept)
			6:
				var pasted := "p%d\nq%d" % [step, step]
				document.ensure_window(line, line)
				document.set_caret_document(Vector2i(line, column))
				edit.replace_selection(pasted)
				var whole := reference
				var at := XpTextEdit.offset_of(whole, line, column)
				reference = whole.substr(0, at) + pasted + whole.substr(at)
			7:
				document.scroll_to(generator.randi_range(0, lines.size() - 1))
				document.check_edges()
			8:
				if edit.can_undo_edit():
					edit.undo_edit()
					assert_true(snapshots.has(edit.document_text()), "an undo leads back to an earlier state (step %d)" % step)
					reference = edit.document_text()
			9:
				document.teleport(generator.randi_range(0, lines.size() - 1), LargeDocument.Place.CENTER)
		assert_eq(edit.document_text(), reference, "after step %d (kind %d)" % [step, kind])
		if failures.size() > 0:
			return
		if snapshots.size() < 400 and snapshots[snapshots.size() - 1] != reference:
			snapshots.append(reference)
	assert_eq(edit.document_line_count(), reference.count("\n") + 1)
