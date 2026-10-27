class_name XpMenuItem
extends RefCounted
## One row of a popup menu, or a separator line.

var label: String = ""
var shortcut: String = ""
var enabled: bool = true
var checked: bool = false
## True for an item that has a check mark state, such as Word Wrap.
var checkable: bool = false
var on_selected: Callable = Callable()
var is_separator: bool = false


static func make(
		item_label: String, item_shortcut: String = "", item_enabled: bool = true,
		item_checked: bool = false, item_checkable: bool = false,
		selected: Callable = Callable()) -> XpMenuItem:
	var item := XpMenuItem.new()
	item.label = item_label
	item.shortcut = item_shortcut
	item.enabled = item_enabled
	item.checked = item_checked
	item.checkable = item_checkable
	item.on_selected = selected
	return item


static func separator() -> XpMenuItem:
	var item := XpMenuItem.new()
	item.is_separator = true
	item.enabled = false
	return item
