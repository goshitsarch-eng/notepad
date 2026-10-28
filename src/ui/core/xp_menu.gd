class_name XpMenu
extends RefCounted
## A top-level menu: its label and the rows of its popup.

var label: String = ""
var items: Array[XpMenuItem] = []


func _init(menu_label: String = "", menu_items: Array[XpMenuItem] = []) -> void:
	label = menu_label
	items = menu_items
