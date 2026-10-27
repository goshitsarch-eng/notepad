extends TestCase
## Regressions found in the second audit, at the level of the view model: the unsaved-changes
## prompt of File > Open, the wording of error messages, large files and the file dialogs'
## start folder. (Ported from the Flutter version's audit_view_model_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

const SAVE_PROMPT := "Do you want to save the changes?"

var rig: ViewModelRig
var vm: NotepadViewModel
## How many times the save prompt was answered by [method _answer_save_prompts].
var prompts := 0


func before_each() -> void:
	Clipboard.set_text("")
	prompts = 0
	rig = ViewModelRig.new()
	vm = rig.vm


func after_each() -> void:
	rig.dispose()


## Answers every save prompt that is open with [param choice], up to the file dialog or the
## end of the command.
func _answer_save_prompts(choice: int) -> void:
	for _i in range(8):
		var request: Variant = vm.modal()
		if request is Requests.MessageRequest and (request as Requests.MessageRequest).text.contains(SAVE_PROMPT):
			prompts += 1
			(request as Requests.MessageRequest).complete(choice)
		else:
			return


## Starts File > Open on a document with unsaved text and answers its save prompt with No,
## leaving the file dialog open.
func _open_after_discarding(path_to_open: String) -> Pending:
	rig.documents.files[path_to_open] = TextCodec.encode_text("from disk", FileEncoding.ANSI)
	rig.type_text("unsaved")
	var opening := Pending.start(vm.open_document)
	_answer_save_prompts(Requests.MessageChoice.NO)
	return opening


# ---- File > Open asks about unsaved changes once ----

func test_answering_no_then_choosing_a_file_opens_it_without_a_second_prompt() -> void:
	var opening := _open_after_discarding("/home/tester/a.txt")
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	_answer_save_prompts(Requests.MessageChoice.NO)
	await opening.wait()

	assert_eq(prompts, 1)
	assert_eq(rig.text(), "from disk")
	assert_eq(vm.file_name(), "a.txt")
	assert_false(vm.is_modified())


func test_answering_yes_saves_then_opens_the_file_with_no_second_prompt() -> void:
	rig.documents.files["/home/tester/a.txt"] = TextCodec.encode_text("from disk", FileEncoding.ANSI)
	rig.type_text("unsaved")
	var opening := Pending.start(vm.open_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	# Yes: the document has no name yet, so Save As is shown.
	prompt.complete(Requests.MessageChoice.YES)
	var save_dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if save_dialog == null:
		return
	assert_eq(save_dialog.mode, Requests.FileDialogMode.SAVE)
	save_dialog.complete(Requests.FileChoice.new("/home/tester/mine.txt", FileEncoding.ANSI))
	var open_dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if open_dialog == null:
		return
	assert_eq(open_dialog.mode, Requests.FileDialogMode.OPEN)
	open_dialog.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	await opening.wait()

	assert_eq(rig.documents.writes.size(), 1)
	assert_eq(rig.documents.writes[0]["text"], "unsaved")
	assert_null(vm.modal())
	assert_eq(rig.text(), "from disk")


func test_cancel_on_the_prompt_opens_nothing() -> void:
	rig.type_text("unsaved")
	var opening := Pending.start(vm.open_document)
	_answer_save_prompts(Requests.MessageChoice.CANCEL)
	await opening.wait()

	assert_null(vm.modal())
	assert_eq(rig.text(), "unsaved")


func test_text_typed_while_the_file_is_read_still_gets_its_own_prompt() -> void:
	var opening := _open_after_discarding("/home/tester/a.txt")
	var request: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if request == null:
		return
	# The choice is delivered, but the read has not finished: the user keeps typing.
	rig.documents.hold_reads = true
	request.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	rig.type_text("unsaved, and more")
	rig.documents.release_reads()
	_answer_save_prompts(Requests.MessageChoice.CANCEL)
	await opening.wait()

	assert_eq(prompts, 2, "the extra typing is new text the user has not agreed to lose")
	assert_eq(rig.text(), "unsaved, and more")


func test_text_typed_while_the_save_before_an_open_is_still_running_gets_its_own_prompt() -> void:
	rig.documents.files["/home/tester/b.txt"] = TextCodec.encode_text("other", FileEncoding.ANSI)

	# A document that has a name and unsaved changes.
	rig.type_text("first")
	var naming := Pending.start(vm.save_as)
	var naming_dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if naming_dialog == null:
		return
	naming_dialog.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	await naming.wait()
	rig.type_text("second")

	# Open, answer Yes, and keep typing while the write is in flight.
	rig.documents.hold_writes = true
	var opening := Pending.start(vm.open_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	prompt.complete(Requests.MessageChoice.YES)
	rig.type_text("second, and more typed during the save")
	rig.documents.release_writes()
	var open_dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if open_dialog == null:
		return
	open_dialog.complete(Requests.FileChoice.new("/home/tester/b.txt", FileEncoding.ANSI))

	# The typing is in no file, so replacing it needs a prompt of its own.
	var again: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if again == null:
		return
	assert_contains(again.text, SAVE_PROMPT)
	again.complete(Requests.MessageChoice.CANCEL)
	await opening.wait()
	assert_eq(rig.text(), "second, and more typed during the save")


# ---- Error messages give the reason (F-12) ----

func _open_choosing(path_to_open: String) -> Pending:
	var opening := Pending.start(vm.open_document)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog != null:
		dialog.complete(Requests.FileChoice.new(path_to_open, FileEncoding.ANSI))
	return opening


func test_an_unreadable_file_says_why() -> void:
	rig.documents.read_failures["/home/tester/secret.txt"] = FileError.make(
		"Cannot open file", "/home/tester/secret.txt", FileError.Kind.OTHER, "Permission denied")
	var opening := _open_choosing("/home/tester/secret.txt")

	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_eq(message.text, "Cannot open \"secret.txt\".\n\nPermission denied")
	message.complete(Requests.MessageChoice.OK)
	await opening.wait()


func test_a_file_that_is_too_large_says_so() -> void:
	rig.documents.read_failures["/home/tester/huge.txt"] = FileError.make(
		"The file is too large. Notepad opens files up to 64 MB", "/home/tester/huge.txt")
	var opening := _open_choosing("/home/tester/huge.txt")

	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_contains(message.text, "too large")
	assert_contains(message.text, "64 MB")
	message.complete(Requests.MessageChoice.OK)
	await opening.wait()


func test_a_missing_file_keeps_the_xp_wording() -> void:
	rig.documents.read_failures["/home/tester/gone.txt"] = FileError.make(
		"No such file or directory", "/home/tester/gone.txt", FileError.Kind.NOT_FOUND,
		"No such file or directory")
	var opening := _open_choosing("/home/tester/gone.txt")

	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_eq(message.text, "Cannot find \"gone.txt\". Make sure the path and file name are correct.")
	message.complete(Requests.MessageChoice.OK)
	await opening.wait()


func test_a_save_that_fails_names_the_folder_and_the_reason() -> void:
	rig.documents.write_failure = FileError.make(
		"Cannot open file", "/readonly/a.txt", FileError.Kind.OTHER, "Read-only file system")
	rig.type_text("text")
	var saving := Pending.start(vm.save_as)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/readonly/a.txt", FileEncoding.ANSI))

	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_eq(message.text, "Cannot save \"a.txt\" in \"/readonly\".\n\nRead-only file system")
	message.complete(Requests.MessageChoice.OK)
	assert_false(await saving.wait())
	assert_true(vm.is_modified(), "a failed save leaves the document unsaved")


func test_an_error_with_no_usable_reason_still_gives_a_message() -> void:
	# Anything that is not a FileError carries no reason a person could use.
	rig.documents.write_failure = "no reason a person could use"
	rig.type_text("text")
	var saving := Pending.start(vm.save_as)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))

	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_eq(message.text, "Cannot save \"a.txt\" in \"/home/tester\".")
	message.complete(Requests.MessageChoice.OK)
	await saving.wait()


