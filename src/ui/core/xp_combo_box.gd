class_name XpComboBox
extends Control
## A drop-down list in the Luna style. The list opens in a layer above the window, below the
## box, or above it when there is no room below, as XP's combo boxes do.

signal changed(index: int)

const _ROW_HEIGHT := 16

var labels: PackedStringArray = PackedStringArray()
var selected: int = 0:
	set(value):
		selected = value
		queue_redraw()
## A box that is not enabled shows its value, greyed, and cannot be opened. XP draws a choice
## that has nothing to choose from this way.
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()
var accessible_name: String = ""

var _popup: Control


func _init(options: PackedStringArray = PackedStringArray(), box_width: float = 0.0) -> void:
	labels = options
	custom_minimum_size = Vector2(box_width, XpMetrics.FIELD_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func xp_theme_changed() -> void:
	queue_redraw()


func is_open() -> bool:
	return _popup != null and is_instance_valid(_popup)


func close_list() -> void:
	if is_open():
		_popup.queue_free()
	_popup = null


func _exit_tree() -> void:
	close_list()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if enabled:
			toggle()
		accept_event()


## Opens the list, or closes it when it is open.
func toggle() -> void:
	if is_open():
		close_list()
		return
	if labels.is_empty():
		return
	var below := get_global_rect().end.y
	var room := get_viewport().get_visible_rect().size.y - below
	var list_height := labels.size() * _ROW_HEIGHT + 2.0
	_popup = _ComboPopup.new(self, room < list_height)
	get_tree().root.add_child(_popup)


func _choose(index: int) -> void:
	close_list()
	selected = index
	changed.emit(index)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, XpColors.paper() if enabled else XpColors.face())
	XpDraw.border(self, rect, XpColors.edit_border())
	var shown := labels[selected] if selected >= 0 and selected < labels.size() else (labels[0] if not labels.is_empty() else "")
	var color := XpColors.text() if enabled else XpColors.gray_text()
	XpDraw.text_in(self, Rect2(3, 0, size.x - 23, size.y), shown, color)
	var arrow := PackedVector2Array([
		Vector2(size.x - 6 - 7, 8), Vector2(size.x - 6, 8), Vector2(size.x - 6 - 3.5, 12)])
	draw_colored_polygon(arrow, color)


## The open list: a catcher over the whole window, so a click anywhere else closes it, and the
## rows.
class _ComboPopup extends Control:
	var _combo: XpComboBox
	var _upward: bool

	func _init(combo: XpComboBox, upward: bool) -> void:
		_combo = combo
		_upward = upward
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		# The screen leaves Escape to an open list, so it closes the list and not the dialog.
		add_to_group("xp_open_list")
		grab_focus()

	func _list_rect() -> Rect2:
		var box := _combo.get_global_rect()
		var height := _combo.labels.size() * XpComboBox._ROW_HEIGHT + 2.0
		var top := box.position.y - height if _upward else box.end.y
		return Rect2(box.position.x, top, box.size.x, height)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var list := _list_rect()
			if list.has_point(event.position):
				var row := int((event.position.y - list.position.y - 1.0) / XpComboBox._ROW_HEIGHT)
				if row >= 0 and row < _combo.labels.size():
					_combo._choose(row)
			else:
				_combo.close_list()
			accept_event()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_combo.close_list()
			accept_event()

	func _draw() -> void:
		var list := _list_rect()
		draw_rect(list, XpColors.paper())
		XpDraw.border(self, list, XpColors.edit_border())
		for index in range(_combo.labels.size()):
			var row := Rect2(list.position.x + 1, list.position.y + 1 + index * XpComboBox._ROW_HEIGHT,
				list.size.x - 2, XpComboBox._ROW_HEIGHT)
			var chosen := index == _combo.selected
			if chosen:
				draw_rect(row, XpColors.highlight())
			XpDraw.text_in(self, Rect2(row.position.x + 3, row.position.y, row.size.x - 3, row.size.y),
				_combo.labels[index], XpColors.highlight_text() if chosen else XpColors.text())
