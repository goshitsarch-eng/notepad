class_name NotepadViewModel
extends RefCounted
## State and commands of the Notepad window. The view reads it and calls its methods. It
## reaches files, settings, printing and the window only through their interfaces, so tests
## build it with fakes. Commands that ask the user something wait for the answer, so they
## are called with `await`.

## Something the view shows has changed.
signal changed
## Ctrl+F, Edit > Find or Ctrl+H was asked for while the Find dialog is open: it loads the
## current query and takes focus.
signal find_requested
## Keyboard focus should return to the open Find box, keeping the text typed there.
signal find_focus_requested

## The value of [method open_menu] while no menu is open.
const NO_MENU := -2
## The value of [method open_menu] while the window menu of the title bar is open. The menus
## of the menu bar are numbered from 0.
const SYSTEM_MENU := -1

## Documents longer than this many characters get a warning before they open. Past this size
## opening takes several seconds, and the text and the copies that editing makes of it use a
## lot of memory.
const DEFAULT_LARGE_DOCUMENT_CHARACTERS := 16 * 1024 * 1024

var documents: DocumentRepository
var settings_repository: SettingsRepository
var file_system: FileSystemService
var printing: PrintingService
var window: WindowService
## Returns the current moment as a datetime dictionary. Tests replace it.
var clock: Callable = Callable(Time, "get_datetime_dict_from_system")
## Tests lower this to avoid building huge strings.
var large_document_characters: int = DEFAULT_LARGE_DOCUMENT_CHARACTERS

## The document text. The editor shows this control.
var text: XpTextEdit

var _settings: NotepadSettings
## Counts the requests that replace the document. A read that finishes after a newer request
## has started is dropped, so it cannot replace what the user chose since.
var _document_request := 0
## The text control's edit count when the document was opened or last saved. Once the count
## has moved on, the document counts as modified, and it stays so.
var _clean_version := 0
var _has_normal_bounds := false
## The last size the window had while it was not maximized, in logical pixels. Saved at
## exit, so a maximized window does not persist its maximized size as the normal one.
var _normal_bounds := Vector2.ZERO
var _path := ""
var _encoding: int = FileEncoding.ANSI
var _modified := false
var _active := true
var _maximized := false
var _exiting := false
var _open_menu := NO_MENU
var _menu_opened_by_click := false
var _menu_cue := false
var _clipboard_has_text := false
var _modal: Variant = null
var _find: Variant = null
var _last_search := SearchOptions.new()
var _saving := false
var _resize_serial := 0
## True from the moment a dialog is shown until the last one waiting has closed. A dialog
## that closes hands the screen straight to the next one, so none slips in between.
var _modal_busy := false
var _modal_waiters: Array = []
var _disposed := false


func _init(
		dependencies: AppDependencies, initial_settings: NotepadSettings,
		clock_override: Callable = Callable()) -> void:
	documents = dependencies.documents
	settings_repository = dependencies.settings
	file_system = dependencies.file_system
	printing = dependencies.printing
	window = dependencies.window
	if clock_override.is_valid():
		clock = clock_override
	_settings = initial_settings
	XpColors.dark = initial_settings.dark_mode
	XpTheme.refresh()
	text = XpTextEdit.new()
	text.configure(_settings.font, _settings.word_wrap)
	# The control reports an edit one step after it, so what is asked of the view model is
	# answered from the control's edit count, which is exact at once.
	text.text_changed.connect(func() -> void: changed.emit())
	text.caret_changed.connect(func() -> void: changed.emit())


# ---- What the view shows ----

func file_name() -> String:
	return "Untitled" if _path.is_empty() else _path.get_file()


func window_title() -> String:
	return "%s - Notepad" % file_name()


func is_modified() -> bool:
	if not _modified and text.document_version() != _clean_version:
		_modified = true
	return _modified


func word_wrap() -> bool:
	return _settings.word_wrap


## The View > Status Bar check mark.
func status_bar_checked() -> bool:
	return _settings.status_bar_visible


