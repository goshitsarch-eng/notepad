class_name XpEditor
extends Control
## The XP edit control's frame: a white, bordered text area. The text, its scroll bars and
## the wrapping come from the engine's TextEdit, which shows a vertical scroll bar when the
## text overflows that way and a horizontal one when word wrap is off. This adds the border
## and the face-coloured box in the corner where the two bars meet.

var text_edit: XpTextEdit

var _corner := Control.new()


func _init(control: XpTextEdit = null) -> void:
	text_edit = control
	clip_contents = true
	if text_edit != null:
		text_edit.focus_mode = Control.FOCUS_ALL
		Ui.anchor(text_edit, Vector4(0, 0, 1, 1), Vector4(1, 1, -1, -1))
		add_child(text_edit)
		var vertical := text_edit.get_v_scroll_bar()
		var horizontal := text_edit.get_h_scroll_bar()
		vertical.visibility_changed.connect(_update_corner)
		horizontal.visibility_changed.connect(_update_corner)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.visible = false
	Ui.anchor(_corner, Vector4(1, 1, 1, 1), Vector4(-18, -18, -1, -1))
	_corner.draw.connect(func() -> void: _corner.draw_rect(Rect2(Vector2.ZERO, _corner.size), XpColors.face()))
	add_child(_corner)


func xp_theme_changed() -> void:
	queue_redraw()
	_corner.queue_redraw()


func _update_corner() -> void:
	if text_edit == null:
		return
	_corner.visible = text_edit.get_v_scroll_bar().visible and text_edit.get_h_scroll_bar().visible


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.paper())
	XpDraw.border(self, Rect2(Vector2.ZERO, size), XpColors.edit_border())
