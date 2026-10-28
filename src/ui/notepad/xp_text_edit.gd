class_name XpTextEdit
extends TextEdit
## The XP edit control, on Godot's TextEdit, which does the editing, undo, caret, selection,
## scrolling and wrapping. This adds what is particular to Notepad: Tab types a tab, Insert does
## not switch to overtype, text is pasted with LF line ends, and selected text is drawn in white
## over the blue highlight.
##
## A document of 128 thousand characters or more is edited through a window of its lines (see
## [LargeDocument]), because TextEdit shapes every line it holds. Everything outside this class
## asks the document methods below, which answer for the whole document either way.

## F5 was pressed in the text.
signal time_date_requested
## The document is shown through a window now, or no longer is.
signal windowed_changed(active: bool)
## The window moved, the scroll position changed or the document changed size, so a scroll bar of
## the whole document should be read again.
signal document_changed

## A document of at least this many characters is edited through a window.
const LARGE_DOCUMENT_CHARACTERS := 128 * 1024

const _PAD_LEFT := 2.0
const _PAD_TOP := 1.0
const _PAD_RIGHT := 2.0

var _large: LargeDocument = null


func _init() -> void:
	accessibility_name = "Text editor"
	context_menu_enabled = false
	empty_selection_clipboard_enabled = false
	middle_mouse_paste_enabled = false
	drag_and_drop_selection_enabled = false
	caret_multiple = false
	caret_blink = true
	deselect_on_focus_loss_enabled = false
	scroll_smooth = false
	scroll_past_end_of_file = false
	highlight_current_line = false
	virtual_keyboard_enabled = false
	minimap_draw = false
	set_tab_size(8)
	theme = XpTheme.shared()
	configure(EditorFont.new(), true)
	# The engine runs its own handling of a key after this signal and skips it when the event
	# is marked as handled here, which is how the keys below are taken over.
	gui_input.connect(_intercept)
	lines_edited_from.connect(_on_lines_edited)
	get_v_scroll_bar().value_changed.connect(_on_scrolled)


## Sets the font and the wrapping, and the colours of the current palette.
func configure(font: EditorFont, word_wrap: bool) -> void:
	var face := XpFonts.editor(font)
	var size := XpFonts.editor_size(font)
	add_theme_font_override("font", face)
	add_theme_font_size_override("font_size", size)
	add_theme_constant_override("line_spacing", XpFonts.editor_line_height(font) - int(ceil(face.get_height(size))))
	add_theme_constant_override("caret_width", 1)
	apply_palette()
	var margins := StyleBoxEmpty.new()
	margins.content_margin_left = _PAD_LEFT
	margins.content_margin_top = _PAD_TOP
	margins.content_margin_right = _PAD_RIGHT
	margins.content_margin_bottom = 0.0
	for name in ["normal", "focus", "read_only"]:
		add_theme_stylebox_override(name, margins)
	wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if word_wrap else TextEdit.LINE_WRAPPING_NONE
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Puts the colours of the current palette on the text, which Dark Mode changes.
func apply_palette() -> void:
	add_theme_color_override("font_color", XpColors.text())
	add_theme_color_override("font_readonly_color", XpColors.text())
	# Selected text is white over the highlight, as in XP's edit control.
	add_theme_color_override("font_selected_color", XpColors.highlight_text())
	add_theme_color_override("selection_color", XpColors.highlight())
	add_theme_color_override("caret_color", XpColors.text())
	add_theme_color_override("caret_background_color", XpColors.paper())
	add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
	add_theme_color_override("background_color", XpColors.paper())


func xp_theme_changed() -> void:
	apply_palette()
	queue_redraw()


# ---- Keys that are not the engine's own ----

