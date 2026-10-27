class_name NotepadScreen
extends Control
## The Notepad window: caption, menu bar, editor and status bar, with the menus and dialogs
## layered on top. It renders the view model and passes input to it.

const NO_MENU := NotepadViewModel.NO_MENU
const SYSTEM_MENU := NotepadViewModel.SYSTEM_MENU

## Where the title bar's icon, which opens the window menu, ends.
const _ICON_RIGHT := 28.0
const _BAR_TOP := XpMetrics.CAPTION_HEIGHT
const _POPUP_TOP := XpMetrics.CAPTION_HEIGHT + XpMetrics.MENU_BAR_HEIGHT

var vm: NotepadViewModel
var caption: XpCaption
var menu_bar: XpMenuBar
var editor: XpEditor
var status_bar: XpStatusBar
var popup: XpMenuPopup
var find_dialog: FindDialog
var modal_host: ModalDialogHost

var _highlight := -1
var _alt_held := false
var _alt_used := false
var _menu_was := NO_MENU
var _modal_was := false
var _find_was := false
var _dark_was := false
var _edges: Array[Control] = []


func _init(view_model: NotepadViewModel) -> void:
	vm = view_model
	name = "NotepadScreen"
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	caption = XpCaption.new()
	caption.drag_started.connect(vm.start_dragging)
	caption.toggle_maximize_requested.connect(vm.toggle_maximize)
	caption.minimize_requested.connect(vm.minimize)
	caption.close_requested.connect(func() -> void: _run(vm.request_exit))
	caption.window_menu_requested.connect(func() -> void: _run(_toggle_window_menu.bind(true)))
	Ui.anchor(caption, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, XpMetrics.CAPTION_HEIGHT))
	add_child(caption)

	menu_bar = XpMenuBar.new()
	menu_bar.pressed.connect(_on_menu_pressed)
	menu_bar.hovered.connect(_on_menu_hovered)
	Ui.anchor(menu_bar, Vector4(0, 0, 1, 0), Vector4(
		XpMetrics.FRAME, _BAR_TOP, -XpMetrics.FRAME, _POPUP_TOP))
	add_child(menu_bar)

	editor = XpEditor.new(vm.text)
	# A single row of paper colour lies between the menu bar and the edit control.
	Ui.anchor(editor, Vector4(0, 0, 1, 1), Vector4(
		XpMetrics.FRAME, _POPUP_TOP + 1.0, -XpMetrics.FRAME, -XpMetrics.FRAME))
	add_child(editor)

	status_bar = XpStatusBar.new()
	status_bar.resize_requested.connect(func() -> void: vm.start_resizing(WindowService.Direction.BOTTOM_RIGHT))
	Ui.anchor(status_bar, Vector4(0, 1, 1, 1), Vector4(
		XpMetrics.FRAME, -XpMetrics.FRAME - XpMetrics.STATUS_BAR_HEIGHT, -XpMetrics.FRAME, -XpMetrics.FRAME))
	add_child(status_bar)

	_add_resize_edges()
	vm.changed.connect(_on_view_model_changed)
	_dark_was = XpColors.dark
	_refresh()


func _ready() -> void:
	resized.connect(_on_resized)
	_layout()
	if vm.modal() == null:
		vm.text.grab_focus()


func _exit_tree() -> void:
	if vm != null and vm.changed.is_connected(_on_view_model_changed):
		vm.changed.disconnect(_on_view_model_changed)


func menus() -> Array[XpMenu]:
	return NotepadMenus.build(vm)


## The items of menu [param index]: one of the menu bar, or the window menu.
func items_of(index: int) -> Array[XpMenuItem]:
	if index == SYSTEM_MENU:
		return NotepadMenus.build_system_menu(vm)
	return menus()[index].items


# ---- Layout ----
# Most of the layout is anchors, which the engine keeps right. What follows is the part that
# depends on the view model: the status bar, which takes room from the editor, and the layers
# that are placed by hand.

