class_name XpPlainControl
extends Control
## A control that is drawn by a callable and described by a dictionary, for the small parts of the
## window that are not controls of their own, such as the icon of the title bar.

var drawer: Callable = Callable()
var info: Dictionary = {}


func accessibility_info() -> Dictionary:
	return info


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE and not info.is_empty():
		XpAccessibility.apply(self, info)
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)


func _draw() -> void:
	if drawer.is_valid():
		drawer.call()
