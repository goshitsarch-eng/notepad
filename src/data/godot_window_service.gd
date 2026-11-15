class_name GodotWindowService
extends WindowService
## [WindowService] backed by Godot's main window. Sizes are in logical pixels: the window's
## own size divided by its content scale, which follows the screen's scale.

var _window: Window
var _was_maximized: bool = false
var _ui_scale_override: float = 0.0


func _init(window: Window = null) -> void:
	_window = window
	if _window == null:
		return
	_window.close_requested.connect(func() -> void: close_requested.emit())
	_window.focus_entered.connect(func() -> void: active_changed.emit(true))
	_window.focus_exited.connect(func() -> void: active_changed.emit(false))
	_window.size_changed.connect(_on_size_changed)
	_window.files_dropped.connect(func(files: PackedStringArray) -> void: files_dropped.emit(files))


## Determines the HiDPI scale factor for [param screen]. Uses [param override_scale] when set
## (0.5 to 4.0). Otherwise reads the OS screen scale (supported natively on macOS and Wayland),
## falling back on Windows to the monitor DPI divided by 96, and on Linux X11 to GDK/Qt scale
## environment variables or Xft DPI when > 96.
static func detect_scale(
		screen: int = -1, override_scale: float = 0.0, os_name: String = "",
		native_scale: float = -1.0, dpi: int = -1, environment: Variant = null) -> float:
	if is_finite(override_scale) and override_scale >= NotepadSettings.MINIMUM_UI_SCALE \
			and override_scale <= NotepadSettings.MAXIMUM_UI_SCALE:
		return override_scale
	var raw_scale := native_scale
	if raw_scale <= 0.0:
		raw_scale = DisplayServer.screen_get_scale(screen) if screen >= 0 else DisplayServer.screen_get_scale()
	if is_finite(raw_scale) and raw_scale > 1.0:
		return clampf(raw_scale, 1.0, NotepadSettings.MAXIMUM_UI_SCALE)
	var platform := OS.get_name() if os_name.is_empty() else os_name
	if platform == "Windows":
		var screen_dpi := dpi if dpi > 0 else (
			DisplayServer.screen_get_dpi(screen) if screen >= 0 else DisplayServer.screen_get_dpi())
		if screen_dpi > 96:
			return clampf(float(screen_dpi) / 96.0, 1.0, NotepadSettings.MAXIMUM_UI_SCALE)
	elif platform == "Linux":
		for key in ["GDK_DPI_SCALE", "QT_SCALE_FACTOR", "GDK_SCALE"]:
			var text: String = str(environment.get(key, "")) if environment is Dictionary else OS.get_environment(key)
			if text.is_valid_float():
				var parsed := text.to_float()
				if is_finite(parsed) and parsed >= NotepadSettings.MINIMUM_UI_SCALE \
						and parsed <= NotepadSettings.MAXIMUM_UI_SCALE:
					return parsed
	return maxf(raw_scale if is_finite(raw_scale) else 1.0, 1.0)


func configure_scale(override_scale: float = 0.0) -> float:
	_ui_scale_override = override_scale
	if _window == null:
		return 1.0
	var scale := detect_scale(_window.current_screen, _ui_scale_override)
	_apply_scale(scale)
	return scale


func _apply_scale(scale: float) -> void:
	if _window == null:
		return
	_window.content_scale_factor = scale
	_window.min_size = Vector2i(
		roundi(NotepadSettings.MINIMUM_WINDOW_WIDTH * scale),
		roundi(NotepadSettings.MINIMUM_WINDOW_HEIGHT * scale))


func _scale() -> float:
	return maxf(_window.content_scale_factor, 0.01)


func _on_size_changed() -> void:
	if _window != null and _ui_scale_override <= 0.0:
		var target_scale := detect_scale(_window.current_screen, 0.0)
		if not is_equal_approx(target_scale, _window.content_scale_factor):
			_apply_scale(target_scale)
	var maximized := is_maximized()
	if maximized != _was_maximized:
		_was_maximized = maximized
		maximized_changed.emit(maximized)
	resized.emit()


func current_size() -> Vector2:
	return Vector2(_window.size) / _scale()


func has_position() -> bool:
	return _window != null and not Engine.is_embedded_in_editor()


func current_position() -> Vector2i:
	return _window.position if _window != null else Vector2i.ZERO


func set_position(pos: Vector2i) -> void:
	if _window == null or Engine.is_embedded_in_editor():
		return
	_window.position = clamp_to_usable_screen(pos, _window.size, _window.current_screen)


## Keeps a restored window position within the screen's usable area so a window saved on a
## monitor that has since been disconnected never opens off-screen.
static func clamp_to_usable_screen(
		pos: Vector2i, window_size: Vector2i, screen: int = -1,
		usable_override: Rect2i = Rect2i()) -> Vector2i:
	var usable := usable_override
	if usable.size == Vector2i.ZERO:
		usable = DisplayServer.screen_get_usable_rect(screen) if screen >= 0 \
			else DisplayServer.screen_get_usable_rect()
	if usable.size.x <= 0 or usable.size.y <= 0:
		return pos
	var max_x := maxi(usable.position.x, usable.end.x - maxi(window_size.x, 100))
	var max_y := maxi(usable.position.y, usable.end.y - maxi(window_size.y, 100))
	return Vector2i(
		clampi(pos.x, usable.position.x, max_x),
		clampi(pos.y, usable.position.y, max_y))


func is_maximized() -> bool:
	return _window.mode == Window.MODE_MAXIMIZED


func set_size(width: float, height: float) -> void:
	_window.size = Vector2i(roundi(width * _scale()), roundi(height * _scale()))


func set_title(title: String) -> void:
	_window.title = title


func set_prevent_close(prevent: bool) -> void:
	var tree := _window.get_tree()
	if tree != null:
		tree.auto_accept_quit = not prevent


func start_dragging() -> void:
	DisplayServer.window_start_drag(_window.get_window_id())


func start_resizing(direction: int) -> void:
	var edge := DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT
	match direction:
		Direction.TOP:
			edge = DisplayServer.WINDOW_EDGE_TOP
		Direction.LEFT:
			edge = DisplayServer.WINDOW_EDGE_LEFT
		Direction.RIGHT:
			edge = DisplayServer.WINDOW_EDGE_RIGHT
		Direction.BOTTOM:
			edge = DisplayServer.WINDOW_EDGE_BOTTOM
		Direction.TOP_LEFT:
			edge = DisplayServer.WINDOW_EDGE_TOP_LEFT
		Direction.TOP_RIGHT:
			edge = DisplayServer.WINDOW_EDGE_TOP_RIGHT
		Direction.BOTTOM_LEFT:
			edge = DisplayServer.WINDOW_EDGE_BOTTOM_LEFT
	DisplayServer.window_start_resize(edge, _window.get_window_id())


func minimize() -> void:
	_window.mode = Window.MODE_MINIMIZED


func toggle_maximize() -> void:
	_window.mode = Window.MODE_WINDOWED if is_maximized() else Window.MODE_MAXIMIZED


func close_window() -> void:
	var tree := _window.get_tree()
	if tree != null:
		tree.quit()