func _on_resized() -> void:
	if find_dialog != null:
		find_dialog.place(size)


func _layout() -> void:
	var status_visible := vm.status_bar_visible()
	status_bar.visible = status_visible
	var status_height := XpMetrics.STATUS_BAR_HEIGHT if status_visible else 0.0
	editor.offset_bottom = -XpMetrics.FRAME - status_height
	_layout_popup()
	if find_dialog != null:
		find_dialog.place(size)


func _draw() -> void:
	XpWindowFrame.draw(self, size, vm.is_active())
	# The paper under the editor, including the row above it.
	draw_rect(Rect2(XpMetrics.FRAME, _POPUP_TOP, size.x - 2.0 * XpMetrics.FRAME, 1.0), XpColors.paper())


func _add_resize_edges() -> void:
	# The frame bands and corners resize the window from every side, as XP's frame does. The
	# corners come last so they take the hits they overlap.
	var specs: Array = [
		[WindowService.Direction.LEFT, Control.CURSOR_HSIZE],
		[WindowService.Direction.RIGHT, Control.CURSOR_HSIZE],
		[WindowService.Direction.TOP, Control.CURSOR_VSIZE],
		[WindowService.Direction.BOTTOM, Control.CURSOR_VSIZE],
		[WindowService.Direction.TOP_LEFT, Control.CURSOR_FDIAGSIZE],
		[WindowService.Direction.TOP_RIGHT, Control.CURSOR_BDIAGSIZE],
		[WindowService.Direction.BOTTOM_LEFT, Control.CURSOR_BDIAGSIZE],
		[WindowService.Direction.BOTTOM_RIGHT, Control.CURSOR_FDIAGSIZE],
	]
	var frame := XpMetrics.FRAME
	var top := XpMetrics.CAPTION_HEIGHT
	var placements: Array = [
		[Vector4(0, 0, 0, 1), Vector4(0, top, frame, -frame)],
		[Vector4(1, 0, 1, 1), Vector4(-frame, top, 0, -frame)],
		[Vector4(0, 0, 1, 0), Vector4(0, 0, 0, frame)],
		[Vector4(0, 1, 1, 1), Vector4(0, -frame, 0, 0)],
		[Vector4(0, 0, 0, 0), Vector4(0, 0, frame, frame)],
		[Vector4(1, 0, 1, 0), Vector4(-frame, 0, 0, frame)],
		[Vector4(0, 1, 0, 1), Vector4(0, -frame, frame, 0)],
		[Vector4(1, 1, 1, 1), Vector4(-frame, -frame, 0, 0)],
	]
	for index in range(specs.size()):
		var spec: Array = specs[index]
		var edge := Control.new()
		Ui.anchor(edge, placements[index][0], placements[index][1])
		edge.mouse_default_cursor_shape = spec[1]
		edge.mouse_filter = Control.MOUSE_FILTER_STOP
		edge.set_meta("direction", spec[0])
		edge.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				vm.start_resizing(spec[0])
				edge.accept_event())
		add_child(edge)
		_edges.append(edge)


# ---- Following the view model ----

func _on_view_model_changed() -> void:
	_refresh()
	_keep_focus_where_xp_puts_it()


func _refresh() -> void:
	if XpColors.dark != _dark_was:
		_dark_was = XpColors.dark
		propagate_call("xp_theme_changed")
		queue_redraw()
	caption.title = vm.window_title()
	caption.active = vm.is_active()
	caption.maximized = vm.is_maximized()
	menu_bar.set_menus(menus())
	menu_bar.open_index = vm.open_menu() if vm.open_menu() >= 0 else -1
	menu_bar.show_mnemonics = vm.menu_cue()
	status_bar.text = vm.status_text()
	_sync_find_dialog()
	_sync_modal_host()
	_layout()
	_sync_popup()
	_arrange_layers()
	queue_redraw()


