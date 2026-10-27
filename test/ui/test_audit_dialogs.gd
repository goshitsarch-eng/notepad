extends TestCase
## Dialog behaviour found wanting in the second audit: Open and Save As folders and typed
## paths, Go To, the Find and Replace dialogs, Page Setup, the combo box and dragging a dialog.
## Each test names its finding. (Ported from the Flutter version's audit_dialogs_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

const WINDOW := Vector2(600, 404)

var rig: ViewModelRig
var vm: NotepadViewModel
var screen: NotepadScreen
## A smaller stand-in for the window, when a test needs one.
var holder: Control
var extras: Array[Node] = []


func after_each() -> void:
	for node in extras:
		if is_instance_valid(node):
			node.queue_free()
	extras.clear()
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

## A screen on fakes. [param window_size] other than the usual one puts the screen in a
## smaller stand-in for the window.
func _start(settings: NotepadSettings = null, window_size: Vector2 = WINDOW) -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new(settings)
	vm = rig.vm
	var parent: Node = tree.root
	if window_size != WINDOW:
		holder = Control.new()
		holder.position = Vector2.ZERO
		holder.size = window_size
		tree.root.add_child(holder)
		parent = holder
	screen = NotepadScreen.new(vm)
	parent.add_child(screen)
	await wait_frames(3)


func _no_wrap() -> NotepadSettings:
	return NotepadSettings.new().copy_with({"word_wrap": false})


## Starts a view model command that opens a dialog and gives the screen time to show it.
func _open(command: Callable) -> Pending:
	var pending := Pending.start(command)
	await wait_frames(2)
	return pending


func _dialog() -> XpDialogWindow:
	return screen.modal_host.dialog


## Replaces what a text box holds by typing, as a user would: select all, then type over it.
func _replace_text(box: LineEdit, value: String) -> void:
	box.grab_focus()
	await Sim.key(tree, KEY_A, {"ctrl": true})
	if value.is_empty():
		await Sim.key(tree, KEY_BACKSPACE)
	else:
		await Sim.type(tree, value)


func _enter() -> void:
	await Sim.key(tree, KEY_ENTER)
	await wait_frames(2)


func _lines_text() -> void:
	rig.type_text("one\ntwo\nthree")
	rig.select(0, 0)
	await wait_frames(1)


## Answers the open dialog with a cancel, then waits for the command that asked for it.
func _close(pending: Pending) -> void:
	if vm.modal() != null:
		vm.modal().complete(null)
	await pending.wait()


## Waits for a command whose dialog the test has answered. One still waiting fails the test
## (and is cancelled, so that the test does not hang).
func _settle(pending: Pending) -> void:
	await wait_frames(2)
	if not pending.finished:
		fail("the command is still waiting for its dialog")
	await _close(pending)


func _selection_start() -> int:
	return vm.text.selection_offsets(vm.text.get_text()).x


# ---- Open and Save As ----

func test_f08_a_folder_path_typed_into_save_as_opens_the_folder_it_does_not_save_a_file() -> void:
	await _start()
	rig.file_system.directories["/home/tester/docs"] = true
	var saving := await _open(vm.save_as)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog() as OpenSaveDialog

	await _replace_text(dialog.name_box, "/home/tester/docs")
	await _enter()

	assert_false(request.is_done, "the dialog must stay open")
	assert_eq(rig.file_system.listed.back(), "/home/tester/docs")
	# The name that was typed is cleared, so it is not read as a file name next.
	assert_eq(dialog.name_box.text, "")

	request.complete(null)
	await _settle(saving)


func test_f08_a_name_that_is_not_a_folder_is_still_a_file_name() -> void:
	await _start()
	var saving := await _open(vm.save_as)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog() as OpenSaveDialog

	await _replace_text(dialog.name_box, "notes")
	await _enter()

	assert_true(request.is_done)
	var chosen: Requests.FileChoice = request.answer
	if assert_not_null(chosen):
		assert_eq(chosen.path, "/home/tester/notes.txt")
	await _settle(saving)


