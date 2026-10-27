class_name TextFile
extends RefCounted
## A file that has been read: its text (with LF line ends) and the encoding it used.

var text: String
var encoding: int


func _init(file_text: String = "", file_encoding: int = FileEncoding.ANSI) -> void:
	text = file_text
	encoding = file_encoding