# ---- A large file is opened only when the user agrees ----
# A document this size takes seconds to open and a lot of memory, so the user is told first.
# The threshold is lowered instead of building a 16-million-character string.

const LARGE_LIMIT := 1000


func _big() -> String:
	return "a".repeat(LARGE_LIMIT + 1)


## Opens big.txt (one character over the limit) and returns the command, with the warning open.
func _open_big() -> Pending:
	vm.large_document_characters = LARGE_LIMIT
	rig.documents.files["/home/tester/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	return _open_choosing("/home/tester/big.txt")


func test_the_large_file_warning_says_what_is_wrong_and_offers_yes_and_no() -> void:
	var opening := _open_big()
	var warning: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if warning == null:
		return

	assert_contains(warning.text, "\"big.txt\" is large")
	assert_contains(warning.text, "takes a while")
	assert_eq(warning.choices, [Requests.MessageChoice.YES, Requests.MessageChoice.NO])
	assert_eq(warning.icon, Requests.MessageIcon.WARNING)
	warning.complete(Requests.MessageChoice.NO)
	await opening.wait()


func test_yes_opens_the_large_file() -> void:
	var opening := _open_big()
	var warning: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if warning == null:
		return
	warning.complete(Requests.MessageChoice.YES)
	await opening.wait()

	assert_null(vm.modal())
	assert_eq(rig.text().length(), _big().length())
	assert_eq(vm.file_name(), "big.txt")


func test_no_leaves_the_current_document_alone() -> void:
	vm.large_document_characters = LARGE_LIMIT
	rig.type_text("my notes")
	var opening := Pending.start(vm.open_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	prompt.complete(Requests.MessageChoice.NO) # discard my notes
	rig.documents.files["/home/tester/big.txt"] = TextCodec.encode_text(_big(), FileEncoding.ANSI)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/big.txt", FileEncoding.ANSI))
	var warning: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if warning == null:
		return
	warning.complete(Requests.MessageChoice.NO)
	await opening.wait()

	assert_eq(rig.text(), "my notes", "declining the big file keeps what was there")
	assert_eq(vm.file_name(), "Untitled")
	assert_true(vm.is_modified())


func test_a_file_just_under_the_limit_opens_with_no_warning() -> void:
	vm.large_document_characters = LARGE_LIMIT
	rig.documents.files["/home/tester/fine.txt"] = TextCodec.encode_text(
		"a".repeat(LARGE_LIMIT), FileEncoding.ANSI)
	var opening := _open_choosing("/home/tester/fine.txt")
	await opening.wait()

	assert_null(vm.modal())
	assert_eq(vm.file_name(), "fine.txt")


func test_the_default_large_file_limit_is_16_million_characters() -> void:
	# The other tests lower the limit; this keeps the real one from drifting.
	assert_eq(NotepadViewModel.DEFAULT_LARGE_DOCUMENT_CHARACTERS, 16 * 1024 * 1024)
	assert_eq(vm.large_document_characters, 16 * 1024 * 1024)


# ---- The file dialogs start where the user was ----

func test_save_as_starts_in_the_last_folder_used() -> void:
	var saving := Pending.start(vm.save_as)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	assert_eq(dialog.start_directory, "/home/tester")
	dialog.complete(null)
	assert_false(await saving.wait())
