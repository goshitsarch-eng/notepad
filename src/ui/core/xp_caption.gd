class_name XpCaption
extends Control
## The 30px Luna title bar: an icon, the title, and minimize, maximize and close buttons.
## Dragging the bar moves the window, and two quick presses toggle maximize, as in XP.

signal drag_started
signal toggle_maximize_requested
signal minimize_requested
signal close_requested
## A click on the icon, or a right click on the bar.
signal window_menu_requested

const _DRAG_SLOP := 4.0

var title: String = "":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value
var active: bool = true:
	set(value):
		active = value
		_apply_state()
var maximized: bool = false:
	set(value):
		maximized = value
		_maximize_button.kind = XpCaptionButton.Kind.RESTORE if value else XpCaptionButton.Kind.MAXIMIZE

var _title_label: Label
var _icon: Control
var _minimize_button: XpCaptionButton
var _maximize_button: XpCaptionButton
var _close_button: XpCaptionButton
var _press_position := Vector2.ZERO
var _pressed := false
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(0, XpMetrics.CAPTION_HEIGHT)
	size = Vector2(0, XpMetrics.CAPTION_HEIGHT)
	_icon = Control.new()
	_icon.position = Vector2(6, 7)
	_icon.size = Vector2(16, 16)
	_icon.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_icon.draw.connect(func() -> void: XpIcons.draw_notepad(_icon, Vector2.ZERO, 16.0))
	_icon.gui_input.connect(_on_icon_input)
	add_child(_icon)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	Ui.anchor(_title_label, Vector4(0, 0, 1, 1), Vector4(26, 0, -75, 0))
	add_child(_title_label)

	_minimize_button = XpCaptionButton.new(XpCaptionButton.Kind.MINIMIZE)
	_maximize_button = XpCaptionButton.new(XpCaptionButton.Kind.MAXIMIZE)
	_close_button = XpCaptionButton.new(XpCaptionButton.Kind.CLOSE)
	_minimize_button.pressed.connect(func() -> void: minimize_requested.emit())
	_maximize_button.pressed.connect(func() -> void: toggle_maximize_requested.emit())
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	# The buttons stay 4px from the right edge, with 2px between them.
	Ui.anchor(_close_button, Vector4(1, 0, 1, 0), Vector4(-25, 4, -4, 25))
	Ui.anchor(_maximize_button, Vector4(1, 0, 1, 0), Vector4(-48, 4, -27, 25))
	Ui.anchor(_minimize_button, Vector4(1, 0, 1, 0), Vector4(-71, 4, -50, 25))
	add_child(_minimize_button)
	add_child(_maximize_button)
	add_child(_close_button)
	_apply_state()


func minimize_button() -> XpCaptionButton:
	return _minimize_button


func maximize_button() -> XpCaptionButton:
	return _maximize_button


func close_button() -> XpCaptionButton:
	return _close_button


func icon_control() -> Control:
	return _icon


func title_label() -> Label:
	return _title_label


func xp_theme_changed() -> void:
	_apply_state()
	queue_redraw()


func _apply_state() -> void:
	if _title_label == null:
		return
	_title_label.add_theme_font_override("font", XpFonts.title())
	_title_label.add_theme_font_size_override("font_size", XpFonts.ui_size())
	_title_label.add_theme_color_override("font_color",
		Color.WHITE if active else XpColors.title_inactive_text())
	_title_label.add_theme_color_override("font_shadow_color",
		XpColors.title_shadow() if active else Color(0, 0, 0, 0))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	for button in [_minimize_button, _maximize_button, _close_button]:
		if button != null:
			button.active = active
	queue_redraw()


func _on_icon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		window_menu_requested.emit()
		_icon.accept_event()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			window_menu_requested.emit()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Two quick presses are a double click. The engine counts them, so a drag
				# that starts on the first press cannot swallow the second.
				if event.double_click:
					_pressed = false
					toggle_maximize_requested.emit()
				else:
					_pressed = true
					_dragging = false
					_press_position = event.position
			else:
				_pressed = false
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _pressed and not _dragging:
		if event.position.distance_to(_press_position) >= _DRAG_SLOP:
			_dragging = true
			_pressed = false
			drag_started.emit()
			accept_event()


func _draw() -> void:
	var gradient := XpGradients.title_active() if active else XpGradients.title_inactive()
	XpGradients.fill_vertical(self, Rect2(Vector2.ZERO, size), gradient)
