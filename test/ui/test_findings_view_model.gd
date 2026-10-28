extends TestCase
## The view-model parts of the findings regression tests: a file that loads while the user
## types (F-05) and the editor that must take text after the document is replaced (F-04).
## The dialog and focus parts (F-01 to F-03, and the focus half of F-04) need the widgets and
## are tested with the screen. (Ported from the Flutter version's findings_regression_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var vm: NotepadViewModel


func before_each() -> void:
	Clipboard.set_text("")
	rig = null
	vm = null


func after_each() -> void:
	if rig != null:
		rig.dispose()


## Starts the view model opening [param file_path] at start-up, with the read held back as a
## big file that is still loading.
func _start_loading(file_path: String) -> void:
	rig = ViewModelRig.new(null, false)
	rig.documents.hold_reads = true
	rig.documents.files[file_path] = TextCodec.encode_text("from file", FileEncoding.ANSI)
	vm = rig.vm
	vm.start(file_path)


# ---- F-04: the editor accepts text after the document is replaced ----

func test_text_can_be_entered_after_file_new() -> void:
	rig = ViewModelRig.new()
	vm = rig.vm
	rig.type_text("old")
	var creating := Pending.start(vm.new_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	prompt.complete(Requests.MessageChoice.NO)
	await creating.wait()

	rig.type_text("abc")
	assert_eq(rig.text(), "abc")


func test_text_can_be_entered_after_a_file_opens_at_startup() -> void:
	rig = ViewModelRig.new(null, false)
	rig.documents.files["/notes/start.txt"] = TextCodec.encode_text("from file", FileEncoding.ANSI)
	vm = rig.vm
	vm.start("/notes/start.txt")

	assert_eq(vm.file_name(), "start.txt")
	assert_eq(rig.text(), "from file")
	rig.type_text("typed after load")
	assert_eq(rig.text(), "typed after load")


# ---- F-05: text typed while a file loads is not replaced silently ----

func test_edits_made_during_the_load_are_kept_and_the_save_prompt_decides() -> void:
	_start_loading("/data/big.txt")
	rig.type_text("typed")

	rig.documents.release_reads()

	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	prompt.complete(Requests.MessageChoice.CANCEL)
	assert_eq(rig.text(), "typed")
	assert_eq(vm.file_name(), "Untitled")


func test_a_file_that_loads_without_edits_replaces_the_empty_document() -> void:
	_start_loading("/data/big.txt")

	rig.documents.release_reads()

	assert_null(vm.modal())
	assert_eq(rig.text(), "from file")
	assert_eq(vm.file_name(), "big.txt")


func test_file_new_during_the_load_cancels_the_load() -> void:
	_start_loading("/data/big.txt")

	await vm.new_document()
	rig.documents.release_reads()

	assert_eq(rig.text(), "")
	assert_eq(vm.file_name(), "Untitled")
	assert_null(vm.modal())
