class_name XpTextEdit
extends TextEdit
## The XP edit control, on Godot's TextEdit, which does the editing, undo, caret, selection,
## scrolling and wrapping, and copes with documents of tens of megabytes. This adds what is
## particular to Notepad: Tab types a tab, Insert does not switch to overtype, text is pasted
## with LF line ends, and selected text is drawn in white over the blue highlight.

## F5 was pressed in the text.
signal time_date_requested

const _PAD_LEFT := 2.0
const _PAD_TOP := 1.0
const _PAD_RIGHT := 2.0


func _init() -> void:
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
					undo()
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


# ---- Editing ----

## Replaces the selection, or inserts at the caret, as one step of the undo list.
func replace_selection(value: String) -> void:
	begin_complex_operation()
	if has_selection():
		delete_selection()
	if not value.is_empty():
		insert_text_at_caret(value)
	end_complex_operation()


func copy_selection() -> void:
	if has_selection():
		Clipboard.set_text(get_selected_text())


func cut_selection() -> void:
	if not has_selection():
		return
	Clipboard.set_text(get_selected_text())
	replace_selection("")


func paste_clipboard() -> void:
	var pasted := Clipboard.get_text()
	if pasted.is_empty():
		return
	replace_selection(pasted.replace("\r\n", "\n"))


## Whether the document has any text at all, without copying it.
func has_text() -> bool:
	return get_line_count() > 1 or get_line(0).length() > 0


## Replaces the whole document without touching the undo list, for a document that is
## opened or started: the list starts empty, and nothing counts as an edit.
func load_document(content: String) -> void:
	text = content
	clear_undo_history()
	set_caret_line(0)
	set_caret_column(0)
	deselect()
	scroll_vertical = 0
	scroll_horizontal = 0


# ---- Offsets ----
# The document's characters are numbered from zero through all its lines, with one for each
# line feed. These conversions work on the document's text, which the caller has fetched.

## The offset of the caret within [param full_text].
func caret_offset(full_text: String) -> int:
	return offset_of(full_text, get_caret_line(), get_caret_column())


## The start and end of the selection as offsets, or the caret twice when nothing is
## selected, as a Vector2i.
func selection_offsets(full_text: String) -> Vector2i:
	if not has_selection():
		var caret := caret_offset(full_text)
		return Vector2i(caret, caret)
	var start := offset_of(full_text, get_selection_from_line(), get_selection_from_column())
	var end := offset_of(full_text, get_selection_to_line(), get_selection_to_column())
	return Vector2i(mini(start, end), maxi(start, end))


## Selects the characters from [param start] to [param end], with the caret at the end, and
## scrolls them into view.
func select_offsets(full_text: String, start: int, end: int) -> void:
	var from := position_of(full_text, start)
	var to := position_of(full_text, end)
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
	var line := full_text.count("\n", 0, clamped)
	var line_start := 0
	if clamped > 0:
		line_start = full_text.rfind("\n", clamped - 1) + 1
	return Vector2i(line, clamped - line_start)
