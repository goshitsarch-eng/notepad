class_name XpCaptionButton
extends Control
## A 21 by 21 Luna caption button with hover and pressed states.

signal pressed

enum Kind { MINIMIZE, MAXIMIZE, RESTORE, CLOSE }

var kind: int = Kind.CLOSE:
	set(value):
		kind = value
		queue_redraw()
		XpAccessibility.changed(self)
var active: bool = true:
	set(value):
		active = value
		queue_redraw()

var _hovered := false
var _held := false


func _init(button_kind: int = Kind.CLOSE) -> void:
	kind = button_kind
	custom_minimum_size = Vector2(21, 21)
	size = Vector2(21, 21)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func accessible_label() -> String:
	match kind:
		Kind.MINIMIZE:
			return "Minimize"
		Kind.MAXIMIZE:
			return "Maximize"
		Kind.RESTORE:
			return "Restore"
	return "Close"


func xp_theme_changed() -> void:
	queue_redraw()


func accessibility_info() -> Dictionary:
	return {"role": "button", "name": accessible_label(),
		"action": func(_data: Variant) -> void: pressed.emit()}


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)
	elif what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		_held = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			queue_redraw()
		else:
			var was_held := _held
			_held = false
			queue_redraw()
			if was_held and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()


func _background() -> Color:
	if kind == Kind.CLOSE:
		if _held:
			return XpColors.close_button_pressed()
		if _hovered:
			return XpColors.close_button_hover()
		return XpColors.close_button()
	if not active:
		return XpColors.caption_inactive()
	if _held:
		return XpColors.caption_pressed()
	if _hovered:
		return XpColors.caption_hover()
	return XpColors.caption_active()


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = _background()
	box.border_color = XpColors.button_glyph_edge()
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var white := Color.WHITE
	match kind:
		Kind.MINIMIZE:
			draw_rect(Rect2(5, 13, 7, 3), white)
		Kind.MAXIMIZE:
			draw_rect(Rect2(5, 5, 11, 3), white)
			draw_rect(Rect2(5, 8, 1, 7), white)
			draw_rect(Rect2(15, 8, 1, 7), white)
			draw_rect(Rect2(5, 14, 11, 1), white)
		Kind.RESTORE:
			draw_rect(Rect2(8, 4, 8, 2), white)
			draw_rect(Rect2(15, 4, 1, 6), white)
			draw_rect(Rect2(4, 8, 9, 3), white)
			draw_rect(Rect2(4, 11, 1, 5), white)
			draw_rect(Rect2(12, 11, 1, 5), white)
			draw_rect(Rect2(4, 15, 9, 1), white)
		Kind.CLOSE:
			draw_line(Vector2(6, 6), Vector2(15, 15), white, 2.0, true)
			draw_line(Vector2(15, 6), Vector2(6, 15), white, 2.0, true)