func test_a_file_name_typed_after_entering_a_typed_folder_is_saved_in_that_folder() -> void:
	await _start()
	rig.file_system.directories["/home/tester/docs"] = true
	var saving := await _open(vm.save_as)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog() as OpenSaveDialog

	await _replace_text(dialog.name_box, "/home/tester/docs")
	await _enter()
	await _replace_text(dialog.name_box, "a")
	await _enter()

	assert_true(request.is_done)
	var chosen: Requests.FileChoice = request.answer
	if assert_not_null(chosen):
		assert_eq(chosen.path, "/home/tester/docs/a.txt")
		assert_eq(chosen.encoding, FileEncoding.ANSI)
	await _settle(saving)


func test_entering_a_folder_from_the_list_keeps_the_file_name_that_was_typed() -> void:
	await _start()
	rig.file_system.listings["/home/tester"] = [
		DirectoryEntry.new("docs", "/home/tester/docs", true, 0, 0)]
	var saving := await _open(vm.save_as)
	var dialog := _dialog() as OpenSaveDialog
	await _replace_text(dialog.name_box, "report")

	# Rows start below the 18 px header and its 1 px border, and are 16 px tall.
	var row := dialog.list.get_global_rect().position + Vector2(40, 19 + 8)
	await Sim.click(tree, row)
	await Sim.click(tree, row, MOUSE_BUTTON_LEFT, true)
	await wait_frames(3)

	assert_eq(rig.file_system.listed.back(), "/home/tester/docs")
	assert_eq(dialog.name_box.text, "report", "XP keeps what you typed while you move between folders")
	await _close(saving)


func test_f11_a_folder_that_cannot_be_listed_says_why_instead_of_looking_empty() -> void:
	await _start()
	rig.file_system.unreadable["/home/tester"] = "Permission denied"
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog() as OpenSaveDialog

	assert_contains(dialog.list.problem, "This folder cannot be opened")
	assert_contains(dialog.list.problem, "Permission denied")
	assert_eq(dialog.problem, dialog.list.problem)

	request.complete(null)
	await opening.wait()


func test_f11_a_start_folder_that_has_been_deleted_falls_back_to_the_nearest_one_that_exists() -> void:
	await _start(NotepadSettings.new().copy_with({"last_directory": "/home/tester/gone/deeper"}))
	rig.file_system.missing_directories["/home/tester/gone/deeper"] = true
	rig.file_system.missing_directories["/home/tester/gone"] = true
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog() as OpenSaveDialog

	assert_eq(rig.file_system.listed, ["/home/tester/gone/deeper", "/home/tester/gone", "/home/tester"])
	assert_eq(dialog.directory, "/home/tester")
	assert_eq(dialog.problem, "", "no 'cannot be opened' message")

	request.complete(null)
	await opening.wait()


func test_a_combo_box_with_no_options_draws_instead_of_crashing() -> void:
	var combo := XpComboBox.new(PackedStringArray(), 120.0)
	combo.position = Vector2(10, 10)
	combo.size = Vector2(120, XpMetrics.FIELD_HEIGHT)
	tree.root.add_child(combo)
	extras.append(combo)
	await wait_frames(2)
	assert_true(is_instance_valid(combo))

	# Tapping it opens nothing and does not fail either.
	await Sim.click(tree, Sim.center_of(combo))
	await wait_frames(1)
	assert_false(combo.is_open())
	assert_null(tree.get_first_node_in_group("xp_open_list"))


# ---- A combo box that is not enabled ----

func _script_combo(enabled: bool) -> XpComboBox:
	var combo := XpComboBox.new(PackedStringArray(["Western", "Greek"]), 120.0)
	combo.accessible_name = "Script"
	combo.enabled = enabled
	combo.position = Vector2(10, 10)
	combo.size = Vector2(120, XpMetrics.FIELD_HEIGHT)
	tree.root.add_child(combo)
	extras.append(combo)
	return combo


