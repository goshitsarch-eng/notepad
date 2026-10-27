extends TestCase
## The dialog and focus parts of the findings regression tests, on the real screen: a size typed
## into the Font dialog (F-01), dialogs and the Find box that take keyboard focus (F-02, F-03),
## the editor that must take text after the document is replaced (F-04), and a file that loads
## while the user types (F-05). (Ported from the Flutter version's findings_regression_test.
## The view-model-only half of it is in test_findings_view_model.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var vm: NotepadViewModel
var screen: NotepadScreen


func after_each() -> void:
	if rig != null:
		rig.documents.release_reads()
		if vm.modal() != null:
			vm.modal().complete(null)
		if vm.find_state() != null:
			vm.close_find()
		await wait_frames(2)
	if screen != null:
		screen.queue_free()
		screen = null
	await wait_frames(2)
	if rig != null:
		rig.dispose()
		rig = null


# ---- Helpers ----

## A screen on fakes. With [param initial_path] the view model starts by opening that file,
## after the screen is up, as the app does.
func _start(initial_path: String = "") -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new(null, false)
	vm = rig.vm
	screen = NotepadScreen.new(vm)
	tree.root.add_child(screen)
	vm.start(initial_path)
	await wait_frames(3)


func _open(command: Callable) -> Pending:
	var pending := Pending.start(command)
	await wait_frames(2)
	return pending


func _dialog() -> XpDialogWindow:
	return screen.modal_host.dialog


func _buttons_in(node: Node, label: String, found: Array[XpButton]) -> void:
	if node is XpButton and (node as XpButton).label == label:
		found.append(node)
	for child in node.get_children():
		_buttons_in(child, label, found)


## The button labelled [param label] in the open dialog.
func _button(label: String) -> XpButton:
	var found: Array[XpButton] = []
	if screen.modal_host != null:
		_buttons_in(screen.modal_host, label, found)
	if found.is_empty():
		fail("no button labelled %s in the open dialog" % label)
		return null
	return found[0]


func _press(label: String) -> void:
	var button := _button(label)
	if button != null:
		await Sim.click(tree, Sim.center_of(button))
	await wait_frames(2)


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


## True when keyboard focus sits inside [param node].
func _focus_in(node: Node) -> bool:
	if node == null:
		return false
	var owner := tree.root.gui_get_focus_owner()
	return owner != null and (owner == node or node.is_ancestor_of(owner))


func _close(pending: Pending) -> void:
	if vm.modal() != null:
		vm.modal().complete(null)
	await pending.wait()


# ---- F-01: a size typed into the Font Size box is applied by OK ----

func test_f01_a_typed_size_is_kept_when_ok_is_pressed() -> void:
	await _start()
	var choosing := await _open(vm.show_font)
	var dialog := _dialog() as FontDialog

	await _replace_text(dialog.size_box, "14")
	await _press("OK")
	await choosing.wait()

	assert_null(vm.modal())
	assert_eq(vm.font().size_points, 14.0)


func test_f01_an_out_of_range_size_keeps_the_dialog_open_and_says_why() -> void:
	await _start()
	var choosing := await _open(vm.show_font)
	var dialog := _dialog() as FontDialog

	await _replace_text(dialog.size_box, "1700")
	await _press("OK")

	assert_true(vm.modal() is Requests.FontRequest)
	assert_eq(vm.font().size_points, 10.0)
	assert_true(dialog.error_label.visible)
	assert_contains(dialog.error_label.text, "1638")
	await _close(choosing)


# ---- F-02: dialogs take keyboard focus, so typing cannot edit the document ----

func test_f02_the_font_dialog_takes_focus_when_it_opens() -> void:
	await _start()
	var choosing := await _open(vm.show_font)

	assert_true(_focus_in(_dialog()), "focus is not inside the Font dialog")
	await _close(choosing)


func test_f02_typing_while_the_font_dialog_is_open_leaves_the_document_alone() -> void:
	await _start()
	var choosing := await _open(vm.show_font)

	await Sim.type(tree, "zz")
	await wait_frames(1)

	assert_eq(rig.text(), "")
	assert_false(vm.is_modified())
	await _close(choosing)


func test_f02_escape_closes_the_font_dialog_and_keeps_the_font() -> void:
	await _start()
	var choosing := await _open(vm.show_font)

	await Sim.key(tree, KEY_ESCAPE)
	await wait_frames(2)
	await choosing.wait()

	assert_null(vm.modal())
	assert_eq(vm.font().size_points, 10.0)


func test_f02_the_arrow_keys_choose_a_family_in_the_font_list() -> void:
	await _start()
	var choosing := await _open(vm.show_font)

	await Sim.key(tree, KEY_DOWN)
	await _press("OK")
	await choosing.wait()

	var current := EditorFont.FAMILIES.find("Lucida Console")
	assert_true(current >= 0 and current + 1 < EditorFont.FAMILIES.size())
	assert_eq(vm.font().family, EditorFont.FAMILIES[current + 1])


