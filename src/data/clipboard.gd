class_name Clipboard
extends RefCounted
## The system clipboard. Where the display server has none, as when the app is driven without
## a display, text is kept in memory instead, so copy and paste still work between the parts of
## the app.

static var _memory := ""


static func _native() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)


static func get_text() -> String:
	return DisplayServer.clipboard_get() if _native() else _memory


static func set_text(value: String) -> void:
	if _native():
		DisplayServer.clipboard_set(value)
	else:
		_memory = value


static func has_text() -> bool:
	return not get_text().is_empty()
