class_name FileListView
extends Control
## The XP file list: a header with the four columns and rows built for the entries in view.

signal row_selected(index: int)
signal row_activated(index: int)

const _SIZE_WIDTH := 58.0
const _TYPE_WIDTH := 100.0
const _DATE_WIDTH := 124.0
const _ROW_HEIGHT := 16
const _HEADER_HEIGHT := 18.0

var entries: Array = []
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()
## Shown in place of the rows when the folder could not be listed.
var problem: String = "":
	set(value):
		problem = value
		queue_redraw()

var _list_height: float
var _scroll := VScrollBar.new()


func _init(list_height: float = 200.0) -> void:
	_list_height = list_height
	custom_minimum_size = Vector2(0, list_height + _HEADER_HEIGHT)
	clip_contents = true
	_scroll.theme = XpTheme.shared()
	_scroll.step = 1.0
	_scroll.visible = false
	_scroll.value_changed.connect(func(_value: float) -> void: queue_redraw())
	Ui.anchor(_scroll, Vector4(1, 0, 1, 1),
		Vector4(-1.0 - XpMetrics.SCROLLBAR, _HEADER_HEIGHT + 1.0, -1, -1))
	add_child(_scroll)


func xp_theme_changed() -> void:
	queue_redraw()


func set_entries(new_entries: Array) -> void:
	entries = new_entries
	selected = -1
	_scroll.value = 0
	queue_redraw()


func _visible_rows() -> int:
	return maxi(1, int(floor((size.y - _HEADER_HEIGHT - 2.0) / _ROW_HEIGHT)))


## As in XP, the bar is shown only when the rows do not fit. The border and padding take four
## pixels.
func overflows() -> bool:
	return entries.size() * _ROW_HEIGHT > _list_height - 4.0


## Fits the scroll bar to the rows and to the size of the list, as it is drawn.
func _sync_scroll() -> void:
	_scroll.visible = overflows() and problem.is_empty()
	_scroll.max_value = entries.size()
	_scroll.page = _visible_rows()


func _row_at(y: float) -> int:
	var row := int((y - _HEADER_HEIGHT - 1.0) / _ROW_HEIGHT) + int(_scroll.value)
	return row if row >= 0 and row < entries.size() and y >= _HEADER_HEIGHT + 1.0 else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var row := _row_at(event.position.y)
			if row >= 0:
				# Selected on press, so a single click does not wait out the double click.
				row_selected.emit(row)
				if event.double_click:
					row_activated.emit(row)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.value -= 3
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.value += 3
			accept_event()


static func type_of(entry: DirectoryEntry) -> String:
	if entry.is_directory:
		return "File Folder"
	return "Text Document" if entry.name.get_extension().to_lower() == "txt" else "File"


static func size_of(entry: DirectoryEntry) -> String:
	if entry.is_directory:
		return ""
	return "%d KB" % int(ceil(float(entry.size) / 1024.0))


func _draw() -> void:
	_sync_scroll()
	# The header, with the width of the scroll bar reserved at its end.
	draw_rect(Rect2(0, 0, size.x, _HEADER_HEIGHT), XpColors.face())
	var columns_start := size.x - XpMetrics.SCROLLBAR - _SIZE_WIDTH - _TYPE_WIDTH - _DATE_WIDTH
	XpDraw.text_in(self, Rect2(4, 0, columns_start, _HEADER_HEIGHT), "Name", XpColors.text())
	XpDraw.text_in(self, Rect2(columns_start + 4, 0, _SIZE_WIDTH, _HEADER_HEIGHT), "Size", XpColors.text())
	XpDraw.text_in(self, Rect2(columns_start + _SIZE_WIDTH + 4, 0, _TYPE_WIDTH, _HEADER_HEIGHT), "Type", XpColors.text())
	XpDraw.text_in(self, Rect2(columns_start + _SIZE_WIDTH + _TYPE_WIDTH + 4, 0, _DATE_WIDTH, _HEADER_HEIGHT),
		"Date Modified", XpColors.text())
	var body := Rect2(0, _HEADER_HEIGHT, size.x, size.y - _HEADER_HEIGHT)
	draw_rect(body, XpColors.paper())
	XpDraw.border(self, body, XpColors.edit_border())
	if not problem.is_empty():
		var lines := problem.split("\n")
		var line_height := XpFonts.ui().get_height(XpFonts.ui_size())
		var top := body.position.y + (body.size.y - lines.size() * line_height) / 2.0
		for index in range(lines.size()):
			var width := XpDraw.text_width(lines[index])
			XpDraw.text(self, Vector2(body.position.x + (body.size.x - width) / 2.0, top + index * line_height),
				lines[index], XpColors.gray_text())
		return
	var rows_width := size.x - 2.0 - (XpMetrics.SCROLLBAR if _scroll.visible else 0.0)
	var name_width := rows_width - _SIZE_WIDTH - _TYPE_WIDTH - _DATE_WIDTH
	var top_index := int(_scroll.value)
	for offset in range(_visible_rows() + 1):
		var index := top_index + offset
		if index >= entries.size():
			break
		var entry: DirectoryEntry = entries[index]
		var y := body.position.y + 1.0 + offset * _ROW_HEIGHT
		var is_selected := index == selected
		var color := XpColors.highlight_text() if is_selected else XpColors.text()
		if is_selected:
			draw_rect(Rect2(1, y, rows_width, _ROW_HEIGHT), XpColors.highlight())
		if entry.is_directory:
			XpIcons.draw_folder(self, Vector2(3, y))
		else:
			XpIcons.draw_document(self, Vector2(3, y))
		XpDraw.text_in(self, Rect2(23, y, name_width - 22, _ROW_HEIGHT),
			XpDraw.fit(entry.name, name_width - 24), color)
		XpDraw.text_in(self, Rect2(1 + name_width, y, _SIZE_WIDTH, _ROW_HEIGHT), size_of(entry), color)
		XpDraw.text_in(self, Rect2(1 + name_width + _SIZE_WIDTH, y, _TYPE_WIDTH, _ROW_HEIGHT), type_of(entry), color)
		XpDraw.text_in(self, Rect2(1 + name_width + _SIZE_WIDTH + _TYPE_WIDTH, y, _DATE_WIDTH, _ROW_HEIGHT),
			TimeDate.format_modified(entry.modified_moment()), color)
