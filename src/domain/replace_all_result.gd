class_name ReplaceAllResult
extends RefCounted
## The text after [method TextSearch.replace_all] and how many matches were replaced.

var text: String
var count: int


func _init(result_text: String = "", result_count: int = 0) -> void:
	text = result_text
	count = result_count
