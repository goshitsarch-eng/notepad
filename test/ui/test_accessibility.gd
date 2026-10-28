extends TestCase
## F-15: the interface used to expose nothing to a screen reader. These tests read what each
## control tells assistive technology, in the way the engine passes it on, so a control that
## loses its name, role or state fails here. (Ported from the Flutter version's semantics_test.)
##
## They cannot replace a trial with a real screen reader. Not ported: "drag-only areas are not
## offered as scrollable nodes", which the Flutter version needed because its gestures made
## nodes scrollable. Here no control offers a scroll action: the caption, the resize edges and
## the size grip are plain controls that describe nothing, and the title bar is only named.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

const WINDOW := Vector2(600, 404)

var rig: ViewModelRig
var vm: NotepadViewModel
var screen: NotepadScreen


func before_each() -> void:
	Clipboard.set_text("")
	XpColors.dark = false
	rig = ViewModelRig.new()
	vm = rig.vm
	screen = NotepadScreen.new(vm)
	tree.root.add_child(screen)
	await wait_frames(3)


func after_each() -> void:
	if vm.modal() != null:
		vm.modal().complete(null)
	if vm.find_state() != null:
		vm.close_find()
	await wait_frames(2)
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()


# ---- Reading what the controls say ----

## Every description in the window, as an assistive technology would walk them: the control
## itself, then its rows. Each carries "hidden" when it lies outside an open dialog.
func _all() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_collect(tree.root, found)
	return found


