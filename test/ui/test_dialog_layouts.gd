extends TestCase
## The layout of every dialog, checked by behaviour. The Flutter version compared each dialog
## with a golden image; this checks what those images were there to catch: the dialog opens,
## lies inside the window (or at least has its title bar there), has the right buttons with the
## default one first, puts keyboard focus where XP does, and is centred when it fits.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

const WINDOW := Vector2(600, 404)

var rig: ViewModelRig
var vm: NotepadViewModel
var screen: NotepadScreen
## A smaller stand-in for the window, when a test needs one.
var holder: Control


func after_each() -> void:
	if rig != null:
		if vm.modal() != null:
			vm.modal().complete(null)
		if vm.find_state() != null:
			vm.close_find()
		await wait_frames(2)
	if screen != null:
		screen.queue_free()
		screen = null
	if holder != null:
		holder.queue_free()
		holder = null
	await wait_frames(2)
	if rig != null:
		rig.dispose()
		rig = null


# ---- Helpers ----

func _start(window_size: Vector2 = WINDOW, initial_path: String = "") -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new(null, false)
	vm = rig.vm
	var parent: Node = tree.root
	if window_size != WINDOW:
		holder = Control.new()
		holder.size = window_size
		tree.root.add_child(holder)
		parent = holder
	screen = NotepadScreen.new(vm)
	parent.add_child(screen)
	vm.start(initial_path)
	await wait_frames(3)


func _show_dialog(command: Callable) -> Pending:
	var pending := Pending.start(command)
	await wait_frames(3)
	return pending


func _buttons_in(node: Node, found: Array[XpButton]) -> void:
	if node is XpButton:
		found.append(node)
	for child in node.get_children():
		_buttons_in(child, found)


func _labels_of(buttons: Array[XpButton]) -> Array:
	var labels: Array = []
	for button in buttons:
		labels.append(button.label)
	return labels


## Checks one open dialog. [param expected_buttons] are the labels of its buttons in order;
## the one at [param default_index] is the default (the file dialogs have the small Up button
## before it). When [param focus_on_button] is true, keyboard focus is on that button, and
## otherwise on the field the dialog opens with.
func _verify(dialog: XpDialogWindow, title: String, type: Variant, expected_buttons: Array,
		focus_on_button: bool, default_index: int = 0, window_size: Vector2 = WINDOW) -> void:
	if not assert_true(dialog != null and is_instance_of(dialog, type), "%s is not open" % title):
		return
	assert_eq(dialog.title, title)
	assert_true(dialog.is_visible_in_tree(), "%s is not visible" % title)

	# Inside the window, or when it is taller or wider than the window, at least the title bar.
	var frame := dialog.get_global_rect()
	var window := Rect2(Vector2.ZERO, window_size)
	if window.encloses(frame):
		var centre := frame.get_center()
		assert_almost_eq(centre.x, window_size.x / 2.0, 0.5, "%s is centred sideways" % title)
		assert_almost_eq(centre.y, window_size.y / 2.0, 0.5, "%s is centred up and down" % title)
	else:
		var bar := dialog.title_bar().get_global_rect()
		assert_true(bar.position.y >= 0.0 and bar.end.y <= window_size.y,
			"%s: the title bar is not inside the window (%s)" % [title, bar])
		assert_true(bar.end.x >= 48.0 and bar.position.x <= window_size.x - 48.0,
			"%s: the title bar cannot be reached (%s)" % [title, bar])
		if window_size == WINDOW:
			assert_true(frame.size.x <= window_size.x, "%s is wider than the window" % title)

	var buttons: Array[XpButton] = []
	_buttons_in(dialog, buttons)
	assert_eq(_labels_of(buttons), expected_buttons, "%s buttons" % title)
	if buttons.is_empty():
		return
	assert_true(buttons[default_index].is_default, "%s: %s is the default button" % [title, buttons[default_index].label])
	for index in range(buttons.size()):
		var button := buttons[index]
		if index != default_index:
			assert_false(button.is_default, "%s: only %s is the default button" % [title, buttons[default_index].label])
		var box := button.get_global_rect()
		assert_true(frame.encloses(box), "%s: button %s lies outside the dialog" % [title, button.label])
		var minimum_width := 40.0 if button.label == "Up" else XpMetrics.BUTTON_WIDTH
		assert_true(button.size.x >= minimum_width and button.size.y >= XpMetrics.BUTTON_HEIGHT,
			"%s: button %s is too small (%s)" % [title, button.label, button.size])
		if window.encloses(frame):
			assert_true(window.encloses(box), "%s: button %s lies outside the window" % [title, button.label])
		for other_index in range(index):
			assert_false(box.intersects(buttons[other_index].get_global_rect()),
				"%s: buttons %s and %s overlap" % [title, button.label, buttons[other_index].label])

	var close := dialog.close_button()
	if assert_not_null(close, "%s has a close button" % title):
		assert_true(dialog.title_bar().get_global_rect().encloses(close.get_global_rect()),
			"%s: the close button is outside the title bar" % title)

	var owner := tree.root.gui_get_focus_owner()
	assert_not_null(owner, "%s: nothing has focus" % title)
	if focus_on_button:
		assert_eq(owner, buttons[default_index], "%s: focus is on the default button" % title)
	else:
		assert_eq(owner, dialog.call("focus_target"), "%s: focus is on its first field" % title)
		assert_true(dialog.is_ancestor_of(owner), "%s: focus is inside the dialog" % title)


