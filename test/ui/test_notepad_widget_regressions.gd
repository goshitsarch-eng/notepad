extends TestCase
## Behaviour of the editor and the dialogs that was once wrong, as a user sees it: focus, the
## scroll bars, white selected text, the Find box, Escape, a message box over Find, Page Setup
## and the drop-down lists. (Ported from the Flutter version's notepad_widget_regressions_test.)
##
## Not ported: nothing is left out as a whole. The check that selected text is white is made
## on the colours the text control draws with, since Godot has no TextSpan to inspect, and the
## widget-tree finders (EditableText, XpScrollBar) became the engine's own nodes.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var screen: NotepadScreen
var _extras: Array[Node] = []


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	screen = NotepadScreen.new(rig.vm)
	tree.root.add_child(screen)
	await wait_frames(3)


func after_each() -> void:
	for node in _extras:
		if is_instance_valid(node):
			node.queue_free()
	_extras.clear()
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()


func _find_button(root: Node, label: String) -> XpButton:
	if root is XpButton and (root as XpButton).label == label:
		return root as XpButton
	for child in root.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _vertical_bar_in(root: Node) -> VScrollBar:
	for child in root.get_children():
		if child is VScrollBar:
			return child as VScrollBar
	return null


# ---- Editor ----

func test_a_click_in_the_blank_area_below_short_text_keeps_focus() -> void:
	rig.vm.text.load_document("short")
	await wait_frames(2)
	assert_true(rig.vm.text.has_focus())

	var area := screen.editor.get_global_rect()
	await Sim.click(tree, Vector2(area.get_center().x, area.position.y + 150))
	await wait_frames(2)

	assert_true(rig.vm.text.has_focus())


func test_a_vertical_scroll_bar_appears_only_when_the_text_overflows() -> void:
	rig.vm.text.load_document("one line")
	await wait_frames(3)
	assert_false(rig.vm.text.get_v_scroll_bar().visible)

	var lines: Array[String] = []
	for index in range(80):
		lines.append("Line %d" % index)
	rig.vm.text.load_document("\n".join(lines))
	await wait_frames(3)
	assert_true(rig.vm.text.get_v_scroll_bar().visible)


func test_selected_text_is_white_while_the_editor_has_focus() -> void:
	rig.vm.text.load_document("abc")
	rig.select(0, 2)
	await wait_frames(2)

	assert_true(rig.vm.text.has_focus())
	assert_eq(rig.vm.text.get_selected_text(), "ab")
	assert_eq(rig.vm.text.get_theme_color("font_selected_color"), XpColors.highlight_text())
	assert_eq(rig.vm.text.get_theme_color("selection_color"), XpColors.highlight())


# ---- Dialogs ----

func test_find_asked_again_while_open_moves_focus_to_the_find_box() -> void:
	rig.vm.show_find(false)
	await wait_frames(3)
	rig.vm.show_find(false)
	await wait_frames(3)
	assert_not_null(screen.find_dialog)
	assert_eq(tree.root.gui_get_focus_owner(), screen.find_dialog.find_box)

	# Asked again with focus in the document, it comes back to the box. The click is at the
	# corner of the text, clear of the dialog in the middle of the window.
	await Sim.click(tree, screen.editor.get_global_rect().position + Vector2(10, 10))
	await wait_frames(2)
	assert_eq(tree.root.gui_get_focus_owner(), rig.vm.text)
	rig.vm.show_find(false)
	await wait_frames(3)
	assert_eq(tree.root.gui_get_focus_owner(), screen.find_dialog.find_box)


func test_ctrl_a_in_the_find_box_does_not_select_the_document() -> void:
	rig.vm.text.load_document("document text")
	await wait_frames(2)
	rig.vm.show_find(false)
	await wait_frames(3)
	await Sim.type(tree, "abc")

	await Sim.key(tree, KEY_A, {"ctrl": true})
	await wait_frames(2)

	assert_false(rig.vm.text.has_selection())
	assert_eq(rig.text(), "document text")
	# The keys went to the box, which selected its own text.
	assert_eq(screen.find_dialog.find_box.get_selected_text(), "abc")


func test_escape_cancels_a_dialog_even_when_focus_is_on_the_dialog() -> void:
	var showing := Pending.start(rig.vm.show_about)
	await wait_frames(3)
	assert_not_null(modal_of(rig.vm, Requests.AboutRequest))

	# Focus on the dialog itself, not on one of its fields.
	var owner := tree.root.gui_get_focus_owner()
	if owner != null:
		owner.release_focus()
	await wait_frames(2)
	assert_null(tree.root.gui_get_focus_owner())
	await Sim.key(tree, KEY_ESCAPE)
	await wait_frames(2)

	assert_null(rig.vm.modal())
	await showing.wait()


