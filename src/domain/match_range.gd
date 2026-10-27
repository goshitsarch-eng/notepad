class_name MatchRange
extends RefCounted
## A matched span [start, end) in characters.

var start: int
var end: int


func _init(range_start: int = 0, range_end: int = 0) -> void:
	start = range_start
	end = range_end
