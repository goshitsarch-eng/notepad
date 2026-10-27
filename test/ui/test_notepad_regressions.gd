extends TestCase
## Regressions of the Notepad window at the level of the view model: the saved window size,
## one dialog at a time, the window title and typing during a save. (Ported from the Flutter
## version's notepad_regressions_test.)

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


## Builds the view model. [param initial_path] is opened at start-up when given; the
## [param files] are put in the fake document store first.
func _start(initial_path: String = "", files: Dictionary = {}) -> void:
	rig = ViewModelRig.new(null, false)
	for path in files:
		rig.documents.files[path] = TextCodec.encode_text(files[path], FileEncoding.ANSI)
	vm = rig.vm
	vm.start(initial_path)


# ---- Window size ----

func test_exit_while_maximized_keeps_the_last_normal_size() -> void:
	_start()
	rig.window.size = Vector2(700, 500)
	rig.window.resized.emit()
	await wait_seconds(0.3)

	rig.window.maximized = true
	rig.window.size = Vector2(1728, 992)
	await vm.request_exit()

	assert_not_null(rig.settings.saved)
	assert_eq(rig.settings.saved.window_width, 700.0)
	assert_eq(rig.settings.saved.window_height, 500.0)


func test_a_window_dragged_below_the_minimum_is_brought_back_to_it() -> void:
	_start()
	rig.window.size = Vector2(300, 200)
	rig.window.resized.emit()
	await wait_seconds(0.3)

	assert_eq(rig.window.size.x, NotepadSettings.MINIMUM_WINDOW_WIDTH)
	assert_eq(rig.window.size.y, NotepadSettings.MINIMUM_WINDOW_HEIGHT)


func test_a_resize_that_is_still_going_does_not_act_until_it_settles() -> void:
	_start()
	# The settle delay is real time, so a hitch in the test run can make one of the short
	# waits last past it. An attempt that was too slow to prove anything is tried again.
	var proved := false
	for _attempt in range(5):
		rig.window.size = Vector2(300, 200)
		# A timer counts the frame it was made in from the frame before it, so work done
		# since the last frame (building the view model) would make it fire early. Two idle
		# frames let that pass first.
		await wait_frames(2)
		var started := Time.get_ticks_msec()
		rig.window.resized.emit()
		await wait_seconds(0.05)
		var second := Time.get_ticks_msec()
		rig.window.resized.emit()
		await wait_seconds(0.05)
		var checked := Time.get_ticks_msec()
		var in_time := second - started < 120 and checked - second < 120
		if in_time:
			# Still inside the settle window, so the size has not been corrected yet.
			assert_eq(rig.window.size.x, 300.0)
			await wait_seconds(0.25)
			assert_eq(rig.window.size.x, NotepadSettings.MINIMUM_WINDOW_WIDTH)
			proved = true
			break
		await wait_seconds(0.3)
	assert_true(proved, "the run was too slow to time the settle window")


# ---- One dialog at a time ----

func test_a_second_dialog_does_not_replace_the_one_already_open() -> void:
	_start()
	var about_shown := Pending.start(vm.show_about)
	var open: Variant = vm.modal()
	var help_shown := Pending.start(vm.show_help)
	assert_true(vm.modal() == open, "the open dialog stays")
	assert_true(vm.modal() is Requests.AboutRequest)

	# Closing About hands the screen to the Help that was waiting.
	vm.modal().complete(null)
	assert_true(vm.modal() is Requests.HelpRequest)
	vm.modal().complete(null)
	await about_shown.wait()
	await help_shown.wait()
	assert_null(vm.modal())


func test_a_close_request_is_ignored_while_a_dialog_is_open() -> void:
	_start()
	var about_shown := Pending.start(vm.show_about)
	rig.window.close_requested.emit()
	assert_true(vm.modal() is Requests.AboutRequest)
	assert_false(rig.window.closed)
	vm.modal().complete(null)
	await about_shown.wait()


func test_a_missing_file_says_it_cannot_be_found() -> void:
	# The store says the file is not there, as the file system does for a path that is gone.
	rig = ViewModelRig.new(null, false)
	rig.documents.read_failures["/home/tester/notes/gone.txt"] = FileError.make(
		"No such file or directory", "/home/tester/notes/gone.txt", FileError.Kind.NOT_FOUND,
		"No such file or directory")
	vm = rig.vm
	vm.start("/home/tester/notes/gone.txt")

	var request: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if request == null:
		return
	assert_eq(request.text, "Cannot find \"gone.txt\". Make sure the path and file name are correct.")
	request.complete(Requests.MessageChoice.OK)


# ---- Window title ----

func test_opening_a_file_puts_its_name_in_the_window_title() -> void:
	_start("/home/tester/notes.txt", {"/home/tester/notes.txt": "x"})
	assert_eq(rig.window.title, "notes.txt - Notepad")


func test_new_puts_untitled_back_in_the_window_title() -> void:
	_start("/home/tester/notes.txt", {"/home/tester/notes.txt": "x"})
	await vm.new_document()
	assert_eq(rig.window.title, "Untitled - Notepad")


# ---- Saving ----

func test_typing_during_a_save_leaves_the_document_modified() -> void:
	_start("/home/tester/a.txt", {"/home/tester/a.txt": "one"})

	rig.documents.hold_writes = true
	rig.type_text("one two")
	var saving := Pending.start(vm.save)
	rig.type_text("one two three")
	rig.documents.release_writes()
	assert_true(await saving.wait())

	# The file holds "one two", so the later edit must still count as unsaved.
	assert_eq(rig.documents.writes[0]["text"], "one two")
	assert_true(vm.is_modified())


func test_a_save_with_no_edits_in_between_is_clean_afterwards() -> void:
	_start("/home/tester/b.txt", {"/home/tester/b.txt": "one"})

	rig.type_text("changed")
	assert_true(vm.is_modified())
	assert_true(await vm.save())
	assert_false(vm.is_modified())
