class_name HeaderFooterLine
extends RefCounted
## A header or footer line after its codes are filled in, split by alignment.

var left: String
var center: String
var right: String


func _init(left_text: String = "", center_text: String = "", right_text: String = "") -> void:
	left = left_text
	center = center_text
	right = right_text


func is_empty() -> bool:
	return left.is_empty() and center.is_empty() and right.is_empty()