## The bar is shown only when the setting is on and word wrap is off, as in XP.
func status_bar_visible() -> bool:
	return _settings.status_bar_visible and not _settings.word_wrap


func font() -> EditorFont:
	return _settings.font


func page_setup() -> PageSetup:
	return _settings.page_setup


func dark_mode() -> bool:
	return _settings.dark_mode


func settings() -> NotepadSettings:
	return _settings


func open_menu() -> int:
	return _open_menu


func menu_opened_by_click() -> bool:
	return _menu_opened_by_click


func menu_cue() -> bool:
	return _menu_cue


func clipboard_has_text() -> bool:
	return _clipboard_has_text


## The dialog that is open, or null.
func modal() -> Variant:
	return _modal


## The Find or Replace dialog's state while it is open, or null.
func find_state() -> Variant:
	return _find


func last_search() -> SearchOptions:
	return _last_search


func is_active() -> bool:
	return _active


func is_maximized() -> bool:
	return _maximized


func path() -> String:
	return _path


func encoding() -> int:
	return _encoding


func has_selection() -> bool:
	return text.has_document_selection()


func has_text() -> bool:
	return text.has_text()


func can_undo() -> bool:
	return text.can_undo_edit()


## The caret's 1-based line and column, as a Vector2i. The column counts UTF-16 units, as the
## status bar of XP Notepad does.
func caret_position() -> Vector2i:
	return Vector2i(text.caret_document_line() + 1, TextMetrics.utf16_length(text.caret_prefix()) + 1)


func status_text() -> String:
	var position := caret_position()
	return "Ln %d, Col %d" % [position.x, position.y]


# ---- Document lifecycle ----

func new_document() -> void:
	if not await _confirm_discard_changes():
		return
	_set_document("", "", FileEncoding.ANSI)


func open_document() -> void:
	var asked_version := text.document_version()
	if not await _confirm_discard_changes():
		return
	# The user has just agreed to lose these edits, so the load does not ask again. Text
	# typed since the question was asked, such as while the Yes answer was still saving, is
	# different text and was never agreed to, so it is left to ask.
	var agreed := text.document_version() == asked_version
	var request := DialogRequests.FileRequest.new(
		DialogRequests.FileDialogMode.OPEN, _start_directory(), _encoding)
	var choice: DialogRequests.FileChoice = await _show_modal(request)
	if choice == null:
		return
	await _open_path(choice.path, asked_version if agreed else -1, choice.open_as)


func save() -> bool:
	if _path.is_empty():
		return await save_as()
	return await _write_to(_path, _encoding)


func save_as() -> bool:
	var request := DialogRequests.FileRequest.new(
		DialogRequests.FileDialogMode.SAVE, _start_directory(), _encoding,
		file_name() if not _path.is_empty() else "")
	var choice: DialogRequests.FileChoice = await _show_modal(request)
	if choice == null:
		return false
	if choice.path != _path and file_system.file_exists(choice.path):
		var answer: Variant = await _message(
			"Notepad",
			"%s already exists.\n\nDo you want to replace it?" % choice.path.get_file(),
			DialogRequests.MessageIcon.WARNING,
			[DialogRequests.MessageChoice.YES, DialogRequests.MessageChoice.NO])
		if answer != DialogRequests.MessageChoice.YES:
			return false
	return await _write_to(choice.path, choice.encoding)


func edit_page_setup() -> void:
	var result: Variant = await _show_modal(DialogRequests.PageSetupRequest.new(_settings.page_setup))
	if result == null:
		return
	_settings = _settings.copy_with({"page_setup": result})
	_persist_settings()
	changed.emit()


func print_document() -> void:
	var result: Result = await printing.print_document(
		text.document_text(), file_name(), _settings.page_setup)
	if not result.ok:
		await _message(
			"Notepad", "Notepad cannot print the document.",
			DialogRequests.MessageIcon.ERROR, [DialogRequests.MessageChoice.OK])


