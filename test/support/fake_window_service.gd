class_name FakeWindowService
extends WindowService
## A window that is a few fields. The test calls the signals' emit to play what the user or
## the window manager does.

var title := ""
var prevent_close := false
var closed := false
var maximized := false
## How many times the caption asked to maximize or restore the window.
var maximize_toggles := 0
## How many times the window was asked to minimize.
var minimizes := 0
var size := Vector2(500, 400)
var drags := 0
var resizes: Array[int] = []


func current_size() -> Vector2:
	return size


func is_maximized() -> bool:
	return maximized


func set_size(width: float, height: float) -> void:
	size = Vector2(width, height)


func set_title(new_title: String) -> void:
	title = new_title


func set_prevent_close(prevent: bool) -> void:
	prevent_close = prevent


func start_dragging() -> void:
	drags += 1


func start_resizing(direction: int) -> void:
	resizes.append(direction)


func minimize() -> void:
	minimizes += 1


func toggle_maximize() -> void:
	maximize_toggles += 1


func close_window() -> void:
	closed = true
