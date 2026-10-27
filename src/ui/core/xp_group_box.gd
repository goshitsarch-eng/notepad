class_name XpGroupBox
extends Container
## A titled frame round a group of controls, as XP's group boxes are drawn. The legend is
## centred on the top border, so the box has room above it, and the content starts below it.

var legend: String = ""
var _content: Control


func _init(group_legend: String = "", content: Control = null) -> void:
	legend = group_legend
	if content != null:
		_content = content
		add_child(content)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func xp_theme_changed() -> void:
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var inner := _content.get_combined_minimum_size() if _content != null else Vector2.ZERO
	return Vector2(inner.x + 16.0, inner.y + 8.0 + 14.0 + 8.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN and _content != null:
		fit_child_in_rect(_content, Rect2(8, 8 + 14, size.x - 16, size.y - 8 - 14 - 8))


func _draw() -> void:
	XpDraw.border(self, Rect2(0, 8, size.x, size.y - 8), XpColors.rule_dark())
	var width := XpDraw.text_width(legend)
	var height := XpFonts.ui().get_height(XpFonts.ui_size())
	draw_rect(Rect2(6, 8 - height / 2.0, width + 4, height), XpColors.face())
	XpDraw.text(self, Vector2(8, 8.0 - height / 2.0), legend, XpColors.text())