## File > Exit, the caption close button and Alt+F4 all end here.
func request_exit() -> void:
	if _exiting:
		return
	if not await _confirm_discard_changes():
		return
	_exiting = true
	_resize_serial += 1
	var normal := _normal_bounds if window.is_maximized() else window.current_size()
	if window.is_maximized() and not _has_normal_bounds:
		normal = Vector2.ZERO
	if normal != Vector2.ZERO:
		_settings = _settings.copy_with({"window_width": normal.x, "window_height": normal.y})
	_save_settings()
	window.set_prevent_close(false)
	window.close_window()


# ---- Editing ----

func undo() -> void:
	if can_undo():
		text.undo_edit()


func cut() -> void:
	text.cut_selection()


func copy() -> void:
	text.copy_selection()


func paste() -> void:
	text.paste_clipboard()


func delete_selection() -> void:
	if has_selection():
		text.replace_selection("")


func select_all() -> void:
	text.select_all_document()


func insert_time_date() -> void:
	insert_text(TimeDate.format_time_date(clock.call()))


func insert_text(value: String) -> void:
	text.replace_selection(value)


## Refreshes whether Edit > Paste is available. Called when a menu opens.
func refresh_clipboard() -> void:
	var available := Clipboard.has_text()
	if available == _clipboard_has_text:
		return
	_clipboard_has_text = available
	changed.emit()


# ---- Find, Replace and Go To ----

func show_find(replace: bool) -> void:
	if has_selection():
		var selected := text.selected_document_text()
		if not selected.contains("\n"):
			_last_search = _last_search.copy_with({"query": selected})
	_find = DialogRequests.FindState.new(replace)
	find_requested.emit()
	changed.emit()


func close_find() -> void:
	if _find == null:
		return
	_find = null
	changed.emit()


## Gives focus back to the open Find box, for example after a message box closes.
func focus_find() -> void:
	find_focus_requested.emit()


## Selects the next match from the caret. Returns false and says so when nothing matches.
func find_next(options: SearchOptions) -> bool:
	_last_search = options
	var full := text.document_text()
	var selection := text.selection_offsets(full)
	var from := selection.y if options.forward else selection.x
	var found := TextSearch.find(full, options, from)
	if found == null:
		_say_cannot_find(options.query)
		return false
	_select(full, found.start, found.end)
	changed.emit()
	return true


func repeat_find() -> void:
	find_next(_last_search)


func replace_current(options: SearchOptions, replacement: String) -> bool:
	_last_search = options
	if has_selection():
		var selected := text.selected_document_text()
		var exact := TextSearch.find(selected, options.copy_with({"forward": true}), 0)
		if exact != null and exact.start == 0 and exact.end == selected.length():
			text.replace_selection(replacement)
	return find_next(options)


## Replace All. Reports when nothing matched, as XP does.
func replace_all_matches(options: SearchOptions, replacement: String) -> bool:
	_last_search = options
	var result := TextSearch.replace_all(text.document_text(), options, replacement)
	if result.count == 0:
		_say_cannot_find(options.query)
		return false
	text.replace_document(result.text)
	return true


func show_go_to() -> void:
	var result: Variant = await _show_modal(DialogRequests.GoToRequest.new(caret_position().x))
	if result != null:
		go_to_line(result)


func go_to_line(line: int) -> void:
	text.go_to_document_line(line)


func _say_cannot_find(query: String) -> void:
	# The message is not waited for: the search that found nothing is over.
	_message(
		"Notepad", "Cannot find \"%s\"" % query,
		DialogRequests.MessageIcon.INFORMATION, [DialogRequests.MessageChoice.OK])


# ---- Format and View ----

func toggle_word_wrap() -> void:
	_settings = _settings.copy_with({"word_wrap": not _settings.word_wrap})
	text.configure(_settings.font, _settings.word_wrap)
	_persist_settings()
	changed.emit()