func _intercept(event: InputEvent) -> void:
	if _large != null and _intercept_windowed(event):
		accept_event()
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		var command := key.ctrl_pressed or key.meta_pressed
		match key.keycode:
			KEY_TAB:
				# Tab types a tab character, replacing the selection, as in Notepad.
				if not command and not key.alt_pressed and not key.shift_pressed:
					replace_selection("\t")
					accept_event()
					return
			KEY_BACKSPACE:
				if key.alt_pressed and not command and not key.shift_pressed:
					undo_edit()
					accept_event()
					return
			KEY_INSERT:
				# Insert does not switch to overtype. With Ctrl it copies, and with Shift it pastes.
				if command:
					copy_selection()
				elif key.shift_pressed:
					paste_clipboard()
				accept_event()
				return
			KEY_V:
				if command and not key.alt_pressed:
					paste_clipboard()
					accept_event()
					return
			KEY_X:
				if command and not key.alt_pressed:
					cut_selection()
					accept_event()
					return
			KEY_C:
				if command and not key.alt_pressed:
					copy_selection()
					accept_event()
					return
			KEY_DELETE:
				if key.shift_pressed and not command:
					cut_selection()
					accept_event()
					return


## The keys and clicks that a window of the document must see before the control does. Returns
## true when it took the event.
func _intercept_windowed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.pressed:
			# A click puts the caret where it is, and ends any selection bigger than the window.
			_large.virtual_caret = null
			_large.clear_wide()
		return false
	if not (event is InputEventKey) or not event.pressed:
		return false
	var key := event as InputEventKey
	var command := key.ctrl_pressed or key.meta_pressed
	if command and not key.alt_pressed:
		match key.keycode:
			KEY_A:
				_large.select_all()
				return true
			KEY_Z:
				undo_edit()
				return true
			KEY_HOME, KEY_END:
				# The control moves only within its window, so the ends of the document are
				# reached here.
				_go_to_edge(key.keycode == KEY_END, key.shift_pressed)
				return true
			KEY_C, KEY_INSERT, KEY_X:
				return false
	if key.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK]:
		return false
	# A key that edits or moves the caret acts at the caret, so the window first goes back to it if
	# the view was scrolled away.
	if _large.virtual_caret != null and _acts_at_caret(key, command):
		_large.restore_caret()
	if _large.wide != null and not command:
		return _act_on_wide_selection(key)
	return false


## True for a key that types, deletes or moves the caret.
func _acts_at_caret(key: InputEventKey, command: bool) -> bool:
	if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN,
			KEY_BACKSPACE, KEY_DELETE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB]:
		return true
	return key.unicode >= 32 and not command and not key.alt_pressed


## What a key does while a selection bigger than the window is active: typing or deleting replaces
## the whole of it, and moving the caret ends it.
func _act_on_wide_selection(key: InputEventKey) -> bool:
	match key.keycode:
		KEY_BACKSPACE, KEY_DELETE:
			replace_selection("")
			return true
		KEY_ENTER, KEY_KP_ENTER:
			replace_selection("\n")
			return true
		KEY_TAB:
			return false
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN:
			var caret := _large.caret_document()
			_large.clear_wide()
			deselect()
			_large.set_caret_document(caret)
			return false
	if key.unicode >= 32 and not key.alt_pressed:
		replace_selection(String.chr(key.unicode))
		return true
	return false


func _go_to_edge(end: bool, extend: bool) -> void:
	var target := _large.end_position() if end else Vector2i.ZERO
	if extend:
		var anchor: Vector2i = _large.wide["anchor"] if _large.wide != null else _large.caret_document()
		_large.set_wide(anchor, target)
		adjust_viewport_to_caret()
		return
	_large.clear_wide()
	_large.go_to(target.x)
	if end:
		set_caret_line(get_line_count() - 1)
		set_caret_column(get_line(get_line_count() - 1).length())
		adjust_viewport_to_caret()


func _on_lines_edited(from_line: int, to_line: int) -> void:
	if _large != null:
		_large.on_edited(from_line, to_line)


func _on_scrolled(_value: float) -> void:
	if _large != null:
		_large.on_scrolled()


# ---- The document: the same answers for a small one and for one shown through a window ----

