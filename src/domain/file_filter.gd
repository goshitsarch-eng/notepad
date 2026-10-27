class_name FileTypeFilter
extends RefCounted
## One entry in the "Files of type" list of the Open and Save As dialogs.

var label: String
## Lower-case extensions including the dot. Empty matches every file.
var extensions: PackedStringArray

static var _text_documents: FileTypeFilter
static var _all_files: FileTypeFilter


func _init(filter_label: String = "", filter_extensions: PackedStringArray = PackedStringArray()) -> void:
	label = filter_label
	extensions = filter_extensions


func matches(file_name: String) -> bool:
	if extensions.is_empty():
		return true
	var lower := file_name.to_lower()
	for extension in extensions:
		if lower.ends_with(extension):
			return true
	return false


func equals(other: FileTypeFilter) -> bool:
	return other != null and other.label == label


static func text_documents() -> FileTypeFilter:
	if _text_documents == null:
		_text_documents = FileTypeFilter.new("Text Documents (*.txt)", PackedStringArray([".txt"]))
	return _text_documents


static func all_files() -> FileTypeFilter:
	if _all_files == null:
		_all_files = FileTypeFilter.new("All Files (*.*)")
	return _all_files
