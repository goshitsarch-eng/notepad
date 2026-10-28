class_name XpCheckBox
extends Control
## A Luna check box with its label. Click or Space toggles it.

signal toggled(value: bool)

var label: String = ""
var value: bool = false:
	set(new_value):
		value = new_value
		queue_redraw()
		XpAccessibility.changed(self)


func _init(box_label: String = "", checked: bool = false) -> void:
	label = box_label
	value = checked
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(13.0 + 6.0 + XpDraw.text_width(label) + 2.0, 15.0)


func xp_theme_changed() -> void:
	queue_redraw()


func accessibility_info() -> Dictionary:
	return {"role": "check_box", "name": label, "checked": value,
		"action": func(_data: Variant) -> void: _toggle()}


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)


func _toggle() -> void:
	value = not value
	toggled.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_toggle()
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle()
		accept_event()


func _draw() -> void:
	var box_top := floorf((size.y - 13.0) / 2.0)
	draw_texture(XpDraw.box_texture(false), Vector2(0, box_top))
	if value:
		var points := PackedVector2Array([
			Vector2(3, 6.5) + Vector2(0, box_top), Vector2(5.5, 9) + Vector2(0, box_top),
			Vector2(10, 3.8) + Vector2(0, box_top)])
		draw_polyline(points, XpColors.check_mark(), 2.0, true)
	var label_box := Rect2(19, 0, size.x - 19, size.y)
	XpDraw.text_in(self, label_box, label, XpColors.text())
	if has_focus() and XpDraw.keyboard_active:
		var text_box := Rect2(19, floorf((size.y - XpFonts.ui().get_height(XpFonts.ui_size())) / 2.0),
			XpDraw.text_width(label), XpFonts.ui().get_height(XpFonts.ui_size()))
		XpDraw.focus_cue(self, text_box, XpColors.text())