func test_a_disabled_combo_box_shows_its_value_but_does_not_open_when_tapped() -> void:
	var combo := _script_combo(false)
	var picked: Array = []
	combo.changed.connect(func(index: int) -> void: picked.append(index))
	await wait_frames(2)
	assert_eq(combo.labels[combo.selected], "Western")

	await Sim.click(tree, Sim.center_of(combo))
	await wait_frames(1)

	assert_false(combo.is_open(), "the list did not open")
	assert_null(tree.get_first_node_in_group("xp_open_list"))
	assert_eq(picked, [])


func test_an_enabled_combo_box_still_opens() -> void:
	var combo := _script_combo(true)
	var picked: Array = []
	combo.changed.connect(func(index: int) -> void: picked.append(combo.labels[index]))
	await wait_frames(2)

	await Sim.click(tree, Sim.center_of(combo))
	await wait_frames(1)
	assert_true(combo.is_open())
	assert_not_null(tree.get_first_node_in_group("xp_open_list"))
	# The second row is Greek: rows are 16 px tall, below the box and a 1 px border.
	var box := combo.get_global_rect()
	await Sim.click(tree, Vector2(box.position.x + 20, box.end.y + 1 + 16 + 8))
	await wait_frames(1)

	assert_eq(picked, ["Greek"])
	assert_false(combo.is_open())


func test_a_disabled_combo_box_is_marked_as_not_enabled() -> void:
	# The Flutter test read the semantics tree. This port has no semantics tree; the box
	# carries its accessible name and its enabled flag, which is what is checked here.
	var combo := _script_combo(false)
	await wait_frames(1)
	assert_eq(combo.accessible_name, "Script")
	assert_false(combo.enabled)
	assert_eq(combo.labels[combo.selected], "Western")


# ---- Go To ----

func test_f09_the_line_number_is_selected_when_go_to_opens() -> void:
	await _start(_no_wrap())
	await _lines_text()
	var going := await _open(vm.show_go_to)
	var dialog := _dialog() as GoToDialog
	if not assert_true(dialog != null, "the Go To dialog is open"):
		return

	assert_eq(dialog.line_box.text, "1")
	assert_true(dialog.line_box.has_selection())
	assert_eq(dialog.line_box.get_selection_from_column(), 0)
	assert_eq(dialog.line_box.get_selection_to_column(), 1)

	await _close(going)


func test_f09_typing_replaces_the_selected_number_instead_of_adding_to_it() -> void:
	await _start(_no_wrap())
	await _lines_text()
	var going := await _open(vm.show_go_to)

	await Sim.type(tree, "3")
	await _enter()
	await _settle(going)

	assert_eq(vm.caret_position().x, 3)


func test_a_number_too_long_for_an_int_goes_to_the_last_line_instead_of_doing_nothing() -> void:
	await _start(_no_wrap())
	await _lines_text()
	var going := await _open(vm.show_go_to)
	var dialog := _dialog() as GoToDialog

	await _replace_text(dialog.line_box, "99999999999999999999999")
	await _enter()
	await _settle(going)

	assert_null(vm.modal(), "the dialog must accept it")
	assert_eq(vm.caret_position().x, 3)


func test_an_empty_go_to_box_keeps_the_dialog_open() -> void:
	await _start(_no_wrap())
	await _lines_text()
	var going := await _open(vm.show_go_to)
	var dialog := _dialog() as GoToDialog

	await _replace_text(dialog.line_box, "")
	await _enter()

	assert_true(vm.modal() is Requests.GoToRequest)
	await _close(going)


# ---- Find and Replace ----

func test_f09_the_last_search_text_is_selected_when_find_opens() -> void:
	await _start()
	rig.type_text("the fox jumps")
	rig.select(0, 0)
	vm.find_next(SearchOptions.new("fox"))
	vm.show_find(false)
	await wait_frames(3)

	var find_box := screen.find_dialog.find_box
	assert_eq(find_box.text, "fox")
	assert_true(find_box.has_selection())
	assert_eq(find_box.get_selection_from_column(), 0)
	assert_eq(find_box.get_selection_to_column(), 3)


