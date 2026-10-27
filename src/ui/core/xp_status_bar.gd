class_name XpStatusBar
extends Control
## The 19px status bar under the editor, with a sunken "Ln 1, Col 1" field and a size grip.

## The size grip was dragged, which starts a window resize.
signal resize_requested

var text: String = "":
	set(value):
		text = value
		queue_redraw()

var _grip_pressed := false


func _init() -> void:
	custom_minimum_size = Vector2(0, XpMetrics.STATUS_BAR_HEIGHT)
	size = Vector2(0, XpMetrics.STATUS_BAR_HEIGHT)


func xp_theme_changed() -> void:
	queue_redraw()


func _grip_rect() -> Rect2:
	return Rect2(size.x - 13.0, size.y - 13.0, 13.0, 13.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_grip_pressed = event.pressed and _grip_rect().has_point(event.position)
		if _grip_pressed:
			resize_requested.emit()
			_grip_pressed = false
		accept_event()
	elif event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if _grip_rect().has_point(event.position) \
			else Control.CURSOR_ARROW


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.face())
	var field_width := maxf(110.0, XpDraw.text_width(text) + 8.0 + 2.0)
	var field := Rect2(2, 1, field_width, 17)
	draw_rect(Rect2(field.position.x, field.position.y, field.size.x, 1), XpColors.rule_dark())
	draw_rect(Rect2(field.position.x, field.position.y, 1, field.size.y), XpColors.rule_dark())
	draw_rect(Rect2(field.position.x, field.end.y - 1, field.size.x, 1), XpColors.rule_light())
	draw_rect(Rect2(field.end.x - 1, field.position.y, 1, field.size.y), XpColors.rule_light())
	XpDraw.text_in(self, Rect2(field.position.x + 5, field.position.y, field.size.x - 5, field.size.y),
		text, XpColors.text())
	XpIcons.draw_size_grip(self, _grip_rect().position)
