class_name XpButton
extends Control
## A Luna push button, 75 by 23 by default. Enter or Space presses it while it has focus.
## A default button gets the blue inner ring that XP gives the dialog's main action.

signal pressed

var label: String = ""
var is_default: bool = false
var disabled: bool = false:
	set(value):
		disabled = value
		queue_redraw()

var _hovered := false
var _held := false


func _init(button_label: String = "", button_default: bool = false, width: float = XpMetrics.BUTTON_WIDTH) -> void:
	label = button_label
	is_default = button_default
	custom_minimum_size = Vector2(width, XpMetrics.BUTTON_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func xp_theme_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_held = false
			queue_redraw()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
				and not event.alt_pressed and not event.ctrl_pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var gradient := XpGradients.button_pressed() if _held and not disabled else XpGradients.button_face()
	XpDraw.gradient_box(self, rect, 3, XpColors.button_border(), gradient)
	if is_default:
		_ring(rect.grow(-1.0), XpColors.button_default_ring(), 2)
	if _hovered and not disabled:
		_ring(rect.grow(-2.0), XpColors.button_hover_ring(), 2)
	if has_focus():
		var focus_box := rect.grow(-4.0)
		draw_rect(focus_box, XpColors.button_focus_ring(), false, 1.0)
	var color := XpColors.gray_text() if disabled else XpColors.text()
	XpDraw.text_in(self, rect, label, color, null, 0, HORIZONTAL_ALIGNMENT_CENTER)


func _ring(rect: Rect2, color: Color, radius: int) -> void:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = color
	ring.set_border_width_all(1)
	ring.set_corner_radius_all(radius)
	ring.anti_aliasing = true
	draw_style_box(ring, rect)
