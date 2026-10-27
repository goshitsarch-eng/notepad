extends TestCase
## The view model, on fakes: the document's life, editing, Find and Replace, the view options and
## the menus. (Ported from the Flutter version's notepad_view_model_test.)

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

var rig: ViewModelRig
var vm: NotepadViewModel


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	vm = rig.vm


func after_each() -> void:
	rig.dispose()


# ---- Document lifecycle ----

func test_starts_untitled_and_unmodified_with_the_xp_title() -> void:
	assert_eq(vm.file_name(), "Untitled")
	assert_false(vm.is_modified())
	assert_eq(vm.window_title(), "Untitled - Notepad")
	assert_true(rig.window.prevent_close)
	assert_eq(rig.window.title, "Untitled - Notepad")


func test_typing_marks_the_document_modified_saving_clears_it_and_renames_it() -> void:
	rig.type_text("hello")
	assert_true(vm.is_modified())

	var saving := Pending.start(vm.save)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	assert_eq(dialog.mode, Requests.FileDialogMode.SAVE)
	dialog.complete(Requests.FileChoice.new("/home/tester/notes.txt", FileEncoding.UTF8))
	assert_true(await saving.wait())

	assert_false(vm.is_modified())
	assert_eq(vm.file_name(), "notes.txt")
	assert_eq(vm.window_title(), "notes.txt - Notepad")
	assert_eq(rig.documents.writes[0]["text"], "hello")
	assert_eq(rig.documents.writes[0]["encoding"], FileEncoding.UTF8)
	assert_eq(rig.window.title, "notes.txt - Notepad")


func test_opening_a_file_loads_its_text_and_remembers_its_encoding() -> void:
	rig.documents.files["/home/tester/a.txt"] = TextCodec.encode_text("first\nsecond", FileEncoding.UNICODE)
	var opening := Pending.start(vm.open_document)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/a.txt", FileEncoding.ANSI))
	await opening.wait()

	assert_eq(rig.text(), "first\nsecond")
	assert_eq(vm.file_name(), "a.txt")
	assert_false(vm.is_modified())
	assert_eq(vm.encoding(), FileEncoding.UNICODE)
	assert_eq(vm.font().family, "Lucida Console")


