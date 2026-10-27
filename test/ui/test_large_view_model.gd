extends TestCase
## The view model with a document big enough to be shown through a window.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var vm: NotepadViewModel
var big_text: String


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	vm = rig.vm
	var lines := PackedStringArray()
	for index in range(6000):
		lines.append("row %d: the quick brown fox jumps over the lazy dog" % index)
	big_text = "\n".join(lines)


func after_each() -> void:
	rig.dispose()


func _open_big() -> void:
	rig.documents.files["/home/tester/big.txt"] = TextCodec.encode_text(big_text, FileEncoding.UTF8)
	var opening := Pending.start(vm.open_document)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/big.txt", FileEncoding.ANSI))
	await opening.wait()


func test_a_big_file_opens_through_a_window_and_is_not_modified() -> void:
	await _open_big()
	assert_true(vm.text.is_windowed())
	assert_false(vm.is_modified())
	assert_eq(vm.file_name(), "big.txt")
	assert_eq(vm.text.document_text(), big_text)
	assert_eq(vm.status_text(), "Ln 1, Col 1")


func test_typing_in_a_big_file_marks_it_modified_and_save_writes_all_of_it() -> void:
	await _open_big()
	vm.text.go_to_document_line(3000)
	vm.text.insert_text_at_caret("EDIT ")
	assert_true(vm.is_modified())
	assert_eq(vm.status_text(), "Ln 3000, Col 6")
	assert_true(await vm.save())
	var lines := big_text.split("\n")
	lines[2999] = "EDIT " + lines[2999]
	assert_eq(rig.documents.writes[0]["text"], "\n".join(lines))
	assert_false(vm.is_modified())


func test_find_next_walks_through_matches_beyond_the_window() -> void:
	await _open_big()
	var options := SearchOptions.new("row 4500:")
	assert_true(vm.find_next(options))
	assert_eq(vm.text.selected_document_text(), "row 4500:")
	assert_eq(vm.status_text(), "Ln 4501, Col 10")
	# Going backwards from there finds the match before it, near the start.
	assert_true(vm.find_next(SearchOptions.new("row 1", false, false, false)))
	assert_true(vm.text.selected_document_text().begins_with("row 1"))


func test_replace_all_works_on_the_whole_document_and_can_be_undone() -> void:
	await _open_big()
	assert_true(vm.replace_all_matches(SearchOptions.new("lazy"), "sleepy"))
	assert_eq(vm.text.document_text(), big_text.replace("lazy", "sleepy"))
	assert_true(vm.can_undo())
	vm.undo()
	assert_eq(vm.text.document_text(), big_text)


func test_go_to_a_line_far_from_the_window() -> void:
	await _open_big()
	vm.go_to_line(5500)
	assert_eq(vm.status_text(), "Ln 5500, Col 1")
	vm.go_to_line(99999)
	assert_eq(vm.status_text(), "Ln 6000, Col 1")


func test_select_all_cut_and_paste_move_the_whole_document() -> void:
	await _open_big()
	vm.select_all()
	vm.copy()
	assert_eq(Clipboard.get_text(), big_text)
	vm.cut()
	assert_eq(vm.text.document_text(), "")
	vm.paste()
	assert_eq(vm.text.document_text(), big_text)


func test_a_big_paste_into_a_small_document_leaves_it_modified_and_windowed() -> void:
	Clipboard.set_text(big_text)
	vm.paste()
	assert_true(vm.text.is_windowed())
	assert_true(vm.is_modified())
	assert_eq(vm.text.document_text(), big_text)


func test_new_document_leaves_the_window() -> void:
	await _open_big()
	var creating := Pending.start(vm.new_document)
	await creating.wait()
	assert_false(vm.text.is_windowed())
	assert_eq(vm.text.document_text(), "")
