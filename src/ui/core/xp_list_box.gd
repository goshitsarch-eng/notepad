class_name XpListBox
extends Control
## A scrollable list box with single selection. The box takes keyboard focus: Up and Down
## move the selection, and Home and End jump to the ends. A scroll bar shows only when the
## rows do not fit, as in XP.

## The user chose the row at [param index], by click or key.
signal changed(index: int)
## A double click, which in XP accepts the dialog.
signal activated(index: int)

const ROW_HEIGHT := 16

var labels: PackedStringArray = PackedStringArray()
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()
var accessible_name: String = ""

var _scroll := VScrollBar.new()
var _center_pending := false


func _init(rows: PackedStringArray = PackedStringArray(), box_height: float = 150.0) -> void:
	labels = rows
	custom_minimum_size = Vector2(0, box_height)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_scroll.theme = XpTheme.shared()
	_scroll.step = 1.0
	_scroll.visible = false
	_scroll.value_changed.connect(func(_value: float) -> void: queue_redraw())
	Ui.anchor(_scroll, Vector4(1, 0, 1, 1), Vector4(-1.0 - XpMetrics.SCROLLBAR, 1, -1, -1))
	add_child(_scroll)


func xp_theme_changed() -> void:
	queue_redraw()


func set_rows(rows: PackedStringArray) -> void:
	labels = rows
	queue_redraw()


## Scrolls so that the selected row is in the middle, as a list box opens. The size is not
## known until the box has been laid out, so this is done when it is first drawn.
func center_selection() -> void:
	_center_pending = true
	queue_redraw()


func _visible_rows() -> int:
	return maxi(1, int(floor((size.y - 2.0) / ROW_HEIGHT)))


## As in XP, the bar is shown only when the rows do not fit. The border and padding take
## four pixels.
func _overflows() -> bool:
	return labels.size() * ROW_HEIGHT > size.y - 4.0


## Fits the scroll bar to the rows and to the size of the box. It is done as the box is drawn,
## when its size is known.
func _sync_scroll() -> void:
	_scroll.visible = _overflows()
	_scroll.min_value = 0
	_scroll.max_value = labels.size()
	_scroll.page = _visible_rows()
	if _center_pending:
		_center_pending = false
		if selected >= 0:
			_scroll.value = maxf(0.0, selected - (_visible_rows() - 1) / 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _row_at(position_y: float) -> int:
	var row := int((position_y - 1.0) / ROW_HEIGHT) + int(_scroll.value)
	return row if row >= 0 and row < labels.size() else -1


func _choose(index: int) -> void:
	selected = index
	changed.emit(index)
	_keep_visible(index)


func _keep_visible(index: int) -> void:
	var rows := _visible_rows()
	if index < _scroll.value:
		_scroll.value = index
	elif index >= _scroll.value + rows:
		_scroll.value = index - rows + 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus()
			var row := _row_at(event.position.y)
			if row >= 0:
				# Selected on press, so a single click does not wait out the double click.
				_choose(row)
				if event.double_click:
					activated.emit(row)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll.value -= 3
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll.value += 3
			accept_event()
	elif event is InputEventKey and event.pressed:
		var last := labels.size() - 1
		if last < 0:
			return
		var current := maxi(selected, 0)
		var target := -1
		match event.keycode:
			KEY_DOWN:
				target = mini(current + 1, last)
			KEY_UP:
				target = maxi(current - 1, 0)
			KEY_HOME:
				target = 0
			KEY_END:
				target = last
			_:
				return
		if target != selected:
			_choose(target)
		accept_event()


func _draw() -> void:
	_sync_scroll()
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.paper())
	# A dark border shows where the keyboard is.
	XpDraw.border(self, Rect2(Vector2.ZERO, size),
		XpColors.text() if has_focus() else XpColors.edit_border())
	var top := int(_scroll.value)
	var rows_width := size.x - 2.0 - (XpMetrics.SCROLLBAR if _scroll.visible else 0.0)
	var visible := _visible_rows() + 1
	for offset in range(visible):
		var index := top + offset
		if index >= labels.size():
			break
		var y := 1.0 + offset * ROW_HEIGHT
		var is_selected := index == selected
		if is_selected:
			draw_rect(Rect2(1, y, rows_width, ROW_HEIGHT), XpColors.highlight())
		XpDraw.text_in(self, Rect2(4, y, rows_width - 3, ROW_HEIGHT), labels[index],
			XpColors.highlight_text() if is_selected else XpColors.text())