func test_a_message_box_is_drawn_over_the_find_dialog_and_takes_clicks() -> void:
	rig.vm.text.load_document("nothing here")
	rig.vm.show_find(false)
	await wait_frames(3)

	# No match, so the Cannot find message appears over the Find dialog.
	rig.vm.find_next(SearchOptions.new("missing"))
	await wait_frames(3)
	assert_not_null(modal_of(rig.vm, Requests.MessageRequest))
	assert_not_null(screen.modal_host)
	assert_true(screen.modal_host.get_index() > screen.find_dialog.get_index(),
		"the message box lies over the Find dialog")

	var ok := _find_button(screen.modal_host, "OK")
	await Sim.click(tree, Sim.center_of(ok))
	await wait_frames(3)
	assert_null(rig.vm.modal())


func test_page_setup_keeps_the_dialog_open_for_a_bad_margin() -> void:
	var editing := Pending.start(rig.vm.edit_page_setup)
	await wait_frames(3)
	var dialog := screen.modal_host.dialog as PageSetupDialog
	assert_not_null(dialog)
	if dialog == null:
		return

	# The top and bottom margins both start at 1.0. Six inches each leaves no room.
	assert_eq(dialog.top_box.text, "1.0")
	assert_eq(dialog.bottom_box.text, "1.0")
	for box in [dialog.top_box, dialog.bottom_box]:
		await Sim.click(tree, Sim.center_of(box))
		await Sim.key(tree, KEY_A, {"ctrl": true})
		await Sim.type(tree, "6")
	await wait_frames(2)
	assert_eq(dialog.top_box.text, "6")
	assert_eq(dialog.bottom_box.text, "6")
	await Sim.click(tree, Sim.center_of(_find_button(dialog, "OK")))
	await wait_frames(3)

	assert_not_null(modal_of(rig.vm, Requests.PageSetupRequest))
	assert_true(dialog.error_label.visible)
	assert_eq(dialog.error_label.text, "The top and bottom margins leave no room to print.")

	rig.vm.modal().complete(null)
	await editing.wait()


func test_a_list_box_shows_a_scroll_bar_only_when_its_rows_overflow() -> void:
	var short_rows := PackedStringArray()
	for index in range(4):
		short_rows.append("Item %d" % index)
	var long_rows := PackedStringArray()
	for index in range(40):
		long_rows.append("Item %d" % index)

	var short_list := XpListBox.new(short_rows, 100.0)
	short_list.position = Vector2(20, 20)
	short_list.size = Vector2(200, 100)
	var long_list := XpListBox.new(long_rows, 100.0)
	long_list.position = Vector2(260, 20)
	long_list.size = Vector2(200, 100)
	_extras.append_array([short_list, long_list])
	tree.root.add_child(short_list)
	tree.root.add_child(long_list)
	await wait_frames(3)

	assert_false(_vertical_bar_in(short_list).visible)
	assert_true(_vertical_bar_in(long_list).visible)


func test_an_encoding_list_opens_upward_and_stays_on_screen_near_the_edge() -> void:
	var labels := PackedStringArray(["ANSI", "Unicode", "Unicode big endian", "UTF-8"])
	var combo := XpComboBox.new(labels, 200.0)
	combo.selected = 3
	var window := tree.root.get_visible_rect().size
	combo.position = Vector2(0, window.y - XpMetrics.FIELD_HEIGHT)
	combo.size = Vector2(200, XpMetrics.FIELD_HEIGHT)
	_extras.append(combo)
	tree.root.add_child(combo)
	await wait_frames(2)

	await Sim.click(tree, Sim.center_of(combo))
	await wait_frames(3)
	assert_true(combo.is_open())
	var popup := tree.get_first_node_in_group("xp_open_list")
	assert_not_null(popup)
	if popup == null:
		return

	# The list is above the box, and every option is on screen, so none is clipped off the bottom.
	var list: Rect2 = popup._list_rect()
	assert_true(list.end.y <= combo.get_global_rect().position.y + 1.0,
		"the list lies above the box")
	var screen_rect := Rect2(Vector2.ZERO, window)
	for index in range(labels.size()):
		var row := Rect2(list.position.x, list.position.y + 1 + index * 16.0, list.size.x, 16.0)
		assert_true(screen_rect.encloses(row), "%s is on screen" % labels[index])

	# And a click on a row chooses it.
	await Sim.click(tree, Vector2(list.position.x + 20, list.position.y + 1 + 16.0 * 0.5))
	assert_eq(combo.selected, 0)
	assert_false(combo.is_open())