func _modal_dialog() -> XpDialogWindow:
	return screen.modal_host.dialog if screen.modal_host != null else null


func _close(pending: Pending) -> void:
	if vm.modal() != null:
		vm.modal().complete(null)
	await pending.wait()


# ---- The dialogs ----

func test_message_save_changes() -> void:
	await _start()
	rig.type_text("draft")
	var creating := await _show_dialog(vm.new_document)
	_verify(_modal_dialog(), "Notepad", MessageDialog, ["Yes", "No", "Cancel"], true)
	var dialog := _modal_dialog() as MessageDialog
	if dialog != null:
		assert_true(dialog.alert)
		assert_eq(dialog.request.text, "The text in the Untitled file has changed.\n\nDo you want to save the changes?")
	await _close(creating)


func test_message_with_a_single_ok_button() -> void:
	await _start()
	vm.find_next(SearchOptions.new("zzz"))
	await wait_frames(3)
	_verify(_modal_dialog(), "Notepad", MessageDialog, ["OK"], true)
	vm.modal().complete(Requests.MessageChoice.OK)


func test_message_with_a_long_text_still_fits_the_window() -> void:
	var long_name := "a_really_long_file_name_".repeat(12) + ".txt"
	await _start(WINDOW, "/home/tester/" + long_name)
	var dialog := _modal_dialog() as MessageDialog
	if not assert_not_null(dialog, "the 'cannot find' message is open"):
		return
	_verify(dialog, "Notepad", MessageDialog, ["OK"], true)
	assert_contains(dialog.request.text, long_name)
	# The text wraps, so the box grows taller and not wider.
	assert_true(dialog.get_global_rect().size.x <= 340.0 + 0.5, "the message box keeps its width")
	assert_true(dialog.get_global_rect().size.y > 120.0, "the message box grew to hold the text")


func test_go_to() -> void:
	await _start()
	var going := await _show_dialog(vm.show_go_to)
	_verify(_modal_dialog(), "Go To Line", GoToDialog, ["Go To", "Cancel"], false)
	await _close(going)


func test_font() -> void:
	await _start()
	var choosing := await _show_dialog(vm.show_font)
	_verify(_modal_dialog(), "Font", FontDialog, ["OK", "Cancel"], false)
	var dialog := _modal_dialog() as FontDialog
	if dialog != null:
		# The three lists, the size box and the sample are all inside the dialog.
		for control in [dialog.family_list, dialog.style_list, dialog.size_list, dialog.size_box,
				dialog.sample, dialog.script_combo]:
			assert_true(dialog.get_global_rect().encloses(control.get_global_rect()),
				"%s lies outside the Font dialog" % control)
		assert_false(dialog.error_label.visible, "no error is shown when the dialog opens")
		assert_false(dialog.script_combo.enabled)
	await _close(choosing)


func test_page_setup() -> void:
	await _start()
	var setting_up := await _show_dialog(vm.edit_page_setup)
	_verify(_modal_dialog(), "Page Setup", PageSetupDialog, ["OK", "Cancel"], false)
	var dialog := _modal_dialog() as PageSetupDialog
	if dialog != null:
		for box in [dialog.header_box, dialog.footer_box, dialog.left_box, dialog.top_box,
				dialog.right_box, dialog.bottom_box]:
			assert_true(dialog.get_global_rect().encloses(box.get_global_rect()),
				"%s lies outside the Page Setup dialog" % box.accessible_name)
		assert_false(dialog.error_label.visible)
	await _close(setting_up)


func test_page_setup_with_its_error_shown_still_fits_the_window() -> void:
	await _start()
	var setting_up := await _show_dialog(vm.edit_page_setup)
	var dialog := _modal_dialog() as PageSetupDialog
	if not assert_not_null(dialog):
		return
	dialog.top_box.text = "6"
	dialog.bottom_box.text = "6"
	dialog.submit()
	await wait_frames(3)
	assert_true(dialog.error_label.visible)
	_verify(dialog, "Page Setup", PageSetupDialog, ["OK", "Cancel"], false)
	await _close(setting_up)