func _collect(node: Node, found: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		var hidden := XpAccessibility.is_hidden(control)
		var info: Dictionary = {}
		if control.has_method("accessibility_info"):
			info = control.call("accessibility_info")
		elif control is Label and not (control as Label).text.is_empty():
			info = {"role": "text", "name": (control as Label).text}
		elif control is TextEdit or control is LineEdit:
			info = {"role": "text_field", "name": control.accessibility_name}
		if not info.is_empty() and control.is_visible_in_tree():
			var entry := info.duplicate()
			entry["hidden"] = hidden
			entry["control"] = control
			found.append(entry)
			for row: Dictionary in info.get("children", []):
				var child_entry := row.duplicate()
				child_entry["hidden"] = hidden
				child_entry["control"] = control
				found.append(child_entry)
	for child in node.get_children():
		_collect(child, found)


## The first description named exactly [param name] that an assistive technology can reach.
func _node(name: String, role: String = "") -> Dictionary:
	for entry in _all():
		if entry.get("name", "") == name and not entry["hidden"] and (role.is_empty() or entry["role"] == role):
			return entry
	fail("no node is named \"%s\"" % name)
	return {}


func _has(name: String) -> bool:
	for entry in _all():
		if entry.get("name", "") == name and not entry["hidden"]:
			return true
	return false


func _has_matching(pattern: String) -> bool:
	var expression := RegEx.create_from_string(pattern)
	for entry in _all():
		if not entry["hidden"] and expression.search(String(entry.get("name", ""))) != null:
			return true
	return false


func _frames() -> void:
	await wait_frames(3)


func _open_menu(index: int) -> void:
	vm.open_menu_at(index, true)
	await _frames()


## True when [param entry] can be pressed by assistive technology.
func _can_press(entry: Dictionary) -> bool:
	return entry.has("action") and (entry["action"] as Callable).is_valid()


func _press(entry: Dictionary) -> void:
	(entry["action"] as Callable).call({})
	await _frames()


# ---- The window ----

func test_the_caption_buttons_are_named_buttons() -> void:
	for name in ["Minimize", "Maximize", "Close"]:
		var entry := _node(name, "button")
		assert_false(entry.is_empty(), name)
		assert_true(_can_press(entry), "%s can be pressed" % name)


func test_the_icon_of_the_title_bar_is_the_button_of_the_window_menu() -> void:
	var entry := _node("Window menu")
	assert_eq(entry.get("role"), "button")
	assert_true(_can_press(entry))

	await _press(entry)
	assert_eq(vm.open_menu(), NotepadScreen.SYSTEM_MENU, "pressing it opens the window menu")
	# The menu names its commands as the menus of the menu bar do.
	for name in ["Minimize", "Maximize", "Close"]:
		var found := false
		for item in _all():
			if item["role"] == "menu_item" and String(item.get("name", "")).begins_with(name):
				found = true
		assert_true(found, name)
	var is_menu := false
	for item in _all():
		is_menu = is_menu or item["role"] == "menu"
	assert_true(is_menu)


func test_the_menu_bar_names_its_menus_as_menu_items() -> void:
	for name in ["File", "Edit", "Format", "View", "Help"]:
		var entry := _node(name, "menu_item")
		assert_false(entry.is_empty(), name)
		assert_true(_can_press(entry), "%s can be pressed" % name)


func test_the_menu_bar_says_which_menu_is_open() -> void:
	assert_false(_node("File", "menu_item").get("expanded", false))
	await _open_menu(0)
	assert_true(_node("File", "menu_item").get("expanded", false))
	var save := _node("Save")
	assert_eq(save["role"], "menu_item")
	assert_true(_can_press(save))


func test_pressing_a_menu_of_the_bar_opens_it() -> void:
	vm.text.replace_document("some text")
	await _press(_node("Edit", "menu_item"))
	assert_eq(vm.open_menu(), 1)
	await _press(_node("Select All"))
	assert_eq(vm.open_menu(), NotepadViewModel.NO_MENU, "choosing an item closes the menu")


func test_the_text_editor_is_named() -> void:
	assert_true(_has("Text editor"))
	assert_eq(_node("Text editor")["role"], "text_field")


func test_the_status_bar_says_the_line_and_column() -> void:
	# Word wrap is on by default, which hides the bar. Turning it off shows the bar.
	vm.toggle_word_wrap()
	await _frames()
	assert_true(_has_matching("Ln 1, Col 1"))
	var found := false
	for entry in _all():
		found = found or entry["control"] is XpStatusBar
	assert_true(found)


# ---- Menus ----

func test_a_menu_item_says_its_shortcut_and_whether_it_is_available() -> void:
	await _open_menu(0)
	var new_item := _node("New")
	assert_eq(new_item["role"], "menu_item")
	assert_eq(new_item.get("shortcut"), "Ctrl+N")
	assert_false(new_item.get("disabled", false))
	assert_true(_can_press(new_item))

	vm.close_menu()
	await _open_menu(1)
	# Nothing is selected, so Cut is unavailable.
	var cut := _node("Cut")
	assert_true(cut.get("disabled", false))
	assert_false(_can_press(cut), "an item that is unavailable cannot be pressed")


func test_a_check_item_announces_its_state_and_the_state_follows_the_setting() -> void:
	await _open_menu(2)
	var wrap := _node("Word Wrap")
	assert_eq(wrap["role"], "menu_item_check")
	assert_true(wrap.get("checked"))

	vm.toggle_word_wrap()
	await _frames()
	assert_false(_node("Word Wrap").get("checked"))


func test_an_item_that_is_not_a_check_item_is_not_announced_as_one() -> void:
	await _open_menu(2)
	var font := _node("Font...")
	assert_eq(font["role"], "menu_item")
	assert_false(font.has("checked"))


func test_the_highlighted_item_is_the_selected_one() -> void:
	await _open_menu(0)
	screen.popup.highlight = 0
	assert_true(_node("New").get("selected"))
	assert_false(_node("Open...").get("selected"))


# ---- Dialogs ----

func test_a_dialog_is_announced_by_its_title_and_its_fields_and_buttons_are_named() -> void:
	Pending.start(vm.show_go_to)
	await _frames()

	var dialog := _node("Go To Line")
	assert_eq(dialog["role"], "dialog")
	assert_true(dialog.get("modal"))
	assert_eq(_node("Line number")["role"], "text_field")
	for name in ["Go To", "Cancel"]:
		var entry := _node(name)
		assert_true(entry["role"] == "button" or entry["role"] == "default_button", name)
		assert_true(_can_press(entry), name)


func test_a_message_box_is_an_alert_dialog_with_named_buttons() -> void:
	vm.find_next(SearchOptions.new("missing"))
	await _frames()

	assert_not_null(vm.modal())
	var dialog := _node("Notepad", "dialog")
	assert_true(dialog.get("alert"), "a message box is announced at once")
	assert_true(dialog.get("modal"))
	assert_true(_can_press(_node("OK")))


func test_check_boxes_expose_their_label_and_state_and_follow_a_press() -> void:
	vm.show_find(false)
	await _frames()

	var box := _node("Match case")
	assert_eq(box["role"], "check_box")
	assert_false(box.get("checked"))
	assert_true(_can_press(box))
	assert_false(_node("Find").get("modal"), "Find leaves the window usable")

	await _press(box)
	assert_true(_node("Match case").get("checked"))
	assert_true(_has("Find what"))


func test_radio_buttons_expose_which_one_is_chosen() -> void:
	vm.show_find(false)
	await _frames()

	assert_eq(_node("Down")["role"], "radio_button")
	assert_true(_node("Down").get("checked"))
	assert_eq(_node("Up")["role"], "radio_button")
	assert_false(_node("Up").get("checked"))

	await _press(_node("Up"))
	assert_true(_node("Up").get("checked"))
	assert_false(_node("Down").get("checked"))


func test_the_font_dialog_names_its_lists_size_box_and_script_box() -> void:
	Pending.start(vm.show_font)
	await _frames()

	assert_true(_has("Font"))
	assert_true(_has("Font style"))
	assert_true(_has("Size"))
	# The script box is a named button whose value is the script it shows. It is not enabled:
	# the editor draws every font the same way, so there is nothing to choose.
	var script := _node("Script")
	assert_eq(script["role"], "button")
	assert_eq(script.get("value"), "Western")
	assert_true(script.get("disabled", false))
	# The chosen font is marked selected in its list.
	var chosen := _node("Lucida Console", "list_option")
	assert_true(chosen.get("selected"))
	assert_true(_can_press(chosen))
	assert_false(_node("Arial", "list_option").get("selected"))


func test_the_open_dialog_names_its_folder_type_and_file_name_controls() -> void:
	Pending.start(vm.open_document)
	await _frames()

	assert_eq(_node("Look in")["role"], "button")
	assert_false(String(_node("Look in").get("value", "")).is_empty(), "it shows the folder")
	assert_eq(_node("Files of type").get("value"), "Text Documents (*.txt)")
	assert_true(_has("File name"))
	assert_eq(_node("Open", "dialog")["role"], "dialog")
	assert_true(_has("Files"), "the file list is named")


func test_the_page_setup_fields_are_named() -> void:
	Pending.start(vm.edit_page_setup)
	await _frames()

	for name in ["Header", "Footer", "Left margin", "Right margin", "Top margin", "Bottom margin"]:
		assert_true(_has(name), name)


# ---- What a screen reader can reach ----

func test_the_buttons_of_a_message_box_are_separate_nodes_that_can_each_be_pressed() -> void:
	vm.text.replace_document("changed")
	Pending.start(vm.new_document)
	await _frames()

	# The Save changes box has three buttons. A screen reader must be able to tell which of
	# them a press would use.
	for name in ["Yes", "No", "Cancel"]:
		var entry := _node(name)
		assert_true(entry["role"] == "button" or entry["role"] == "default_button", name)
		assert_true(_can_press(entry), name)
	assert_true(_has_matching("Do you want to save the changes"),
		"the question is a node of its own, not merged into a button")


func test_pressing_a_button_by_assistive_technology_answers_the_dialog() -> void:
	vm.text.replace_document("changed")
	var pending := Pending.start(vm.new_document)
	await _frames()

	await _press(_node("No"))
	assert_null(vm.modal(), "the dialog is answered")
	await pending.wait()
	assert_eq(vm.text.document_text(), "", "No discards the changes and starts a new document")


func test_the_window_behind_an_open_dialog_is_hidden_from_assistive_technology() -> void:
	assert_true(_has("File"))
	assert_true(_has("Text editor"))

	Pending.start(vm.show_about)
	await _frames()

	assert_false(_has("File"))
	assert_false(_has("Text editor"))
	assert_true(_has("About Notepad"))

	vm.modal().complete(true)
	await _frames()
	assert_true(_has("File"))
	assert_true(_has("Text editor"))


func test_nothing_is_hidden_once_the_dialog_is_gone() -> void:
	Pending.start(vm.show_about)
	await _frames()
	assert_not_null(XpAccessibility.modal_root)

	vm.modal().complete(true)
	await _frames()
	assert_null(XpAccessibility.modal_root)
	for entry in _all():
		assert_false(entry["hidden"], str(entry.get("name")))


func test_the_title_bar_is_named_and_can_be_pressed_by_nothing() -> void:
	var title := _node("Untitled - Notepad", "title_bar")
	assert_false(title.is_empty())
	assert_false(_can_press(title), "dragging the bar is not an action for assistive technology")


func test_the_list_of_a_dialog_rows_follow_its_scroll_position() -> void:
	# A row scrolled out of view lies outside the box, so a reader does not offer it as on screen.
	var box := XpListBox.new(PackedStringArray(["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]), 40.0)
	tree.root.add_child(box)
	box.size = Vector2(100, 40)
	await wait_frames(2)
	var rows: Array = box.accessibility_info()["children"]
	assert_eq(rows.size(), 10)
	assert_eq(rows[0]["rect"].position.y, 1.0)
	box._scroll.value = 3
	rows = box.accessibility_info()["children"]
	assert_eq(rows[3]["rect"].position.y, 1.0)
	assert_true(rows[0]["rect"].position.y < 0.0)
	box.queue_free()
	await wait_frames(1)
