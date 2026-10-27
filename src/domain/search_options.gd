class_name SearchOptions
extends RefCounted
## What Find, Find Next, Replace and Replace All look for.

var query: String = ""
var match_case: bool = false
var whole_word: bool = false
var forward: bool = true


func _init(
		search_query: String = "", search_match_case: bool = false,
		search_whole_word: bool = false, search_forward: bool = true) -> void:
	query = search_query
	match_case = search_match_case
	whole_word = search_whole_word
	forward = search_forward


func copy_with(changes: Dictionary) -> SearchOptions:
	return SearchOptions.new(
		changes.get("query", query),
		changes.get("match_case", match_case),
		changes.get("whole_word", whole_word),
		changes.get("forward", forward))