func toggle_status_bar() -> void:
	if _settings.word_wrap:
		return
	_settings = _settings.copy_with({"status_bar_visible": not _settings.status_bar_visible})
	_persist_settings()
	changed.emit()


func show_font() -> void:
	var result: Variant = await _show_modal(DialogRequests.FontRequest.new(_settings.font))
	if result == null:
		return
	_settings = _settings.copy_with({"font": result})
	text.configure(_settings.font, _settings.word_wrap)
	_persist_settings()
	changed.emit()


# ---- Help ----

func show_about() -> void:
	await _show_modal(DialogRequests.AboutRequest.new())


## Help > Help Topics and F1. Lists the shortcuts the app really responds to.
func show_help() -> void:
	await _show_modal(DialogRequests.HelpRequest.new())


## View > Dark Mode. The colours switch on the next frame and the choice is saved.
func toggle_dark_mode() -> void:
	_settings = _settings.copy_with({"dark_mode": not _settings.dark_mode})
	XpColors.dark = _settings.dark_mode
	XpTheme.refresh()
	text.xp_theme_changed()
	_persist_settings()
	changed.emit()


# ---- Menus and keyboard cues ----

## Opens the menu at [param index], or closes the menu when [param index] is [constant NO_MENU].
func open_menu_at(index: int, by_click: bool = false) -> void:
	_open_menu = index
	_menu_opened_by_click = index != NO_MENU and by_click
	changed.emit()


func close_menu() -> void:
	if _open_menu == NO_MENU:
		return
	_open_menu = NO_MENU
	_menu_opened_by_click = false
	changed.emit()


func set_menu_cue(visible: bool) -> void:
	if _menu_cue == visible:
		return
	_menu_cue = visible
	changed.emit()


# ---- Window ----

func start_dragging() -> void:
	window.start_dragging()


func start_resizing(direction: int) -> void:
	window.start_resizing(direction)


func minimize() -> void:
	window.minimize()


func toggle_maximize() -> void:
	window.toggle_maximize()


## Connects the window events and sets the first title. Opens [param initial_path] if given.
func start(initial_path: String = "") -> void:
	window.close_requested.connect(on_close_requested)
	window.active_changed.connect(on_active_changed)
	window.maximized_changed.connect(on_maximized_changed)
	window.resized.connect(on_resized)
	window.set_prevent_close(true)
	window.set_title(window_title())
	refresh_clipboard()
	if not initial_path.is_empty():
		_open_path(initial_path)


func on_close_requested() -> void:
	# The window cannot close while a dialog is open. Otherwise the close would replace that
	# dialog and leave its answer unread.
	if _modal != null:
		return
	request_exit()


