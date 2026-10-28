class_name XpEditor
extends Control
## The XP edit control's frame: a white, bordered text area. The text, its scroll bars and
## the wrapping come from the engine's TextEdit, which shows a vertical scroll bar when the
## text overflows that way and a horizontal one when word wrap is off. This adds the border
## and the face-coloured box in the corner where the two bars meet.

var text_edit: XpTextEdit

var _corner := Control.new()
## The scroll bar of a large document, which stands in for the control's own: that one reaches
## only the window.
var _document_bar := VScrollBar.new()
var _updating_bar := false


func _init(control: XpTextEdit = null) -> void:
	text_edit = control
	clip_contents = true
	if text_edit != null:
		text_edit.focus_mode = Control.FOCUS_ALL
		Ui.anchor(text_edit, Vector4(0, 0, 1, 1), Vector4(1, 1, -1, -1))
		add_child(text_edit)
		var vertical := text_edit.get_v_scroll_bar()
		var horizontal := text_edit.get_h_scroll_bar()
		vertical.visibility_changed.connect(_update_corner)
		horizontal.visibility_changed.connect(_update_corner)
		text_edit.windowed_changed.connect(_on_windowed_changed)
		text_edit.document_changed.connect(_sync_document_bar)
		_document_bar.theme = XpTheme.shared()
		_document_bar.step = 1.0
		_document_bar.visible = false
		Ui.anchor(_document_bar, Vector4(1, 0, 1, 1), Vector4(-1.0 - XpMetrics.SCROLLBAR, 1, -1, -1))
		_document_bar.value_changed.connect(_on_document_bar_changed)
		add_child(_document_bar)
		_on_windowed_changed(text_edit.is_windowed())
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.visible = false
	Ui.anchor(_corner, Vector4(1, 1, 1, 1), Vector4(-18, -18, -1, -1))
	_corner.draw.connect(func() -> void: _corner.draw_rect(Rect2(Vector2.ZERO, _corner.size), XpColors.face()))
	add_child(_corner)


func xp_theme_changed() -> void:
	queue_redraw()
	_corner.queue_redraw()


## The frame is an unnamed group, and the engine's text control inside it carries the name
## "Text editor". While a dialog is open the whole frame is hidden, and the text with it.
func accessibility_info() -> Dictionary:
	return {"role": "group", "name": ""}


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		XpAccessibility.apply(self, accessibility_info())
	elif what == NOTIFICATION_ACCESSIBILITY_INVALIDATE:
		XpAccessibility.release(self)


func _update_corner() -> void:
	if text_edit == null:
		return
	var across := text_edit.get_h_scroll_bar().visible
	_corner.visible = text_edit.get_v_scroll_bar().visible and across
	# The bar of a large document stops above the horizontal bar, as the control's own would.
	_document_bar.offset_bottom = -1.0 - (XpMetrics.SCROLLBAR if across else 0.0)


## A large document hides the control's own vertical bar, which reaches only its window, and
## shows one for the whole document.
func _on_windowed_changed(active: bool) -> void:
	var own := text_edit.get_v_scroll_bar()
	own.modulate = Color(1, 1, 1, 0.0 if active else 1.0)
	own.mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
	_document_bar.visible = active
	_update_corner()
	_sync_document_bar()


func _sync_document_bar() -> void:
	var document := text_edit.large_document()
	if document == null:
		return
	var state := document.scroll_state()
	_updating_bar = true
	_document_bar.max_value = state["max"]
	_document_bar.page = state["page"]
	_document_bar.set_value_no_signal(state["value"])
	_updating_bar = false


func _on_document_bar_changed(value: float) -> void:
	if _updating_bar:
		return
	var document := text_edit.large_document()
	if document != null:
		document.scroll_to(int(value))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), XpColors.paper())
	XpDraw.border(self, Rect2(Vector2.ZERO, size), XpColors.edit_border())