## Menus lie over the text, the Find box over the menus, and a dialog over everything.
func _arrange_layers() -> void:
	for layer in [popup, find_dialog, modal_host]:
		if layer != null and is_instance_valid(layer):
			move_child(layer, get_child_count() - 1)


func _sync_find_dialog() -> void:
	var state: Variant = vm.find_state()
	if state == null:
		if find_dialog != null:
			find_dialog.queue_free()
			find_dialog = null
		return
	# A different kind of dialog, Find or Replace, is a new one.
	if find_dialog != null and find_dialog.replace_mode != state.replace:
		find_dialog.queue_free()
		find_dialog = null
	if find_dialog == null:
		find_dialog = FindDialog.new(vm, state.replace)
		add_child(find_dialog)
		move_child(find_dialog, get_child_count() - 1)
		find_dialog.place(size)
		find_dialog.focus_target().call_deferred("grab_focus")


func _sync_modal_host() -> void:
	var request: Variant = vm.modal()
	if request == null:
		if modal_host != null:
			modal_host.queue_free()
			modal_host = null
		return
	if modal_host != null and modal_host.request == request:
		return
	if modal_host != null:
		modal_host.queue_free()
	modal_host = ModalDialogHost.new(request, vm)
	add_child(modal_host)


## Keeps keyboard focus where XP puts it: on the menu while one is open, on a dialog while one
## is open, and back in the text when either closes.
func _keep_focus_where_xp_puts_it() -> void:
	var menu := vm.open_menu()
	if menu != _menu_was:
		_menu_was = menu
		if menu == NO_MENU and vm.modal() == null:
			_restore_focus()
	var modal := vm.modal() != null
	var find := vm.find_state() != null
	var closed := (_modal_was and not modal) or (_find_was and not find)
	# The text cannot take focus while a dialog is over it.
	vm.text.focus_mode = Control.FOCUS_NONE if modal else Control.FOCUS_ALL
	if modal and not _modal_was and vm.text.has_focus():
		vm.text.release_focus()
	if closed and not modal and menu == NO_MENU:
		_restore_focus()
	_modal_was = modal
	_find_was = find


## Focus goes back to the Find box while Find is open, and to the editor otherwise. While Find
## is open, typing must not fall through to the document.
func _restore_focus() -> void:
	if vm.find_state() != null:
		vm.focus_find()
	else:
		vm.text.call_deferred("grab_focus")


# ---- Menus ----

func _first_enabled(items: Array[XpMenuItem]) -> int:
	for index in range(items.size()):
		if not items[index].is_separator and items[index].enabled:
			return index
	return -1


func _open_menu_from_keyboard(index: int) -> void:
	_highlight = _first_enabled(items_of(index))
	vm.open_menu_at(index)
	vm.refresh_clipboard()


## Opens the window menu, or closes it when it is open already.
func _toggle_window_menu(by_click: bool) -> void:
	if vm.open_menu() == SYSTEM_MENU:
		_close_menu()
		return
	if by_click:
		_highlight = -1
		vm.open_menu_at(SYSTEM_MENU, true)
	else:
		_open_menu_from_keyboard(SYSTEM_MENU)


func _close_menu() -> void:
	_highlight = -1
	vm.close_menu()


func _activate(item: XpMenuItem) -> void:
	_close_menu()
	if item.enabled and item.on_selected.is_valid():
		item.on_selected.call()


func _move_highlight(items: Array[XpMenuItem], step: int) -> void:
	if items.is_empty():
		return
	var index := _highlight if _highlight >= 0 else (-1 if step > 0 else items.size())
	for _attempt in range(items.size()):
		index = (index + step + items.size()) % items.size()
		if not items[index].is_separator and items[index].enabled:
			_highlight = index
			_sync_popup()
			return


func _on_menu_pressed(index: int) -> void:
	if vm.open_menu() == index and vm.menu_opened_by_click():
		_close_menu()
		return
	_highlight = -1
	vm.open_menu_at(index, true)
	vm.refresh_clipboard()