func test_f02_every_dialog_and_the_find_box_take_focus_when_they_open() -> void:
	await _start()
	# Each opener, with the dialog it should open.
	var openers: Array = [
		["Font", vm.show_font, FontDialog, false],
		["Page Setup", vm.edit_page_setup, PageSetupDialog, false],
		["Go To", vm.show_go_to, GoToDialog, false],
		["About", vm.show_about, AboutDialog, false],
		["Help", vm.show_help, HelpDialog, false],
		["Open", vm.open_document, OpenSaveDialog, false],
		["Save As", vm.save_as, OpenSaveDialog, false],
		["Find", vm.show_find.bind(false), FindDialog, true],
		["Replace", vm.show_find.bind(true), FindDialog, true],
	]
	for entry in openers:
		var label: String = entry[0]
		var pending: Pending = null
		if entry[3]:
			(entry[1] as Callable).call()
		else:
			pending = Pending.start(entry[1])
		await wait_frames(3)
		var dialog: Node = screen.find_dialog if entry[3] else (
			screen.modal_host.dialog if screen.modal_host != null else null)
		if assert_true(dialog != null and is_instance_of(dialog, entry[2]), "%s did not open" % label):
			assert_true(_focus_in(dialog), "%s has no focus" % label)
		await Sim.key(tree, KEY_ESCAPE)
		if vm.find_state() != null:
			vm.close_find()
		await wait_frames(3)
		if pending != null:
			assert_true(pending.finished, "Escape did not close %s" % label)
			await _close(pending)


# ---- F-03: Find keeps focus in its box ----

func test_f03_enter_runs_find_next_and_leaves_focus_in_the_find_box() -> void:
	await _start()
	vm.insert_text("the quick fox")
	# Find Next searches forward from the caret, so the caret goes to the start first.
	vm.text.set_caret_line(0)
	vm.text.set_caret_column(0)
	vm.show_find(false)
	await wait_frames(3)

	await _replace_text(screen.find_dialog.find_box, "fox")
	await _enter()

	assert_eq(vm.text.get_selected_text(), "fox", "Find Next ran")
	assert_true(_focus_in(screen.find_dialog))


func test_f03_after_a_cannot_find_message_closes_focus_returns_to_the_find_box() -> void:
	await _start()
	vm.show_find(false)
	await wait_frames(3)

	await _replace_text(screen.find_dialog.find_box, "zzz")
	await _enter()
	assert_true(vm.modal() is Requests.MessageRequest)

	await _press("OK")

	assert_null(vm.modal())
	assert_true(_focus_in(screen.find_dialog))
	assert_eq(screen.find_dialog.find_box.text, "zzz", "what was typed is kept")


# ---- F-04: the editor accepts text after the document is replaced ----

func test_f04_typing_reaches_the_editor_after_file_new() -> void:
	await _start()
	await Sim.click(tree, Sim.center_of(screen.editor))
	await wait_frames(1)

	var creating := await _open(vm.new_document)
	await creating.wait()
	await wait_frames(2)

	assert_eq(tree.root.gui_get_focus_owner(), vm.text, "the editor has focus")
	await Sim.type(tree, "abc")
	assert_eq(rig.text(), "abc")


func test_f04_typing_reaches_the_editor_after_a_file_opens_at_startup() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new(null, false)
	vm = rig.vm
	rig.documents.files["/notes/start.txt"] = TextCodec.encode_text("from file", FileEncoding.ANSI)
	screen = NotepadScreen.new(vm)
	tree.root.add_child(screen)
	vm.start("/notes/start.txt")
	await wait_frames(4)

	assert_eq(vm.file_name(), "start.txt")
	assert_eq(rig.text(), "from file")
	assert_eq(tree.root.gui_get_focus_owner(), vm.text, "the editor has focus")
	await Sim.type(tree, "typed after load")
	assert_true(rig.text().contains("typed after load"))
	assert_eq(rig.text().length(), "from file".length() + "typed after load".length())


# ---- F-05: text typed while a file loads is not replaced silently ----

func _start_loading() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new(null, false)
	vm = rig.vm
	rig.documents.files["/data/big.txt"] = TextCodec.encode_text("from file", FileEncoding.ANSI)
	rig.documents.hold_reads = true
	screen = NotepadScreen.new(vm)
	tree.root.add_child(screen)
	vm.start("/data/big.txt")
	await wait_frames(3)


func test_f05_edits_made_during_the_load_are_kept_and_the_save_prompt_decides() -> void:
	await _start_loading()
	await Sim.type(tree, "typed")
	assert_eq(rig.text(), "typed")

	rig.documents.release_reads()
	await wait_frames(3)

	assert_true(vm.modal() is Requests.MessageRequest, "the save prompt is shown")
	await _press("Cancel")
	assert_eq(rig.text(), "typed")
	assert_eq(vm.file_name(), "Untitled")


func test_f05_a_file_that_loads_without_edits_replaces_the_empty_document() -> void:
	await _start_loading()

	rig.documents.release_reads()
	await wait_frames(3)

	assert_null(vm.modal())
	assert_eq(rig.text(), "from file")
	assert_eq(vm.file_name(), "big.txt")


func test_f05_file_new_during_the_load_cancels_the_load() -> void:
	await _start_loading()

	var creating := await _open(vm.new_document)
	await creating.wait()
	rig.documents.release_reads()
	await wait_frames(3)

	assert_eq(rig.text(), "")
	assert_eq(vm.file_name(), "Untitled")
	assert_null(vm.modal())
