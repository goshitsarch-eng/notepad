class_name WindowService
extends RefCounted
## Borderless window control. XP draws its own caption, so the OS frame is removed. This
## base class does nothing and is the fake the tests build on; [GodotWindowService] is the
## real one.

signal close_requested
signal active_changed(active: bool)
signal maximized_changed(maximized: bool)
## The window's size changed. On Linux this arrives continuously while an edge is dragged,
## so the handler should wait for the resize to settle before it acts.
signal resized
## Files dragged from the desktop or file manager and dropped onto the window.
signal files_dropped(files: PackedStringArray)

## Edges and corners the user can drag to resize the borderless window.
enum Direction { TOP, LEFT, RIGHT, BOTTOM, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }


## The window's size in logical pixels.
func current_size() -> Vector2:
	return Vector2(600, 404)


## Whether this window tracks a screen position that should be remembered across runs.
func has_position() -> bool:
	return false


## The window's top-left screen position in device pixels.
func current_position() -> Vector2i:
	return Vector2i.ZERO


func set_position(_pos: Vector2i) -> void:
	pass


func is_maximized() -> bool:
	return false


func set_size(_width: float, _height: float) -> void:
	pass


func set_title(_title: String) -> void:
	pass


func set_prevent_close(_prevent: bool) -> void:
	pass


func start_dragging() -> void:
	pass


func start_resizing(_direction: int) -> void:
	pass


func minimize() -> void:
	pass


func toggle_maximize() -> void:
	pass


func close_window() -> void:
	pass