func _on_menu_hovered(index: int) -> void:
	var open := vm.open_menu()
	if open == NO_MENU or open == index:
		return
	_highlight = -1
	vm.open_menu_at(index)
	vm.refresh_clipboard()


## The left edge of the popup under menu [param index], in window coordinates.
func _menu_left(index: int) -> float:
	var left := XpMetrics.FRAME
	if index == SYSTEM_MENU:
		return left
	var all := menus()
	for position in range(index):
		left += XpMenuLayout.bar_label_width(all[position].label)
	return left


func _menu_top(index: int) -> float:
	return _BAR_TOP if index == SYSTEM_MENU else _POPUP_TOP


func _sync_popup() -> void:
	var index := vm.open_menu()
	if index == NO_MENU:
		if popup != null:
			popup.queue_free()
			popup = null
		return
	var items := items_of(index)
	if popup == null:
		popup = XpMenuPopup.new(items)
		popup.highlighted.connect(func(item: int) -> void:
			_highlight = item
			popup.highlight = item)
		popup.activated.connect(func(item: int) -> void: _activate(items_of(vm.open_menu())[item]))
		add_child(popup)
	else:
		popup.set_items(items)
	popup.highlight = _highlight
	popup.show_mnemonics = vm.menu_cue()
	_layout_popup()


func _layout_popup() -> void:
	if popup == null or vm.open_menu() == NO_MENU:
		return
	popup.position = Vector2(_menu_left(vm.open_menu()), _menu_top(vm.open_menu()))


# ---- Keyboard ----

## True while the document or the window itself has focus, rather than a text box in a
## dialog. Editing keys are left to that text box.
func document_has_focus() -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner == null or owner == vm.text


func _run(action: Callable) -> void:
	if vm.modal() != null:
		return
	action.call()


func _find_again() -> void:
	if vm.last_search().query.is_empty():
		vm.show_find(false)
	else:
		vm.repeat_find()


## Keys while a menu is open go to the menu. Alt and letters open menus as in XP. Escape
## cancels a dialog. Runs before the controls see the key.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_pointer_down(event)
		return
	if not (event is InputEventKey):
		return
	XpDraw.keyboard_active = true
	var key := event as InputEventKey
	if vm.modal() != null:
		if key.pressed and key.keycode == KEY_ESCAPE and modal_host != null \
				and get_tree().get_first_node_in_group("xp_open_list") == null:
			modal_host.cancel()
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ALT:
		if key.pressed and not key.echo:
			_alt_held = true
			# Ctrl with Alt is AltGr, whose key-up must not light up the menu underlines.
			_alt_used = key.ctrl_pressed
		elif not key.pressed:
			_alt_held = false
			if not _alt_used:
				vm.set_menu_cue(true)
		return
	if not key.pressed:
		return
	# The Alt key-up never arrives when focus leaves the window while Alt is down, such as
	# Alt+Tab. The keyboard's own state is the truth, so a stale flag is dropped here rather
	# than turning later plain letters into menu accelerators.
	if _alt_held and not key.alt_pressed:
		_alt_held = false
	if _alt_held:
		_alt_used = true

	# Alt+Space is the window menu, from the text or from a menu that is open.
	if _alt_held and key.keycode == KEY_SPACE and not key.ctrl_pressed:
		vm.set_menu_cue(true)
		_toggle_window_menu(false)
		get_viewport().set_input_as_handled()
		return

	var open_index := vm.open_menu()
	if open_index != NO_MENU:
		_handle_menu_key(key, open_index)
		get_viewport().set_input_as_handled()
		return

	# Escape closes the Find dialog while focus is inside it.
	if key.keycode == KEY_ESCAPE and find_dialog != null and _focus_in(find_dialog):
		vm.close_find()
		get_viewport().set_input_as_handled()
		return

	# Ctrl+Alt is how Windows reports AltGr, which types characters on many keyboard layouts.
	# It must reach the text instead of opening a menu.
	if _alt_held and not key.ctrl_pressed:
		var letter := _letter_of(key)
		var index := _menu_index_for(letter)
		if index >= 0:
			vm.set_menu_cue(true)
			_open_menu_from_keyboard(index)
			get_viewport().set_input_as_handled()


