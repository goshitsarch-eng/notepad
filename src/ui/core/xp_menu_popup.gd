class_name XpMenuPopup
extends Control
## A popup menu under a menu-bar label. Rows highlight on hover or keyboard movement.

signal highlighted(index: int)
signal activated(index: int)

var items: Array[XpMenuItem] = []
var highlight: int = -1:
	set(value):
		highlight = value
		queue_redraw()
var show_mnemonics: bool = false:
	set(value):
		show_mnemonics = value
		queue_redraw()


func _init(menu_items: Array[XpMenuItem] = []) -> void:
	set_items(menu_items)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_items(menu_items: Array[XpMenuItem]) -> void:
	items = menu_items
	size = Vector2(XpMenuLayout.popup_width(items), XpMenuLayout.popup_height(items))
	custom_minimum_size = size
	queue_redraw()


func xp_theme_changed() -> void:
	queue_redraw()


## The row under [param y], counted from the top of the popup, or -1.
func _row_at(y: float) -> int:
	var top := 3.0
	for index in range(items.size()):
		var height := XpMenuLayout.SEPARATOR_HEIGHT if items[index].is_separator else XpMetrics.MENU_ROW_HEIGHT
		if y >= top and y < top + height:
			return -1 if items[index].is_separator else index
		top += height
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := _row_at(event.position.y)
		if index >= 0 and items[index].enabled and index != highlight:
			highlight = index
			highlighted.emit(index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _row_at(event.position.y)
		# A row is chosen when the button is let go over it, as in XP.
		if not event.pressed and index >= 0 and items[index].enabled:
			activated.emit(index)
		accept_event()


func _draw() -> void:
	# The shadow, soft and offset to the lower right.
	for spread in range(3):
		draw_rect(Rect2(2 + spread * 0.5, 2 + spread * 0.5, size.x, size.y).grow(0.0),
			Color(0, 0, 0, XpColors.menu_shadow().a / 3.0))
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.paper())
	XpDraw.border(self, Rect2(Vector2.ZERO, size), XpColors.menu_border())
	var top := 3.0
	for index in range(items.size()):
		var item := items[index]
		if item.is_separator:
			var y := top + 2.0
			draw_rect(Rect2(3, y, size.x - 6, 1), XpColors.rule_dark())
			draw_rect(Rect2(3, y + 1, size.x - 6, 1), XpColors.rule_light())
			top += XpMenuLayout.SEPARATOR_HEIGHT
			continue
		var active := highlight == index and item.enabled
		var color := XpColors.gray_text() if not item.enabled else (
			XpColors.highlight_text() if active else XpColors.text())
		var row := Rect2(1, top, size.x - 2, XpMetrics.MENU_ROW_HEIGHT)
		if active:
			draw_rect(row, XpColors.highlight())
		if item.checked:
			var origin := Vector2(1 + 7, top + 6)
			var tick := PackedVector2Array([
				origin + Vector2(1, 4.5), origin + Vector2(3.5, 7), origin + Vector2(8, 1.5)])
			draw_polyline(tick, color, 1.6, true)
		var label := MenuLabel.parse(item.label)
		var height := XpFonts.ui().get_height(XpFonts.ui_size())
		label.draw(self, Vector2(1 + 22, top + floorf((XpMetrics.MENU_ROW_HEIGHT - height) / 2.0)),
			color, show_mnemonics)
		if not item.shortcut.is_empty():
			XpDraw.text_in(self, Rect2(1, top, size.x - 2 - 20, XpMetrics.MENU_ROW_HEIGHT),
				item.shortcut, color, null, 0, HORIZONTAL_ALIGNMENT_RIGHT)
		top += XpMetrics.MENU_ROW_HEIGHT