func test_about() -> void:
	await _start()
	var showing := await _show_dialog(vm.show_about)
	_verify(_modal_dialog(), "About Notepad", AboutDialog, ["OK"], true)
	await _close(showing)


func test_help() -> void:
	await _start()
	var showing := await _show_dialog(vm.show_help)
	_verify(_modal_dialog(), "Notepad Help", HelpDialog, ["OK"], true)
	var dialog := _modal_dialog() as HelpDialog
	if dialog != null:
		assert_true(dialog.get_global_rect().encloses(dialog.table.get_global_rect()))
	await _close(showing)


func test_open() -> void:
	await _start()
	var opening := await _show_dialog(vm.open_document)
	_verify(_modal_dialog(), "Open", OpenSaveDialog, ["Up", "Open", "Cancel"], false, 1)
	var dialog := _modal_dialog() as OpenSaveDialog
	if dialog != null:
		for control in [dialog.look_in_combo, dialog.up_button, dialog.list, dialog.name_box,
				dialog.type_combo, dialog.encoding_combo]:
			assert_true(dialog.get_global_rect().encloses(control.get_global_rect()),
				"%s lies outside the Open dialog" % control)
		assert_eq(dialog.up_button.label, "Up")
	await _close(opening)


func test_save_as() -> void:
	await _start()
	var saving := await _show_dialog(vm.save_as)
	_verify(_modal_dialog(), "Save As", OpenSaveDialog, ["Up", "Save", "Cancel"], false, 1)
	var dialog := _modal_dialog() as OpenSaveDialog
	if dialog != null:
		for control in [dialog.look_in_combo, dialog.up_button, dialog.list, dialog.name_box,
				dialog.type_combo, dialog.encoding_combo]:
			assert_true(dialog.get_global_rect().encloses(control.get_global_rect()),
				"%s lies outside the Save As dialog" % control)
	await _close(saving)


func test_find() -> void:
	await _start()
	vm.show_find(false)
	await wait_frames(3)
	_verify(screen.find_dialog, "Find", FindDialog, ["Find Next", "Cancel"], false)
	var dialog := screen.find_dialog
	if dialog != null:
		assert_null(dialog.replace_box, "Find has no Replace with box")
		assert_not_null(dialog.up_button, "Find has the Direction group")
		assert_true(dialog.down_button.is_selected, "searching down is the default")
		assert_null(screen.modal_host, "Find is modeless")


func test_replace() -> void:
	await _start()
	vm.show_find(true)
	await wait_frames(3)
	_verify(screen.find_dialog, "Replace", FindDialog,
		["Find Next", "Replace", "Replace All", "Cancel"], false)
	var dialog := screen.find_dialog
	if dialog != null:
		assert_not_null(dialog.replace_box, "Replace has a Replace with box")
		assert_null(dialog.up_button, "Replace has no Direction group")


# ---- The smallest window ----

## The smallest window the app allows is 400 by 310. Dialogs do not shrink with it, so the most
## that can be asked is that the title bar, which drags the dialog, stays within reach.
func test_every_dialog_has_its_title_bar_within_reach_in_the_smallest_window() -> void:
	var size := Vector2(NotepadSettings.MINIMUM_WINDOW_WIDTH, NotepadSettings.MINIMUM_WINDOW_HEIGHT)
	await _start(size)
	rig.type_text("draft")
	var openers: Array = [
		["Save changes", vm.new_document, false],
		["Go To", vm.show_go_to, false],
		["Font", vm.show_font, false],
		["Page Setup", vm.edit_page_setup, false],
		["About", vm.show_about, false],
		["Help", vm.show_help, false],
		["Open", vm.open_document, false],
		["Save As", vm.save_as, false],
		["Find", vm.show_find.bind(false), true],
		["Replace", vm.show_find.bind(true), true],
	]
	for entry in openers:
		var pending: Pending = null
		if entry[2]:
			(entry[1] as Callable).call()
		else:
			pending = Pending.start(entry[1])
		await wait_frames(3)
		var dialog: XpDialogWindow = screen.find_dialog if entry[2] else _modal_dialog()
		if assert_not_null(dialog, "%s did not open" % entry[0]):
			var bar := dialog.title_bar().get_global_rect()
			assert_true(bar.position.y >= 0.0 and bar.end.y <= size.y,
				"%s: the title bar is not inside the window (%s)" % [entry[0], bar])
			assert_true(bar.end.x >= 48.0 and bar.position.x <= size.x - 48.0,
				"%s: the title bar cannot be reached (%s)" % [entry[0], bar])
		if entry[2]:
			vm.close_find()
		else:
			await _close(pending)
		await wait_frames(2)