func is_windowed() -> bool:
	return _large != null


## The window of a large document, or null while the control holds all the text.
func large_document() -> LargeDocument:
	return _large


## The number of edits so far. It moves on with every edit, and the view model compares it with
## what it was when the document was opened or saved.
func document_version() -> int:
	return _large.version if _large != null else get_version()


## The whole text of the document, with LF line ends.
func document_text() -> String:
	return _large.full_text() if _large != null else get_text()


func document_line_count() -> int:
	return _large.total_lines() if _large != null else get_line_count()


## Whether the document has any text at all, without copying it.
func has_text() -> bool:
	if _large != null:
		return true
	return get_line_count() > 1 or get_line(0).length() > 0


## The caret's line in the document, counted from 0.
func caret_document_line() -> int:
	return _large.caret_document().x if _large != null else get_caret_line()


## The text of the caret's line that lies before the caret.
func caret_prefix() -> String:
	if _large != null:
		var position := _large.caret_document()
		return _large.line_at(position.x).substr(0, position.y)
	# While the text is being replaced the caret can briefly name a line that is gone.
	var line := clampi(get_caret_line(), 0, get_line_count() - 1)
	return get_line(line).substr(0, get_caret_column())


func has_document_selection() -> bool:
	return has_selection() or (_large != null and _large.wide != null)


func selected_document_text() -> String:
	if _large != null and _large.wide != null:
		var full := _large.full_text()
		var offsets := selection_offsets(full)
		return full.substr(offsets.x, offsets.y - offsets.x)
	return get_selected_text()


func can_undo_edit() -> bool:
	return _large.can_undo() if _large != null else has_undo()


func undo_edit() -> void:
	if _large != null:
		_large.undo()
	elif has_undo():
		undo()


func select_all_document() -> void:
	if _large != null:
		_large.select_all()
	else:
		select_all()


## Puts the caret at the start of line [param line] (counted from 1, and kept within the document).
func go_to_document_line(line: int) -> void:
	if _large != null:
		_large.go_to(line - 1)
		return
	var target := clampi(line, 1, get_line_count())
	deselect()
	set_caret_line(target - 1)
	set_caret_column(0)
	adjust_viewport_to_caret()


## Replaces the whole document by [param value], as Replace All does, with the caret at its start.
func replace_document(value: String) -> void:
	if _large == null and value.length() >= LARGE_DOCUMENT_CHARACTERS:
		_enter_windowed()
	if _large != null:
		_large.restore_caret()
		_large.replace_range(Vector2i.ZERO, _large.end_position(), value)
		_large.go_to(0)
		return
	begin_complex_operation()
	select_all()
	replace_selection(value)
	set_caret_line(0)
	set_caret_column(0)
	deselect()
	end_complex_operation()
	adjust_viewport_to_caret()


## Replaces the selection, or inserts at the caret, as one step of the undo list.
func replace_selection(value: String) -> void:
	if _large == null and value.length() >= LARGE_DOCUMENT_CHARACTERS:
		_enter_windowed()
	if _large != null:
		_large.restore_caret()
		if _large.wide != null or value.length() > LargeDocument.WINDOW_CHARS:
			var full := _large.full_text()
			var offsets := selection_offsets(full)
			_large.replace_range(position_of(full, offsets.x), position_of(full, offsets.y), value)
			return
	begin_complex_operation()
	if has_selection():
		delete_selection()
	if not value.is_empty():
		insert_text_at_caret(value)
	end_complex_operation()


func copy_selection() -> void:
	if has_document_selection():
		Clipboard.set_text(selected_document_text())


func cut_selection() -> void:
	if not has_document_selection():
		return
	Clipboard.set_text(selected_document_text())
	replace_selection("")


func paste_clipboard() -> void:
	var pasted := Clipboard.get_text()
	if pasted.is_empty():
		return
	replace_selection(pasted.replace("\r\n", "\n"))


