extends TestCase
## A message that is ready while another dialog is open waits its turn. It used to be dropped
## and counted as the answer No, so a file the user asked for silently did not open, or an
## error went unreported. (Ported from the Flutter version's modal_queue_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

## A document this size is a large one for these tests, in place of 16 million characters.
const LARGE_LIMIT := 1000

var rig: ViewModelRig
var vm: NotepadViewModel


func before_each() -> void:
	Clipboard.set_text("")
	# Not started: each test starts it with the file it opens. Reads wait for the test, to
	# model a slow disk.
	rig = ViewModelRig.new(null, false)
	rig.documents.hold_reads = true
	vm = rig.vm
	vm.large_document_characters = LARGE_LIMIT


func after_each() -> void:
	rig.dispose()


func _big() -> String:
	return "a".repeat(LARGE_LIMIT + 1)


## Starts opening [param file_path] with the read held back, then opens About on top.
func _about_during_read(file_path: String) -> Requests.AboutRequest:
	vm.start(file_path)
	Pending.start(vm.show_about)
	return modal_of(vm, Requests.AboutRequest)


func test_an_error_found_while_about_is_open_is_shown_when_about_closes() -> void:
	# The file is not there, so the read ends in an error to report.
	var about := _about_during_read("/missing.txt")
	if about == null:
		return
	rig.documents.release_reads()
	assert_true(vm.modal() == about, "About is still the one on screen")

	about.complete(null)
	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_contains(message.text, "missing.txt")
	message.complete(Requests.MessageChoice.OK)
	assert_null(vm.modal())


func test_the_question_about_a_large_file_waits_and_yes_opens_the_file() -> void:
	rig.documents.files["/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	var about := _about_during_read("/big.txt")
	if about == null:
		return
	rig.documents.release_reads()
	assert_true(vm.modal() == about)

	about.complete(null)
	var question: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if question == null:
		return
	assert_contains(question.text, "\"big.txt\" is large")
	question.complete(Requests.MessageChoice.YES)
	assert_eq(rig.text().length(), _big().length())
	assert_eq(vm.file_name(), "big.txt")
	assert_null(vm.modal())


func test_the_question_about_a_large_file_waits_and_no_leaves_things_as_they_are() -> void:
	rig.documents.files["/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	var about := _about_during_read("/big.txt")
	if about == null:
		return
	rig.documents.release_reads()
	about.complete(null)
	var question: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if question == null:
		return
	question.complete(Requests.MessageChoice.NO)
	assert_eq(rig.text().length(), 0)
	assert_eq(vm.file_name(), "Untitled")


func test_a_question_that_is_no_longer_wanted_is_not_asked() -> void:
	rig.documents.files["/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	var about := _about_during_read("/big.txt")
	if about == null:
		return
	rig.documents.release_reads()
	# While About is open the user starts a new document, which replaces the request.
	await vm.new_document()
	about.complete(null)
	assert_null(vm.modal(), "the question belongs to an open that was replaced")
	assert_eq(rig.text(), "")


func test_a_yes_to_a_question_about_an_open_that_was_replaced_does_nothing() -> void:
	rig.documents.files["/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	vm.start("/big.txt")
	rig.documents.release_reads()
	var question: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if question == null:
		return
	# Something else replaces the document while the question is on screen.
	await vm.new_document()
	question.complete(Requests.MessageChoice.YES)
	assert_eq(rig.text().length(), 0)
	assert_eq(vm.file_name(), "Untitled")


func test_dialogs_shown_one_after_another_each_get_their_turn() -> void:
	var first := Pending.start(vm.show_about)
	var about: Requests.AboutRequest = modal_of(vm, Requests.AboutRequest)
	if about == null:
		return
	var second := Pending.start(vm.show_help)
	var third := Pending.start(vm.show_about)
	assert_true(vm.modal() == about)

	about.complete(null)
	var help: Requests.HelpRequest = modal_of(vm, Requests.HelpRequest)
	if help == null:
		return
	help.complete(null)
	var last: Requests.AboutRequest = modal_of(vm, Requests.AboutRequest)
	if last == null:
		return
	assert_false(last == about, "the second About is a request of its own")
	last.complete(null)
	await first.wait()
	await second.wait()
	await third.wait()
	assert_null(vm.modal())


func test_a_dialog_asked_for_while_nothing_is_open_appears_at_once() -> void:
	var shown := Pending.start(vm.show_about)
	var about: Requests.AboutRequest = modal_of(vm, Requests.AboutRequest)
	if about == null:
		return
	about.complete(null)
	await shown.wait()