func on_active_changed(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if not active:
		_open_menu = NO_MENU
	changed.emit()


func on_maximized_changed(maximized: bool) -> void:
	if _maximized == maximized:
		return
	_maximized = maximized
	changed.emit()


func on_resized() -> void:
	_resize_serial += 1
	var serial := _resize_serial
	var tree := Engine.get_main_loop() as SceneTree
	await tree.create_timer(0.15).timeout
	if serial != _resize_serial or _disposed:
		return
	_settle_size()


## Runs after a resize. Linux window managers can let an edge drag go below the minimum
## size, so the app holds the minimum itself. It also remembers the size the window has when
## it is not maximized.
func _settle_size() -> void:
	var size := window.current_size()
	if size.x < NotepadSettings.MINIMUM_WINDOW_WIDTH or size.y < NotepadSettings.MINIMUM_WINDOW_HEIGHT:
		window.set_size(
			maxf(size.x, NotepadSettings.MINIMUM_WINDOW_WIDTH),
			maxf(size.y, NotepadSettings.MINIMUM_WINDOW_HEIGHT))
		return
	if window.is_maximized():
		return
	_normal_bounds = size
	_has_normal_bounds = true


func dispose() -> void:
	_disposed = true
	_resize_serial += 1
	for waiter in _modal_waiters:
		(waiter as Turn).finish()
	_modal_waiters.clear()
	if text != null and is_instance_valid(text):
		if text.is_inside_tree():
			text.queue_free()
		else:
			text.free()
	text = null


# ---- Internals ----

class Turn extends RefCounted:
	signal turn
	var _finished := false

	func finish() -> void:
		if _finished:
			return
		_finished = true
		turn.emit()

	func wait() -> void:
		if not _finished:
			await turn


func _set_document(content: String, new_path: String, new_encoding: int) -> void:
	_document_request += 1
	_path = new_path
	_encoding = new_encoding
	text.load_document(content)
	_clean_version = text.document_version()
	_modified = false
	_sync_title()
	changed.emit()


func _select(full: String, start: int, end: int) -> void:
	text.select_offsets(full, start, end)


## Reads [param file_path] and shows it, as [param as_encoding] when the Open dialog was told
## to, and by detecting it otherwise. [param discard_agreed_at] is the edit count the user has
## already agreed to lose, from the save prompt shown before the file dialog, or -1. While the
## text is still at that count, the replacement needs no second prompt.
func _open_path(
		file_path: String, discard_agreed_at: int = -1,
		as_encoding: int = FileEncoding.DETECT) -> void:
	_document_request += 1
	var request := _document_request
	var result: Result = await documents.read(file_path, as_encoding)
	# A newer New, Open or start-up file has taken over, so this result is no longer wanted.
	if request != _document_request or _disposed:
		return
	if result.ok:
		# Text typed while the file was read is not in the file. Ask before it is replaced.
		var agreed := discard_agreed_at >= 0 and text.document_version() == discard_agreed_at
		var wanted := func() -> bool: return request == _document_request
		if not agreed and not await _confirm_discard_changes(wanted):
			return
		var file: TextFile = result.value
		if file.text.length() > large_document_characters \
				and not await _confirm_large_document(file_path.get_file(), file, wanted):
			return
		# A question may have waited behind another dialog, and the user may have opened
		# something else meanwhile.
		if not wanted.call():
			return
		_settings = _settings.copy_with({"last_directory": file_path.get_base_dir()})
		_persist_settings()
		_set_document(file.text, file_path, file.encoding)
	else:
		var name := file_path.get_file()
		var reason := FileError.describe(result.error)
		# A missing file has its own XP wording. Any other reason is told as it is.
		var missing: bool = (result.error is FileError and result.error.kind == FileError.Kind.NOT_FOUND) \
			or (reason.is_empty() and not file_system.file_exists(file_path))
		var message := "Cannot find \"%s\". Make sure the path and file name are correct." % name \
			if missing else "Cannot open \"%s\".%s" % [name, "" if reason.is_empty() else "\n\n" + reason]
		await _message(
			"Notepad", message, DialogRequests.MessageIcon.ERROR, [DialogRequests.MessageChoice.OK],
			func() -> bool: return request == _document_request)


func _write_to(file_path: String, new_encoding: int) -> bool:
	# XP warns before ANSI silently replaces characters Windows-1252 cannot hold.
	if new_encoding == FileEncoding.ANSI and not TextCodec.can_encode_ansi(text.document_text()):
		var answer: Variant = await _message(
			"Notepad",
			"%s\nThis file contains Unicode characters which will be lost if\n"
			% file_path.get_file()
			+ "you save this file in the ANSI encoding.\n"
			+ "To keep these characters, click Cancel, and then select\n"
			+ "one of the Unicode options in the Encoding drop down list.\n"
			+ "Continue?",
			DialogRequests.MessageIcon.WARNING,
			[DialogRequests.MessageChoice.OK, DialogRequests.MessageChoice.CANCEL])
		if answer != DialogRequests.MessageChoice.OK:
			return false
	if _saving:
		return false
	_saving = true
	var saved_version := text.document_version()
	var result: Result = await documents.write(file_path, text.document_text(), new_encoding)
	_saving = false
	if not result.ok:
		var reason := FileError.describe(result.error)
		await _message(
			"Notepad",
			"Cannot save \"%s\" in \"%s\".%s" % [
				file_path.get_file(), file_path.get_base_dir(),
				"" if reason.is_empty() else "\n\n" + reason],
			DialogRequests.MessageIcon.ERROR, [DialogRequests.MessageChoice.OK])
		return false
	_path = file_path
	_encoding = new_encoding
	# Typing during the save is not in the file, so the document stays modified.
	_clean_version = saved_version
	_modified = text.document_version() != saved_version
	_settings = _settings.copy_with({"last_directory": file_path.get_base_dir()})
	_persist_settings()
	_sync_title()
	changed.emit()
	return true


## Warns that a large file takes a while to open and uses a lot of memory, and asks whether
## to open it anyway.
func _confirm_large_document(name: String, file: TextFile, still_wanted: Callable) -> bool:
	var millions := "%.1f" % (float(file.text.length()) / 1000000.0)
	var answer: Variant = await _message(
		"Notepad",
		"The file \"%s\" is large (%s million characters).\n\n" % [name, millions]
		+ "It takes a while to open a file this size, and it uses a lot of memory.\n\n"
		+ "Do you want to open it anyway?",
		DialogRequests.MessageIcon.WARNING,
		[DialogRequests.MessageChoice.YES, DialogRequests.MessageChoice.NO], still_wanted)
	return answer == DialogRequests.MessageChoice.YES


## Asks whether to save changes before the text is replaced or the window closes. Returns
## true when the caller may go ahead.
func _confirm_discard_changes(still_wanted: Callable = Callable()) -> bool:
	if not is_modified():
		return true
	var answer: Variant = await _message(
		"Notepad",
		"The text in the %s file has changed.\n\nDo you want to save the changes?" % file_name(),
		DialogRequests.MessageIcon.WARNING,
		[DialogRequests.MessageChoice.YES, DialogRequests.MessageChoice.NO,
			DialogRequests.MessageChoice.CANCEL],
		still_wanted)
	match answer:
		DialogRequests.MessageChoice.YES:
			return await save()
		DialogRequests.MessageChoice.NO:
			return true
	return false


func _message(
		title: String, message: String, icon: int, choices: Array[int],
		still_wanted: Callable = Callable()) -> Variant:
	return await _show_modal(
		DialogRequests.MessageRequest.new(title, message, icon, choices), still_wanted)


## Shows one modal dialog and waits for its answer. Only one is shown at a time. A dialog
## asked for while another is open waits for its turn, as a message that is ready while About
## is open, instead of being refused. [param still_wanted] is asked once its turn has come:
## when it says no, because the request has been replaced meanwhile, the dialog is not shown
## and the answer is null, which counts as a cancel.
func _show_modal(request: DialogRequests.Request, still_wanted: Callable = Callable()) -> Variant:
	if _modal_busy:
		var turn := Turn.new()
		_modal_waiters.append(turn)
		await turn.wait()
		if _disposed or (still_wanted.is_valid() and not still_wanted.call()):
			_end_modal_turn()
			return null
	_modal_busy = true
	_modal = request
	changed.emit()
	var answer: Variant = await request.result()
	_end_modal_turn()
	return answer


## Gives the screen to the next dialog in line, or clears it.
func _end_modal_turn() -> void:
	if not _modal_waiters.is_empty():
		(_modal_waiters.pop_front() as Turn).finish()
		return
	var shown := _modal != null
	_modal = null
	_modal_busy = false
	if shown and not _disposed:
		changed.emit()


## The folder the file dialogs start in. The dialog itself moves up to the nearest folder
## that exists, if the last one has been deleted or moved since.
func _start_directory() -> String:
	if not _settings.last_directory.is_empty():
		return _settings.last_directory
	return file_system.home_directory()


func _sync_title() -> void:
	window.set_title(window_title())


func _persist_settings() -> void:
	_save_settings()


func _save_settings() -> void:
	# Settings are a convenience. A failed save must not block editing or closing.
	settings_repository.save_settings(_settings)
