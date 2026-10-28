class_name XpAccessibility
extends RefCounted
## What the app's own controls tell assistive technology, such as a screen reader: a role, a name,
## and a state, for menus, buttons, fields, check boxes, radio buttons, lists, dialogs and the
## status bar. The engine's controls (the text editor, the text boxes, the labels, the scroll bars)
## describe themselves.
##
## Each control of the app has an accessibility_info() that answers with a Dictionary:
##   "role"       a key of [constant ROLES]
##   "name"       what the control is called
##   "value"      what it holds, for a list or a box that shows a choice
##   "checked"    for a check box, a radio button or a check item: true or false
##   "selected"   for a row of a list or a menu that is chosen
##   "disabled"   true for a control that cannot be used now
##   "expanded"   true for a menu or a list that is open
##   "modal"      true for a dialog that blocks the window
##   "alert"      true for a message box, which the reader announces at once
##   "shortcut"   the keys of a menu item
##   "action"     a Callable that clicking it by assistive technology runs
##   "children"   rows, each with the same keys, for a list or a menu
## and the engine's update then passes it on through [method apply].

## While a dialog is open this is its host, and everything outside it is hidden from assistive
## technology, as the window behind a dialog is.
static var modal_root: Node = null

const ROLES := {
	"button": DisplayServer.ROLE_BUTTON,
	"default_button": DisplayServer.ROLE_DEFAULT_BUTTON,
	"check_box": DisplayServer.ROLE_CHECK_BOX,
	"radio_button": DisplayServer.ROLE_RADIO_BUTTON,
	"menu_bar": DisplayServer.ROLE_MENU_BAR,
	"menu": DisplayServer.ROLE_MENU,
	"menu_item": DisplayServer.ROLE_MENU_ITEM,
	"menu_item_check": DisplayServer.ROLE_MENU_ITEM_CHECK_BOX,
	"list": DisplayServer.ROLE_LIST_BOX,
	"list_option": DisplayServer.ROLE_LIST_BOX_OPTION,
	"dialog": DisplayServer.ROLE_DIALOG,
	"region": DisplayServer.ROLE_REGION,
	"group": DisplayServer.ROLE_CONTAINER,
	"title_bar": DisplayServer.ROLE_TITLE_BAR,
	"text": DisplayServer.ROLE_STATIC_TEXT,
}


## True when [param control] lies outside the open dialog, so it should be left out.
static func is_hidden(control: Control) -> bool:
	if modal_root == null or not is_instance_valid(modal_root):
		return false
	return control != modal_root and not modal_root.is_ancestor_of(control)


## Asks every control for a new description, as when a dialog opens or closes and the window
## behind it is hidden or shown.
static func refresh_all(tree: SceneTree) -> void:
	if tree != null and DisplayServer.accessibility_screen_reader_active() > 0:
		tree.root.propagate_call("queue_accessibility_update")


## Asks the engine for a new description of [param control] when something about it changed, which
## is only worth doing while a screen reader is listening.
static func changed(control: Control) -> void:
	if control.is_inside_tree() and DisplayServer.accessibility_screen_reader_active() > 0:
		control.queue_accessibility_update()


## Passes [param info] to the engine as the description of [param control].
static func apply(control: Control, info: Dictionary) -> void:
	var element := control.get_accessibility_element()
	if not element.is_valid():
		return
	release(control)
	_write(element, info, control)
	var made: Array[RID] = []
	for row in info.get("children", []):
		var sub := DisplayServer.accessibility_create_sub_element(element, ROLES[row["role"]], -1)
		_write(sub, row, control)
		if row.has("rect"):
			DisplayServer.accessibility_update_set_bounds(sub, row["rect"])
		made.append(sub)
	control.set_meta("xp_accessibility_rows", made)


## Frees the rows made for the last description.
static func release(control: Control) -> void:
	if not control.has_meta("xp_accessibility_rows"):
		return
	for sub: RID in control.get_meta("xp_accessibility_rows"):
		if DisplayServer.accessibility_has_element(sub):
			DisplayServer.accessibility_free_element(sub)
	control.remove_meta("xp_accessibility_rows")


static func _write(element: RID, info: Dictionary, control: Control) -> void:
	DisplayServer.accessibility_update_set_role(element, ROLES[info["role"]])
	DisplayServer.accessibility_update_set_name(element, info.get("name", ""))
	if info.has("value"):
		DisplayServer.accessibility_update_set_value(element, info["value"])
	if info.has("checked"):
		DisplayServer.accessibility_update_set_checked(element, info["checked"])
	if info.has("selected"):
		DisplayServer.accessibility_update_set_list_item_selected(element, info["selected"])
	if info.has("shortcut") and not String(info["shortcut"]).is_empty():
		DisplayServer.accessibility_update_set_shortcut(element, info["shortcut"])
	if info.get("expanded", false):
		DisplayServer.accessibility_update_set_state_description(element, "expanded")
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_DISABLED, info.get("disabled", false))
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_MODAL, info.get("modal", false))
	DisplayServer.accessibility_update_set_flag(element, DisplayServer.FLAG_HIDDEN, is_hidden(control))
	if info.get("alert", false):
		DisplayServer.accessibility_update_set_live(element, DisplayServer.LIVE_ASSERTIVE)
	if info.has("action"):
		DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK, info["action"])
