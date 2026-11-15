class_name XpComboBox
extends Control
## A drop-down list in the Luna style. The list opens in a layer above the window, below the
## box, or above it when there is no room below, as XP's combo boxes do.

signal changed(index: int)

const _ROW_HEIGHT := 16

var labels: PackedStringArray = PackedStringArray()
var selected: int = 0:
	set(value):
		selected = value
		queue_redraw()
		XpAccessibility.changed(self)
## A box that is not enabled shows its value, greyed, and cannot be opened. XP draws a choice
## that has nothing to choose from this way.
var enabled: bool = true:
	set(value):
		enabled = value
		focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		queue_redraw()
		XpAccessibility.changed(self)
var accessible_name: String = ""

var _popup: Control


func _init(options: PackedStringArray = PackedStringArray(), box_width: float = 0.0) -> void:
	labels = options
	custom_minimum_size = Vector2(box_width, XpMetrics.FIELD_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func xp_theme_changed() -> void:
	queue_redraw()


func accessibility_info() -> Dictionary:
	var shown := labels[selected] if selected >= 0 and selected < labels.size() else ""
	var info := {"role": "button", "name": accessible_name, "value": shown, "disabled": not enabled,
		"expanded": is_open()}
	if enabled:
		info["action"] = func(_data: Variant) -> void: toggle()
	return info


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)


func is_open() -> bool:
	return _popup != null and is_instance_valid(_popup)


func close_list(restore_focus: bool = true) -> void:
	var was_open := is_open()
	var had_popup_focus := was_open and _popup.has_focus()
	if was_open:
		_popup.queue_free()
	_popup = null
	if was_open and restore_focus and enabled and is_inside_tree():
		var owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
		if had_popup_focus or owner == null or owner == _popup:
			grab_focus()


func _exit_tree() -> void:
	close_list(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if enabled:
			grab_focus()
			toggle()
		accept_event()
	elif event is InputEventKey and event.pressed and enabled:
		if (event.keycode == KEY_DOWN and event.alt_pressed) or event.keycode == KEY_F4 or event.keycode == KEY_SPACE:
			toggle()
			accept_event()
			return
		if labels.is_empty():
			return
		var target := selected
		match event.keycode:
			KEY_DOWN, KEY_RIGHT:
				target = mini(selected + 1, labels.size() - 1)
			KEY_UP, KEY_LEFT:
				target = maxi(selected - 1, 0)
			KEY_HOME:
				target = 0
			KEY_END:
				target = labels.size() - 1
			_:
				return
		if target != selected:
			selected = target
			changed.emit(target)
		accept_event()


## Opens the list, or closes it when it is open.
func toggle() -> void:
	if is_open():
		close_list()
		return
	if labels.is_empty():
		return
	var below := get_global_rect().end.y
	var room := get_viewport().get_visible_rect().size.y - below
	var list_height := labels.size() * _ROW_HEIGHT + 2.0
	_popup = _ComboPopup.new(self, room < list_height)
	get_tree().root.add_child(_popup)


func _choose(index: int) -> void:
	close_list()
	selected = index
	changed.emit(index)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, XpColors.paper() if enabled else XpColors.face())
	XpDraw.border(self, rect, XpColors.text() if (has_focus() and enabled) else XpColors.edit_border())
	var shown := labels[selected] if selected >= 0 and selected < labels.size() else (labels[0] if not labels.is_empty() else "")
	var focused := has_focus() and enabled and not is_open() and XpDraw.keyboard_active
	if focused:
		draw_rect(Rect2(2, 2, maxf(0.0, size.x - 20), maxf(0.0, size.y - 4)), XpColors.highlight())
	var color := XpColors.highlight_text() if focused else (XpColors.text() if enabled else XpColors.gray_text())
	XpDraw.text_in(self, Rect2(3, 0, size.x - 23, size.y), shown, color)
	var arrow_color := XpColors.text() if enabled else XpColors.gray_text()
	var arrow := PackedVector2Array([
		Vector2(size.x - 6 - 7, 8), Vector2(size.x - 6, 8), Vector2(size.x - 6 - 3.5, 12)])
	draw_colored_polygon(arrow, arrow_color)


## The open list: a catcher over the whole window, so a click anywhere else closes it, and the
## rows.
class _ComboPopup extends Control:
	var _combo: XpComboBox
	var _upward: bool
	var _highlighted: int = 0

	func _init(combo: XpComboBox, upward: bool) -> void:
		_combo = combo
		_upward = upward
		_highlighted = clampi(combo.selected, 0, maxi(0, combo.labels.size() - 1))
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		# The screen leaves Escape to an open list, so it closes the list and not the dialog.
		add_to_group("xp_open_list")
		grab_focus()

	func _list_rect() -> Rect2:
		var box := _combo.get_global_rect()
		var height := _combo.labels.size() * XpComboBox._ROW_HEIGHT + 2.0
		var top := box.position.y - height if _upward else box.end.y
		return Rect2(box.position.x, top, box.size.x, height)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var list := _list_rect()
			if list.has_point(event.position):
				var row := int((event.position.y - list.position.y - 1.0) / XpComboBox._ROW_HEIGHT)
				if row >= 0 and row < _combo.labels.size() and row != _highlighted:
					_highlighted = row
					queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var list := _list_rect()
			if list.has_point(event.position):
				var row := int((event.position.y - list.position.y - 1.0) / XpComboBox._ROW_HEIGHT)
				if row >= 0 and row < _combo.labels.size():
					_combo._choose(row)
			else:
				_combo.close_list()
			accept_event()
		elif event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_ESCAPE, KEY_F4:
					_combo.close_list()
					accept_event()
				KEY_UP:
					if event.alt_pressed:
						_combo.close_list()
					elif _combo.labels.size() > 0:
						_highlighted = maxi(_highlighted - 1, 0)
						queue_redraw()
					accept_event()
				KEY_DOWN:
					if _combo.labels.size() > 0:
						_highlighted = mini(_highlighted + 1, _combo.labels.size() - 1)
						queue_redraw()
					accept_event()
				KEY_HOME:
					if _combo.labels.size() > 0:
						_highlighted = 0
						queue_redraw()
					accept_event()
				KEY_END:
					if _combo.labels.size() > 0:
						_highlighted = _combo.labels.size() - 1
						queue_redraw()
					accept_event()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					if _highlighted >= 0 and _highlighted < _combo.labels.size():
						_combo._choose(_highlighted)
					else:
						_combo.close_list()
					accept_event()

	func _draw() -> void:
		var list := _list_rect()
		draw_rect(list, XpColors.paper())
		XpDraw.border(self, list, XpColors.edit_border())
		for index in range(_combo.labels.size()):
			var row := Rect2(list.position.x + 1, list.position.y + 1 + index * XpComboBox._ROW_HEIGHT,
				list.size.x - 2, XpComboBox._ROW_HEIGHT)
			var chosen := index == _highlighted
			if chosen:
				draw_rect(row, XpColors.highlight())
			XpDraw.text_in(self, Rect2(row.position.x + 3, row.position.y, row.size.x - 3, row.size.y),
				_combo.labels[index], XpColors.highlight_text() if chosen else XpColors.text())
