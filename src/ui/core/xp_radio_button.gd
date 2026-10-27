class_name XpRadioButton
extends Control
## A Luna radio button with its label. Clicking selects it. Parents keep the group state.
## The arrow keys emit [signal moved] with -1 (left or up) or 1 (right or down), and the
## parent then selects and focuses the neighbour, as the arrow keys do in a Windows radio
## group.

signal selected
signal moved(step: int)

var label: String = ""
var is_selected: bool = false:
	set(value):
		is_selected = value
		queue_redraw()


func _init(button_label: String = "", chosen: bool = false) -> void:
	label = button_label
	is_selected = chosen
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(13.0 + 6.0 + XpDraw.text_width(label) + 2.0, 15.0)


func xp_theme_changed() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		selected.emit()
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and not event.echo:
			selected.emit()
			accept_event()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_UP:
			moved.emit(-1)
			accept_event()
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_DOWN:
			moved.emit(1)
			accept_event()


func _draw() -> void:
	var box_top := floorf((size.y - 13.0) / 2.0)
	draw_texture(XpDraw.box_texture(true), Vector2(0, box_top))
	if is_selected:
		draw_circle(Vector2(6.5, 6.5 + box_top), 2.5, XpColors.check_mark(), true, -1.0, true)
	XpDraw.text_in(self, Rect2(19, 0, size.x - 19, size.y), label, XpColors.text())
	if has_focus() and XpDraw.keyboard_active:
		var height := XpFonts.ui().get_height(XpFonts.ui_size())
		XpDraw.focus_cue(self, Rect2(19, floorf((size.y - height) / 2.0), XpDraw.text_width(label), height),
			XpColors.text())
