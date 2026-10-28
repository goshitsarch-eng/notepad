class_name XpMenuBar
extends Control
## The Luna menu bar: a 19px face-coloured strip of labels.

signal pressed(index: int)
signal hovered(index: int)

var menus: Array[XpMenu] = []
var open_index: int = -1:
	set(value):
		open_index = value
		queue_redraw()
		XpAccessibility.changed(self)
var show_mnemonics: bool = false:
	set(value):
		show_mnemonics = value
		queue_redraw()

var _hover_index := -1


func _init() -> void:
	custom_minimum_size = Vector2(0, XpMetrics.MENU_BAR_HEIGHT)
	size = Vector2(0, XpMetrics.MENU_BAR_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_menus(new_menus: Array[XpMenu]) -> void:
	menus = new_menus
	queue_redraw()
	XpAccessibility.changed(self)


func xp_theme_changed() -> void:
	queue_redraw()


## The left edge of the label at [param index], and its width.
func label_span(index: int) -> Vector2:
	var left := 0.0
	for position in range(index):
		left += XpMenuLayout.bar_label_width(menus[position].label)
	return Vector2(left, XpMenuLayout.bar_label_width(menus[index].label))


func _index_at(x: float) -> int:
	var left := 0.0
	for index in range(menus.size()):
		var width := XpMenuLayout.bar_label_width(menus[index].label)
		if x >= left and x < left + width:
			return index
		left += width
	return -1


func accessibility_info() -> Dictionary:
	var rows: Array[Dictionary] = []
	for index in range(menus.size()):
		var span := label_span(index)
		var menu_index := index
		rows.append({"role": "menu_item", "name": MenuLabel.parse(menus[index].label).text,
			"expanded": index == open_index, "rect": Rect2(span.x, 0, span.y, size.y),
			"action": func(_data: Variant) -> void: pressed.emit(menu_index)})
	return {"role": "menu_bar", "name": "Application", "children": rows}


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_index = -1
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _index_at(event.position.x)
		if index != _hover_index:
			_hover_index = index
			if index >= 0:
				hovered.emit(index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := _index_at(event.position.x)
		if index >= 0:
			pressed.emit(index)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.face())
	var left := 0.0
	for index in range(menus.size()):
		var width := XpMenuLayout.bar_label_width(menus[index].label)
		var is_open := index == open_index
		if is_open:
			draw_rect(Rect2(left, 0, width, size.y), XpColors.highlight())
		var label := MenuLabel.parse(menus[index].label)
		var color := XpColors.highlight_text() if is_open else XpColors.text()
		var height := XpFonts.ui().get_height(XpFonts.ui_size())
		label.draw(self, Vector2(left + 5.5, floorf((size.y - height) / 2.0)), color, show_mnemonics)
		left += width