func test_f17_replace_searches_down_even_after_an_earlier_find_went_up() -> void:
	await _start()
	rig.type_text("a b a b a")
	rig.select(9, 9)
	vm.find_next(SearchOptions.new("b", false, false, false))
	assert_false(vm.last_search().forward)

	vm.show_find(true)
	await wait_frames(3)
	rig.select(0, 0)
	await Sim.click(tree, Sim.center_of(screen.find_dialog.find_next_button))
	await wait_frames(3)

	assert_true(vm.last_search().forward)
	assert_eq(_selection_start(), 2, "the first b after the start")


func test_f18_the_arrow_keys_move_between_the_direction_buttons() -> void:
	await _start()
	rig.type_text("x x x x x")
	vm.show_find(false)
	await wait_frames(3)
	var dialog := screen.find_dialog
	await _replace_text(dialog.find_box, "x")

	# The caret is put back in the middle before each search, so both directions always have
	# a match and no "Cannot find" message gets in the way.
	var search_goes_down := func() -> bool:
		rig.select(4, 4)
		await Sim.click(tree, Sim.center_of(dialog.find_next_button))
		await wait_frames(3)
		assert_null(vm.modal())
		return vm.last_search().forward

	# Down is the default. A click focuses the Up button, then the keys move.
	await Sim.click(tree, Sim.center_of(dialog.up_button))
	await wait_frames(2)
	assert_false(await search_goes_down.call())

	await Sim.click(tree, Sim.center_of(dialog.up_button))
	await wait_frames(2)
	await Sim.key(tree, KEY_RIGHT)
	await wait_frames(2)
	assert_true(await search_goes_down.call())

	await Sim.click(tree, Sim.center_of(dialog.down_button))
	await wait_frames(2)
	await Sim.key(tree, KEY_LEFT)
	await wait_frames(2)
	assert_false(await search_goes_down.call())

	# And the up and down arrows do the same.
	await Sim.click(tree, Sim.center_of(dialog.up_button))
	await wait_frames(2)
	await Sim.key(tree, KEY_DOWN)
	await wait_frames(2)
	assert_true(await search_goes_down.call())
	await Sim.click(tree, Sim.center_of(dialog.down_button))
	await wait_frames(2)
	await Sim.key(tree, KEY_UP)
	await wait_frames(2)
	assert_false(await search_goes_down.call())


# ---- Page Setup ----

func _open_page_setup() -> Pending:
	await _start()
	return await _open(vm.edit_page_setup)


func test_f06_enter_in_a_margin_box_accepts_the_dialog() -> void:
	var setting_up := await _open_page_setup()
	var dialog := _dialog() as PageSetupDialog
	assert_eq(dialog.left_box.text, "0.75")

	await _replace_text(dialog.left_box, "2")
	await _enter()
	await _settle(setting_up)

	assert_null(vm.modal())
	assert_eq(rig.settings.saved.page_setup.left_inches, 2.0)


func test_f06_enter_in_the_header_box_accepts_the_dialog_too() -> void:
	var setting_up := await _open_page_setup()
	var dialog := _dialog() as PageSetupDialog
	assert_eq(dialog.header_box.text, "&f")

	await _replace_text(dialog.header_box, "My notes")
	await _enter()
	await _settle(setting_up)

	assert_null(vm.modal())
	assert_eq(rig.settings.saved.page_setup.header, "My notes")


func test_f06_enter_with_a_bad_margin_keeps_the_dialog_open_and_says_why() -> void:
	var setting_up := await _open_page_setup()
	var dialog := _dialog() as PageSetupDialog
	assert_eq(dialog.top_box.text, "1.0")

	await _replace_text(dialog.top_box, "6")
	await _replace_text(dialog.bottom_box, "6")
	await _enter()

	assert_true(vm.modal() is Requests.PageSetupRequest)
	assert_true(dialog.error_label.visible)
	assert_eq(dialog.error_label.text, "The top and bottom margins leave no room to print.")
	await _close(setting_up)


