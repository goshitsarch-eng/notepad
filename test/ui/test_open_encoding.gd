extends TestCase
## The Open dialog's Encoding list, which XP has, and what the view model does with the choice.
## (Ported from the Flutter version's open_encoding_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var vm: NotepadViewModel
var screen: NotepadScreen


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	vm = rig.vm
	screen = NotepadScreen.new(vm)
	tree.root.add_child(screen)
	await wait_frames(3)


func after_each() -> void:
	if vm.modal() != null:
		vm.modal().complete(null)
	await wait_frames(2)
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()


# ---- Helpers ----

## UTF-16 little endian with no byte order mark: nothing in it says what it is.
static func _utf16_little_endian_without_mark(content: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	for index in range(content.length()):
		var unit := content.unicode_at(index)
		bytes.append(unit & 0xFF)
		bytes.append((unit >> 8) & 0xFF)
	return bytes


func _open(command: Callable) -> Pending:
	var pending := Pending.start(command)
	await wait_frames(2)
	return pending


func _dialog() -> OpenSaveDialog:
	return screen.modal_host.dialog as OpenSaveDialog


## The file the dialog named does not exist in the fake, so the open ends in a message. It is
## closed so that the open can finish.
func _finish(opening: Pending) -> void:
	await wait_frames(3)
	if vm.modal() is Requests.MessageRequest:
		vm.modal().complete(Requests.MessageChoice.OK)
	await opening.wait()


func _replace_text(box: LineEdit, value: String) -> void:
	box.grab_focus()
	await Sim.key(tree, KEY_A, {"ctrl": true})
	await Sim.type(tree, value)


func _enter() -> void:
	await Sim.key(tree, KEY_ENTER)
	await wait_frames(2)


## Opens [param combo] with a click and clicks the row labelled [param label] in its list.
func _choose(combo: XpComboBox, label: String) -> void:
	await Sim.click(tree, Sim.center_of(combo))
	await wait_frames(2)
	var popup := tree.get_first_node_in_group("xp_open_list") as Control
	if not assert_not_null(popup, "the %s list did not open" % combo.accessible_name):
		return
	var row := combo.labels.find(label)
	if not assert_true(row >= 0, "no row labelled %s" % label):
		return
	var list: Rect2 = popup.call("_list_rect")
	await Sim.click(tree, Vector2(list.position.x + 20, list.position.y + 1 + 16 * row + 8))
	await wait_frames(2)


func _labels_in(node: Node, text: String, found: Array[Label]) -> void:
	if node is Label and (node as Label).text == text:
		found.append(node)
	for child in node.get_children():
		_labels_in(child, text, found)


# ---- The Open dialog ----

func test_the_open_dialog_has_an_encoding_list_that_starts_on_detecting_by_itself() -> void:
	var opening := await _open(vm.open_document)
	var dialog := _dialog()
	if not assert_not_null(dialog):
		return

	assert_not_null(dialog.encoding_combo)
	assert_eq(dialog.encoding_combo.accessible_name, "Encoding")
	var captions: Array[Label] = []
	_labels_in(dialog, "Encoding:", captions)
	assert_eq(captions.size(), 1, "one Encoding: caption")
	assert_eq(dialog.encoding_combo.labels[dialog.encoding_combo.selected], "Detect automatically")
	assert_contains(dialog.encoding_combo.labels, "Detect automatically")

	vm.modal().complete(null)
	await opening.wait()


func test_open_answers_with_no_encoding_when_none_was_chosen() -> void:
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return

	await _replace_text(_dialog().name_box, "notes.txt")
	await _enter()

	assert_true(request.is_done)
	var chosen: Requests.FileChoice = request.answer
	if assert_not_null(chosen):
		assert_eq(chosen.path, "/home/tester/notes.txt")
		assert_eq(chosen.open_as, FileEncoding.DETECT)
	await _finish(opening)


func test_open_answers_with_the_encoding_the_user_chose() -> void:
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog()

	await _choose(dialog.encoding_combo, "Unicode")
	await _replace_text(dialog.name_box, "notes.txt")
	await _enter()

	assert_true(request.is_done)
	var chosen: Requests.FileChoice = request.answer
	if assert_not_null(chosen):
		assert_eq(chosen.open_as, FileEncoding.UNICODE)
	await _finish(opening)


func test_open_keeps_the_choice_when_a_file_is_opened_by_double_clicking_it() -> void:
	rig.file_system.listings["/home/tester"] = [
		DirectoryEntry.new("report.txt", "/home/tester/report.txt", false, 12, 0)]
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	var dialog := _dialog()

	await _choose(dialog.encoding_combo, "UTF-8")
	# Rows start below the 18 px header and its 1 px border, and are 16 px tall.
	var row := dialog.list.get_global_rect().position + Vector2(40, 19 + 8)
	await Sim.click(tree, row)
	await Sim.click(tree, row, MOUSE_BUTTON_LEFT, true)
	await wait_frames(2)

	assert_true(request.is_done)
	var chosen: Requests.FileChoice = request.answer
	if assert_not_null(chosen):
		assert_eq(chosen.path, "/home/tester/report.txt")
		assert_eq(chosen.open_as, FileEncoding.UTF8)
	await _finish(opening)


func test_save_as_keeps_its_own_list_which_has_no_automatic_choice() -> void:
	var saving := await _open(vm.save_as)
	var dialog := _dialog()
	if not assert_not_null(dialog):
		return

	assert_not_null(dialog.encoding_combo)
	assert_eq(dialog.encoding_combo.labels.size(), FileEncoding.ALL.size())
	assert_not_contains(dialog.encoding_combo.labels, "Detect automatically")

	vm.modal().complete(null)
	await saving.wait()


# ---- Opening as a chosen encoding ----

func test_opening_as_a_chosen_encoding_reads_the_file_as_that_encoding_and_keeps_it_for_saving() -> void:
	# Japanese UTF-16 with no mark: nothing in it says what it is.
	var content := "日本語のテキストです。\n"
	rig.documents.files["/home/tester/jp.txt"] = _utf16_little_endian_without_mark(content)
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	request.complete(Requests.FileChoice.new("/home/tester/jp.txt", FileEncoding.ANSI, FileEncoding.UNICODE))
	await opening.wait()
	await wait_frames(3)

	assert_eq(rig.text(), content)
	assert_eq(rig.documents.read_encodings.back(), FileEncoding.UNICODE)
	# Saving writes it back in the encoding it was opened as.
	await vm.save()
	assert_eq(rig.documents.writes.back()["encoding"], FileEncoding.UNICODE)


func test_opening_detects_by_itself_when_no_encoding_is_chosen() -> void:
	rig.documents.files["/home/tester/a.txt"] = TextCodec.encode_text("café", FileEncoding.UTF8)
	var opening := await _open(vm.open_document)
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	request.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	await opening.wait()
	await wait_frames(3)

	assert_eq(rig.text(), "café")
	assert_eq(rig.documents.read_encodings.back(), FileEncoding.DETECT)