func _focus_in(node: Node) -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	return owner != null and node.is_ancestor_of(owner)


## Shortcuts that no control took for itself. They do nothing while a dialog is open.
func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if vm.modal() != null:
		return
	var key := event as InputEventKey
	var control := key.ctrl_pressed or key.meta_pressed
	var handled := true
	if control and not key.alt_pressed and not key.shift_pressed:
		match key.keycode:
			KEY_N:
				vm.new_document()
			KEY_O:
				vm.open_document()
			KEY_S:
				vm.save()
			KEY_P:
				vm.print_document()
			KEY_F:
				vm.show_find(false)
			KEY_H:
				vm.show_find(true)
			KEY_G:
				if not vm.word_wrap():
					vm.show_go_to()
			_:
				handled = false
	elif not control and not key.alt_pressed and not key.shift_pressed:
		match key.keycode:
			KEY_F1:
				vm.show_help()
			KEY_F3:
				_find_again()
			KEY_F5:
				if document_has_focus():
					vm.insert_time_date()
				else:
					handled = false
			_:
				handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


static func _letter_of(key: InputEventKey) -> String:
	if key.keycode >= KEY_A and key.keycode <= KEY_Z:
		return char(key.keycode).to_lower()
	return ""


func _menu_index_for(letter: String) -> int:
	if letter.is_empty():
		return -1
	var all := menus()
	for index in range(all.size()):
		if MenuLabel.parse(all[index].label).mnemonic() == letter:
			return index
	return -1


func _handle_menu_key(key: InputEventKey, open_index: int) -> void:
	var all := menus()
	var items := items_of(open_index)
	match key.keycode:
		KEY_ESCAPE:
			_close_menu()
		KEY_DOWN:
			_move_highlight(items, 1)
		KEY_UP:
			_move_highlight(items, -1)
		KEY_RIGHT:
			# From the window menu, Right goes to the first menu of the bar.
			_open_menu_from_keyboard(0 if open_index == SYSTEM_MENU else (open_index + 1) % all.size())
		KEY_LEFT:
			_open_menu_from_keyboard(
				all.size() - 1 if open_index == SYSTEM_MENU else (open_index - 1 + all.size()) % all.size())
		KEY_ENTER, KEY_KP_ENTER:
			if _highlight >= 0:
				_activate(items[_highlight])
		_:
			var letter := _letter_of(key)
			if letter.is_empty():
				return
			for index in range(items.size()):
				var item := items[index]
				if not item.is_separator and item.enabled and MenuLabel.parse(item.label).mnemonic() == letter:
					_activate(item)
					return
			var menu_index := _menu_index_for(letter)
			if menu_index >= 0:
				_open_menu_from_keyboard(menu_index)


## Clicks outside an open menu close it. Clicks on the menu bar go to its labels.
func _on_pointer_down(event: InputEventMouseButton) -> void:
	XpDraw.keyboard_active = false
	if vm.menu_cue():
		vm.set_menu_cue(false)
	var open_index := vm.open_menu()
	if open_index == NO_MENU:
		return
	var position := event.position
	# The title bar and the menu bar belong to their own handlers, which open, switch and close
	# menus themselves.
	if position.y >= _BAR_TOP and position.y < _POPUP_TOP:
		return
	# The title bar opens and closes the window menu itself, from its icon and from a right
	# click. That includes a right click that has just opened it.
	if open_index == SYSTEM_MENU and position.y < _BAR_TOP \
			and (position.x < _ICON_RIGHT or event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var items := items_of(open_index)
	var rect := Rect2(
		_menu_left(open_index), _menu_top(open_index),
		XpMenuLayout.popup_width(items), XpMenuLayout.popup_height(items))
	if rect.has_point(position):
		return
	_close_menu()