# ---- F-20: a dialog cannot be dragged out of reach ----

func _open_go_to() -> Pending:
	await _start(_no_wrap())
	return await _open(vm.show_go_to)


## Drags the title bar of the dialog from its middle by [param delta], in one move.
func _drag_title(dialog: XpDialogWindow, delta: Vector2) -> void:
	var start := Sim.center_of(dialog.title_bar())
	await Sim.press(tree, start)
	await Sim.move(tree, start + delta)
	await Sim.release(tree, start + delta)
	await wait_frames(2)


func test_f20_dragged_far_beyond_the_right_and_bottom_edges_the_title_bar_stays_inside() -> void:
	var going := await _open_go_to()
	var dialog := _dialog()

	await _drag_title(dialog, Vector2(5000, 5000))

	var frame := dialog.get_global_rect()
	assert_true(frame.position.x <= 600 - 48, "a grip stays on screen sideways (left is %s)" % frame.position.x)
	assert_true(frame.position.y <= 404 - XpMetrics.DIALOG_TITLE_HEIGHT, "top is %s" % frame.position.y)
	assert_true(frame.position.y > 100, "it did move down (top is %s)" % frame.position.y)
	await _close(going)


func test_f20_dragged_beyond_the_left_and_top_edges_the_title_bar_stays_inside() -> void:
	var going := await _open_go_to()
	var dialog := _dialog()

	await _drag_title(dialog, Vector2(-5000, -5000))

	var frame := dialog.get_global_rect()
	assert_true(frame.position.y >= 0, "top is %s" % frame.position.y)
	assert_true(frame.end.x >= 48, "right is %s" % frame.end.x)
	assert_true(frame.position.x < 0, "it did move left (left is %s)" % frame.position.x)
	await _close(going)


func test_f20_the_dialog_follows_the_pointer_back_at_once_with_no_dead_zone() -> void:
	var going := await _open_go_to()
	var dialog := _dialog()
	var start := Sim.center_of(dialog.title_bar())

	# Far past the edge, then a short drag back. It must move on the first pixels back.
	await Sim.press(tree, start)
	await Sim.move(tree, start + Vector2(5000, 0))
	await wait_frames(1)
	var pinned := dialog.get_global_rect().position.x
	await Sim.move(tree, start + Vector2(5000 - 40, 0))
	await wait_frames(1)
	var backed := dialog.get_global_rect().position.x
	await Sim.release(tree, start + Vector2(5000 - 40, 0))

	assert_eq(pinned, 600.0 - 48.0, "stopped at the edge")
	assert_eq(backed, pinned - 40.0)
	await _close(going)


func test_f20_a_dialog_taller_than_the_window_starts_with_its_title_bar_at_the_top_edge() -> void:
	# Open wants about 380 px, and the smallest window is 310.
	await _start(null, Vector2(NotepadSettings.MINIMUM_WINDOW_WIDTH, NotepadSettings.MINIMUM_WINDOW_HEIGHT))
	var opening := await _open(vm.open_document)
	var dialog := _dialog()

	var frame := dialog.get_global_rect()
	assert_true(frame.size.y > NotepadSettings.MINIMUM_WINDOW_HEIGHT, "the dialog is taller than this window")
	assert_eq(frame.position.y, 0.0)
	# The Flutter dialog was also squeezed to the window's height. This one keeps its size,
	# since its content has a fixed height, and only its title bar is held inside.
	await _close(opening)


func test_f20_a_dialog_that_fits_starts_centred_exactly_where_it_did_before() -> void:
	var going := await _open_go_to()
	var dialog := _dialog()

	var centre := dialog.get_global_rect().get_center()
	assert_almost_eq(centre.x, 300.0, 0.01)
	assert_almost_eq(centre.y, 202.0, 0.01)
	await _close(going)