## Replaces the whole document without touching the undo list, for a document that is opened or
## started: the list starts empty, and nothing counts as an edit. A big document is shown through
## a window.
func load_document(content: String) -> void:
	if content.length() >= LARGE_DOCUMENT_CHARACTERS:
		_start_windowed(content.split("\n"))
		return
	if _large != null:
		_stop_windowed()
	text = content
	clear_undo_history()
	set_caret_line(0)
	set_caret_column(0)
	deselect()
	scroll_vertical = 0
	scroll_horizontal = 0


## Moves what the control holds into a window of a large document, as when a big paste has made a
## small document large.
func _enter_windowed() -> void:
	if _large != null:
		return
	var full := get_text()
	var offsets := selection_offsets(full)
	var start := position_of(full, offsets.x)
	_start_windowed(full.split("\n"), start)
	if offsets.y > offsets.x:
		_large.select_range(start, position_of(full, offsets.y))


func _start_windowed(lines: PackedStringArray, caret: Vector2i = Vector2i.ZERO) -> void:
	var first := _large == null
	var base_version := document_version()
	if first:
		_large = LargeDocument.new(self)
	_large.build(lines, caret.x, caret.y)
	# The count of edits goes on from where it was, so a document that was changed is still
	# changed, and an earlier count is never reached again.
	_large.version = base_version + 1
	if first:
		windowed_changed.emit(true)


func _stop_windowed() -> void:
	_large = null
	windowed_changed.emit(false)


# ---- Offsets ----
# The document's characters are numbered from zero through all its lines, with one for each line
# feed. These conversions work on the document's text, which the caller has fetched.

## The offset of the caret within [param full_text].
func caret_offset(full_text: String) -> int:
	if _large != null:
		var position := _large.caret_document()
		return offset_of(full_text, position.x, position.y)
	return offset_of(full_text, get_caret_line(), get_caret_column())


## The start and end of the selection as offsets, or the caret twice when nothing is selected, as a
## Vector2i.
func selection_offsets(full_text: String) -> Vector2i:
	if _large != null and _large.wide != null:
		var anchor: Vector2i = _large.wide["anchor"]
		var caret: Vector2i = _large.wide["caret"]
		var first := offset_of(full_text, anchor.x, anchor.y)
		var second := offset_of(full_text, caret.x, caret.y)
		return Vector2i(mini(first, second), maxi(first, second))
	var shift := _large.win_start if _large != null else 0
	if not has_selection():
		var caret_at := caret_offset(full_text)
		return Vector2i(caret_at, caret_at)
	var start := offset_of(full_text, get_selection_from_line() + shift, get_selection_from_column())
	var end := offset_of(full_text, get_selection_to_line() + shift, get_selection_to_column())
	return Vector2i(mini(start, end), maxi(start, end))


## Selects the characters from [param start] to [param end], with the caret at the end, and scrolls
## them into view.
func select_offsets(full_text: String, start: int, end: int) -> void:
	var from := position_of(full_text, start)
	var to := position_of(full_text, end)
	if _large != null:
		_large.select_range(from, to)
		return
	select(from.x, from.y, to.x, to.y)
	set_caret_line(to.x)
	set_caret_column(to.y)
	adjust_viewport_to_caret()


static func offset_of(full_text: String, line: int, column: int) -> int:
	var cursor := 0
	for _line in range(line):
		var feed := full_text.find("\n", cursor)
		if feed < 0:
			return full_text.length()
		cursor = feed + 1
	return mini(cursor + column, full_text.length())


## The line and column, as a Vector2i, of the character at [param offset].
static func position_of(full_text: String, offset: int) -> Vector2i:
	var clamped := clampi(offset, 0, full_text.length())
	# String.count treats an end of 0 as "to the end of the string", so offset 0 is its own case.
	var line := 0
	var line_start := 0
	if clamped > 0:
		line = full_text.count("\n", 0, clamped)
		line_start = full_text.rfind("\n", clamped - 1) + 1
	return Vector2i(line, clamped - line_start)