func test_new_asks_about_unsaved_changes_and_no_discards_them() -> void:
	rig.type_text("draft")
	var creating := Pending.start(vm.new_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	assert_eq(prompt.text, "The text in the Untitled file has changed.\n\nDo you want to save the changes?")
	prompt.complete(Requests.MessageChoice.NO)
	await creating.wait()

	assert_eq(rig.text(), "")
	assert_false(vm.is_modified())


func test_cancel_on_the_save_prompt_keeps_the_text_and_the_window() -> void:
	rig.type_text("draft")
	var creating := Pending.start(vm.new_document)
	var prompt: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if prompt == null:
		return
	prompt.complete(Requests.MessageChoice.CANCEL)
	await creating.wait()

	assert_eq(rig.text(), "draft")
	assert_true(vm.is_modified())


func test_closing_with_unsaved_changes_asks_first_and_can_be_cancelled() -> void:
	rig.type_text("draft")
	var closing := Pending.start(vm.request_exit)
	var first: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if first == null:
		return
	first.complete(Requests.MessageChoice.CANCEL)
	await closing.wait()
	assert_false(rig.window.closed)

	var leaving := Pending.start(vm.request_exit)
	var second: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if second == null:
		return
	second.complete(Requests.MessageChoice.NO)
	await leaving.wait()
	assert_true(rig.window.closed)


func test_printing_hands_the_text_and_file_name_to_the_printing_service() -> void:
	rig.type_text("print me")
	await vm.print_document()
	assert_eq(rig.printing.printed, ["Untitled"])
	assert_eq(rig.printing.printed_text, ["print me"])


# ---- Editing ----

func test_cut_copy_and_paste_go_through_the_clipboard() -> void:
	rig.type_text("hello world")
	rig.select(6, 11)
	vm.copy()
	assert_eq(Clipboard.get_text(), "world")

	vm.cut()
	assert_eq(rig.text(), "hello ")
	assert_eq(Clipboard.get_text(), "world")

	vm.text.deselect()
	vm.text.set_caret_line(0)
	vm.text.set_caret_column(6)
	vm.paste()
	assert_eq(rig.text(), "hello world")


func test_time_date_inserts_the_xp_form_at_the_caret() -> void:
	rig.type_text("at ")
	vm.text.set_caret_column(3)
	vm.insert_time_date()
	assert_eq(rig.text(), "at 3:05 PM 10/7/2026")


func test_select_all_selects_everything_and_delete_removes_the_selection() -> void:
	rig.type_text("abc")
	vm.select_all()
	assert_true(vm.has_selection())
	vm.delete_selection()
	assert_eq(rig.text(), "")


# ---- Find, replace and go to ----

func test_find_next_selects_each_match_then_reports_when_none_is_left() -> void:
	rig.type_text("one two one")
	vm.text.deselect()
	vm.text.set_caret_column(0)
	var options := SearchOptions.new("one")

	assert_true(vm.find_next(options))
	assert_eq(vm.text.get_selected_text(), "one")
	assert_eq(vm.text.get_selection_from_column(), 0)
	assert_eq(vm.text.get_selection_to_column(), 3)

	assert_true(vm.find_next(options))
	assert_eq(vm.text.get_selection_from_column(), 8)

	assert_false(vm.find_next(options))
	var message: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if message == null:
		return
	assert_eq(message.text, "Cannot find \"one\"")
	message.complete(Requests.MessageChoice.OK)


func test_replace_all_reports_the_count_and_rewrites_the_text() -> void:
	rig.type_text("a a a")
	assert_true(vm.replace_all_matches(SearchOptions.new("a"), "b"))
	assert_eq(rig.text(), "b b b")


func test_replace_swaps_a_selected_match_then_moves_to_the_next_one() -> void:
	rig.type_text("x x")
	rig.select(0, 1)
	assert_true(vm.replace_current(SearchOptions.new("x"), "y"))
	assert_eq(rig.text(), "y x")
	assert_eq(vm.text.get_selection_from_column(), 2)


func test_go_to_clamps_the_line_number_to_the_document() -> void:
	rig.type_text("a\nbc\nd")
	vm.go_to_line(99)
	assert_eq(vm.text.get_caret_line(), 2)
	assert_eq(vm.text.get_caret_column(), 0)
	vm.go_to_line(2)
	assert_eq(vm.text.get_caret_line(), 1)
	assert_eq(vm.text.get_caret_column(), 0)


# ---- View options ----

func test_word_wrap_is_on_by_default_and_hides_the_status_bar() -> void:
	assert_true(vm.word_wrap())
	assert_true(vm.status_bar_checked())
	assert_false(vm.status_bar_visible())


func test_status_bar_cannot_be_toggled_while_word_wrap_is_on() -> void:
	vm.toggle_status_bar()
	assert_true(vm.status_bar_checked())


func test_turning_word_wrap_off_shows_the_status_bar_again() -> void:
	vm.toggle_word_wrap()
	assert_false(vm.word_wrap())
	assert_true(vm.status_bar_visible())


func test_the_status_text_gives_the_caret_line_and_column() -> void:
	rig.type_text("ab\ncd")
	vm.text.set_caret_line(1)
	vm.text.set_caret_column(1)
	assert_eq(vm.status_text(), "Ln 2, Col 2")


# ---- Menus ----

func test_opening_a_menu_and_closing_it_updates_the_open_index() -> void:
	vm.open_menu_at(1, true)
	assert_eq(vm.open_menu(), 1)
	assert_true(vm.menu_opened_by_click())
	vm.close_menu()
	assert_eq(vm.open_menu(), NotepadViewModel.NO_MENU)


func test_losing_window_focus_closes_an_open_menu() -> void:
	vm.open_menu_at(0)
	vm.on_active_changed(false)
	assert_eq(vm.open_menu(), NotepadViewModel.NO_MENU)
	assert_false(vm.is_active())


func test_find_next_is_enabled_only_after_a_search_has_been_made() -> void:
	assert_eq(vm.last_search().query, "")
	rig.type_text("abc")
	vm.find_next(SearchOptions.new("b"))
	assert_eq(vm.last_search().query, "b")


func test_saving_non_ansi_text_as_ansi_warns_first_and_cancel_keeps_the_file_unsaved() -> void:
	rig.type_text("中文")
	var saving := Pending.start(vm.save)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/cjk.txt", FileEncoding.ANSI))
	var warning: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if warning == null:
		return
	assert_contains(warning.text, "characters which will be lost")
	warning.complete(Requests.MessageChoice.CANCEL)

	assert_false(await saving.wait())
	assert_eq(rig.documents.writes, [])
	assert_true(vm.is_modified())


func test_ok_on_the_ansi_warning_saves_anyway() -> void:
	rig.type_text("中文")
	var saving := Pending.start(vm.save)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/cjk.txt", FileEncoding.ANSI))
	var warning: Requests.MessageRequest = modal_of(vm, Requests.MessageRequest)
	if warning == null:
		return
	warning.complete(Requests.MessageChoice.OK)

	assert_true(await saving.wait())
	assert_eq(rig.documents.writes[0]["text"], "中文")


func test_saving_a_file_keeps_the_encoding_it_was_opened_with() -> void:
	rig.documents.files["/home/tester/wide.txt"] = TextCodec.encode_text("hi", FileEncoding.UNICODE_BIG_ENDIAN)
	var opening := Pending.start(vm.open_document)
	var dialog: Requests.FileRequest = modal_of(vm, Requests.FileRequest)
	if dialog == null:
		return
	dialog.complete(Requests.FileChoice.new("/home/tester/wide.txt", FileEncoding.ANSI))
	await opening.wait()

	assert_true(await vm.save())
	assert_eq(rig.documents.writes[0]["encoding"], FileEncoding.UNICODE_BIG_ENDIAN)
	assert_eq(rig.documents.writes[0]["text"], "hi")
