class_name GodotWindowService
extends WindowService
## [WindowService] backed by Godot's main window. Sizes are in logical pixels: the window's
## own size divided by its content scale, which follows the screen's scale.

var _window: Window
var _was_maximized: bool = false


func _init(window: Window = null) -> void:
	_window = window
	if _window == null:
		return
	_window.close_requested.connect(func() -> void: close_requested.emit())
	_window.focus_entered.connect(func() -> void: active_changed.emit(true))
	_window.focus_exited.connect(func() -> void: active_changed.emit(false))
	_window.size_changed.connect(_on_size_changed)


func _scale() -> float:
	return maxf(_window.content_scale_factor, 0.01)


func _on_size_changed() -> void:
	var maximized := is_maximized()
	if maximized != _was_maximized:
		_was_maximized = maximized
		maximized_changed.emit(maximized)
	resized.emit()


func current_size() -> Vector2:
	return Vector2(_window.size) / _scale()


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
