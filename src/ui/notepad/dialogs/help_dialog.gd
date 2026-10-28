class_name HelpDialog
extends XpDialogWindow
## Help > Help Topics: a scrollable table of shortcuts, then OK.

## Every shortcut listed here is handled by the app. Ctrl+G works only while Word Wrap is off.
const SHORTCUTS: Array = [
	["Ctrl+N", "New document"],
	["Ctrl+O", "Open a file"],
	["Ctrl+S", "Save"],
	["Ctrl+P", "Print"],
	["Ctrl+Z  or  Alt+Backspace", "Undo"],
	["Ctrl+X", "Cut"],
	["Ctrl+C  or  Ctrl+Insert", "Copy"],
	["Ctrl+V  or  Shift+Insert", "Paste"],
	["Del", "Delete the selection"],
	["Ctrl+A", "Select all"],
	["Ctrl+F", "Find"],
	["F3", "Find next"],
	["Ctrl+H", "Replace"],
	["Ctrl+G", "Go To line (Word Wrap off)"],
	["F5", "Insert time and date"],
	["F1", "Help topics"],
	["Alt + letter", "Open a menu, e.g. Alt+F for File"],
	["Alt+Space", "Open the window menu: minimize, maximize, close"],
	["Esc", "Close a menu or dialog"],
	["Tab", "Insert a tab character"],
	["Enter", "Press the highlighted button in a dialog"],
]

var request: DialogRequests.HelpRequest
var table: _ShortcutTable
var _ok: XpButton


func _init(help_request: DialogRequests.HelpRequest) -> void:
	super("Notepad Help", 400.0)
	request = help_request
	close_requested.connect(cancel)
	table = _ShortcutTable.new()
	_ok = XpButton.new("OK", true)
	_ok.pressed.connect(cancel)
	set_content(Ui.vbox([
		Ui.label("Keyboard shortcuts", true), Ui.spacer(0, 6), table, Ui.spacer(0, 12),
		Ui.centered(_ok)]))


func cancel() -> void:
	request.complete(true)


func focus_target() -> Control:
	return _ok


## The table of shortcuts: two columns of 18px rows in a bordered box with a scroll bar.
class _ShortcutTable extends Control:
	const _ROW_HEIGHT := 18
	const _KEYS_WIDTH := 170.0

	var _scroll := VScrollBar.new()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 240)
		clip_contents = true
		_scroll.theme = XpTheme.shared()
		_scroll.step = 1.0
		_scroll.value_changed.connect(func(_value: float) -> void: queue_redraw())
		Ui.anchor(_scroll, Vector4(1, 0, 1, 1), Vector4(-1.0 - XpMetrics.SCROLLBAR, 1, -1, -1))
		add_child(_scroll)

	func xp_theme_changed() -> void:
		queue_redraw()

	func _visible_rows() -> int:
		return maxi(1, int(floor((size.y - 2.0) / _ROW_HEIGHT)))

	## Fits the scroll bar to the rows and to the size of the table, as it is drawn.
	func _sync_scroll() -> void:
		_scroll.visible = HelpDialog.SHORTCUTS.size() * _ROW_HEIGHT > size.y - 4.0
		_scroll.max_value = HelpDialog.SHORTCUTS.size()
		_scroll.page = _visible_rows()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll.value -= 3
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll.value += 3
				accept_event()

	func _draw() -> void:
		_sync_scroll()
		draw_rect(Rect2(Vector2.ZERO, size), XpColors.paper())
		XpDraw.border(self, Rect2(Vector2.ZERO, size), XpColors.edit_border())
		var top := int(_scroll.value)
		for offset in range(_visible_rows() + 1):
			var index := top + offset
			if index >= HelpDialog.SHORTCUTS.size():
				break
			var y := 1.0 + offset * _ROW_HEIGHT
			var row: Array = HelpDialog.SHORTCUTS[index]
			XpDraw.text_in(self, Rect2(5, y, _KEYS_WIDTH, _ROW_HEIGHT), row[0], XpColors.text())
			XpDraw.text_in(self, Rect2(5 + _KEYS_WIDTH, y, size.x - _KEYS_WIDTH - 24, _ROW_HEIGHT),
				row[1], XpColors.text())
