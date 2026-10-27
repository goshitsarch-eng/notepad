extends TestCase
## The real screen driven as a user would: shortcuts, menus, Find and the caption. (Ported from
## the Flutter version's notepad_interaction_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var screen: NotepadScreen


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	screen = NotepadScreen.new(rig.vm)
	tree.root.add_child(screen)
	await wait_frames(3)


func after_each() -> void:
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()


## Clicks into the text, as the Dart tests tap the editable text.
func _click_text() -> void:
	await Sim.click(tree, Sim.center_of(screen.editor))
	await wait_frames(1)


## The centre of the row at [param index] of the open popup, in window coordinates.
func _row_center(index: int) -> Vector2:
	var top := 3.0
	for position in range(index):
		top += XpMenuLayout.SEPARATOR_HEIGHT if screen.popup.items[position].is_separator else XpMetrics.MENU_ROW_HEIGHT
	return screen.popup.get_global_rect().position + Vector2(40, top + XpMetrics.MENU_ROW_HEIGHT / 2.0)


## The centre of the label of menu [param index] in the menu bar.
func _label_center(index: int) -> Vector2:
	var span := screen.menu_bar.label_span(index)
	return screen.menu_bar.get_global_rect().position + Vector2(span.x + span.y / 2.0, XpMetrics.MENU_BAR_HEIGHT / 2.0)


func _message_button(label: String) -> XpButton:
	for button in (screen.modal_host.dialog as MessageDialog).buttons():
		if button.label == label:
			return button
	fail("the message box has no %s button" % label)
	return null


func test_ctrl_n_on_an_untouched_document_asks_nothing() -> void:
	await Sim.key(tree, KEY_N, {"ctrl": true})
	await wait_frames(2)
	assert_null(rig.vm.modal())


func test_ctrl_n_after_typing_asks_to_save_and_no_discards_the_text() -> void:
	await Sim.type(tree, "draft")
	assert_true(rig.vm.is_modified())

	await Sim.key(tree, KEY_N, {"ctrl": true})
	await wait_frames(3)
	assert_not_null(modal_of(rig.vm, Requests.MessageRequest))
	assert_not_null(screen.modal_host)
	await Sim.click(tree, Sim.center_of(_message_button("No")))
	await wait_frames(2)

	assert_eq(rig.text(), "")
	assert_null(rig.vm.modal())


func test_alt_f_opens_the_file_menu_and_escape_closes_it() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key(tree, KEY_F, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	await wait_frames(1)
	assert_eq(rig.vm.open_menu(), 0)
	var labels: Array[String] = []
	for item in screen.popup.items:
		labels.append(MenuLabel.parse(item.label).text)
	assert_contains(labels, "Open...")

	await Sim.key(tree, KEY_ESCAPE)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_clicking_a_menu_label_opens_it_and_clicking_an_item_runs_it() -> void:
	await Sim.type(tree, "to be cleared")

	await Sim.click(tree, _label_center(0))
	assert_eq(rig.vm.open_menu(), 0)
	assert_eq(MenuLabel.parse(screen.popup.items[6].label).text, "Print...")

	await Sim.click(tree, _row_center(6))
	await wait_frames(2)

	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)
	assert_eq(rig.printing.printed_text, ["to be cleared"] as Array[String])


func test_tab_inserts_a_tab_character_instead_of_moving_focus() -> void:
	await _click_text()
	await Sim.key(tree, KEY_TAB)
	assert_eq(rig.text(), "\t")
	assert_eq(tree.root.gui_get_focus_owner(), rig.vm.text)


func test_f5_inserts_the_time_and_date() -> void:
	await _click_text()
	await Sim.key(tree, KEY_F5)
	var pattern := RegEx.create_from_string("^\\d{1,2}:\\d{2} (AM|PM) \\d{1,2}/\\d{1,2}/\\d{4}$")
	assert_not_null(pattern.search(rig.text()), "the time and date, got \"%s\"" % rig.text())


func test_ctrl_f_opens_find_and_find_next_selects_the_match() -> void:
	rig.vm.text.load_document("alpha beta alpha")
	await wait_frames(1)

	await Sim.key(tree, KEY_F, {"ctrl": true})
	await wait_frames(2)
	assert_not_null(rig.vm.find_state())
	assert_false(rig.vm.find_state().replace)
	assert_not_null(screen.find_dialog)

	await Sim.type(tree, "alpha")
	assert_eq(screen.find_dialog.find_box.text, "alpha")
	await Sim.click(tree, Sim.center_of(screen.find_dialog.find_next_button))
	await wait_frames(1)

	assert_eq(rig.vm.text.selection_offsets(rig.text()), Vector2i(0, 5))


func test_f3_repeats_the_last_search_without_opening_find() -> void:
	rig.vm.text.load_document("one two one")
	await wait_frames(1)
	rig.vm.find_next(SearchOptions.new("one"))
	await wait_frames(1)

	await Sim.key(tree, KEY_F3)

	assert_null(rig.vm.find_state())
	assert_eq(rig.vm.text.selection_offsets(rig.text()), Vector2i(8, 11))


func test_escape_closes_the_find_dialog() -> void:
	await Sim.key(tree, KEY_F, {"ctrl": true})
	await wait_frames(2)
	assert_not_null(rig.vm.find_state())

	await Sim.key(tree, KEY_ESCAPE)

	assert_null(rig.vm.find_state())


func test_format_word_wrap_turns_wrapping_off_and_shows_the_status_bar() -> void:
	assert_false(screen.status_bar.visible)
	assert_true(rig.vm.word_wrap())

	await Sim.click(tree, _label_center(2))
	assert_eq(MenuLabel.parse(screen.popup.items[0].label).text, "Word Wrap")
	await Sim.click(tree, _row_center(0))
	await wait_frames(2)

	assert_false(rig.vm.word_wrap())
	assert_true(screen.status_bar.visible)
	assert_contains(screen.status_bar.text, "Ln 1, Col 1")


func test_the_caption_close_button_closes_an_unmodified_window() -> void:
	await Sim.click(tree, Sim.center_of(screen.caption.close_button()))
	await wait_frames(2)
	assert_true(rig.window.closed)
