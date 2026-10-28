class_name XpDialogWindow
extends Container
## An XP dialog window: a 25px title bar with a close button, the window frame, and a body.
## Dragging the title bar moves the dialog inside the Notepad window, and never so far that
## the title bar is out of reach.

signal close_requested

const _GRAB := 48.0

var title: String = ""
var dialog_width: float = 300.0
## True for a message box, which a screen reader announces as an alert.
var alert: bool = false
## True for a dialog that leaves the window usable, such as Find.
var modeless: bool = false
var content: Control

var _title_bar: Control
var _title_label: Label
var _close_button: XpCaptionButton
## How far the dialog has been dragged from the centre of the window.
var _offset := Vector2.ZERO
var _drag_from := Vector2.ZERO
var _dragging := false
var _closable := true


func _init(dialog_title: String = "", width: float = 300.0, closable: bool = true) -> void:
	title = dialog_title
	dialog_width = width
	_closable = closable
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar = Control.new()
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.draw.connect(_draw_title_bar)
	_title_bar.gui_input.connect(_on_title_input)
	add_child(_title_bar)
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = title
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_title_bar.add_child(_title_label)
	if closable:
		_close_button = XpCaptionButton.new(XpCaptionButton.Kind.CLOSE)
		_close_button.pressed.connect(func() -> void: close_requested.emit())
		_title_bar.add_child(_close_button)
	_style_title()


## Sets what the dialog shows below its title bar.
func set_content(body: Control) -> void:
	if content != null:
		content.queue_free()
	content = body
	add_child(body)
	update_minimum_size()


func title_bar() -> Control:
	return _title_bar


func close_button() -> XpCaptionButton:
	return _close_button


func xp_theme_changed() -> void:
	_style_title()
	queue_redraw()
	_title_bar.queue_redraw()


func _style_title() -> void:
	_title_label.add_theme_font_override("font", XpFonts.title())
	_title_label.add_theme_font_size_override("font_size", XpFonts.ui_size())
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_color_override("font_shadow_color", XpColors.title_shadow())
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)


func _get_minimum_size() -> Vector2:
	var inner := content.get_combined_minimum_size() if content != null else Vector2.ZERO
	# 11px of padding at the sides and above, and 8px above the 4px bottom frame.
	return Vector2(dialog_width, XpMetrics.DIALOG_TITLE_HEIGHT + 11.0 + inner.y + 8.0 + XpMetrics.FRAME)


func accessibility_info() -> Dictionary:
	return {"role": "dialog", "name": title, "modal": not modeless, "alert": alert}


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)
	elif what == NOTIFICATION_SORT_CHILDREN:
		fit_child_in_rect(_title_bar, Rect2(0, 0, size.x, XpMetrics.DIALOG_TITLE_HEIGHT))
		_title_label.position = Vector2(6, 0)
		_title_label.size = Vector2(maxf(size.x - 6 - 26, 0.0), XpMetrics.DIALOG_TITLE_HEIGHT)
		if _close_button != null:
			_close_button.position = Vector2(size.x - 3 - 21, 2)
		if content != null:
			fit_child_in_rect(content, Rect2(
				11, XpMetrics.DIALOG_TITLE_HEIGHT + 11,
				size.x - 22, size.y - XpMetrics.DIALOG_TITLE_HEIGHT - 11 - 8 - XpMetrics.FRAME))


func _draw() -> void:
	XpWindowFrame.draw(self, size, true, XpColors.face())


func _draw_title_bar() -> void:
	XpGradients.fill_vertical(_title_bar, Rect2(Vector2.ZERO, _title_bar.size), XpGradients.title_active())


# ---- Placing and dragging ----

## Centres the dialog in an area of [param area] pixels, then applies the drag. A dialog
## taller than the window starts with its title bar at the top edge rather than above it.
func place(area: Vector2) -> void:
	size = get_combined_minimum_size()
	_offset = clamp_offset(_offset, area)
	var centre := (area - size) / 2.0
	position = centre + _offset


## [param offset] limited to the drags that leave the title bar reachable.
func clamp_offset(offset: Vector2, area: Vector2) -> Vector2:
	var centre := (area - size) / 2.0
	var min_x := minf(_GRAB - size.x, area.x - _GRAB)
	var max_x := maxf(_GRAB - size.x, area.x - _GRAB)
	var max_y := maxf(0.0, area.y - XpMetrics.DIALOG_TITLE_HEIGHT)
	return Vector2(
		clampf(centre.x + offset.x, min_x, max_x) - centre.x,
		clampf(centre.y + offset.y, 0.0, max_y) - centre.y)


func drag_by(delta: Vector2, area: Vector2) -> void:
	# Clamped as it is stored, so a drag past the edge does not have to be dragged back
	# before the dialog moves again.
	_offset = clamp_offset(_offset + delta, area)
	place(area)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_from = event.global_position
		_title_bar.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var area := _area_size()
		drag_by(event.global_position - _drag_from, area)
		_drag_from = event.global_position
		_title_bar.accept_event()


func _area_size() -> Vector2:
	var parent := get_parent() as Control
	return parent.size if parent != null else get_viewport_rect().size
