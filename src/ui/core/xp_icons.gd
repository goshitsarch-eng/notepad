class_name XpIcons
extends RefCounted
## Icons drawn with canvas primitives. They evoke the XP shell icons without copying them.

enum MessageKind { INFORMATION, WARNING, ERROR }


## A notepad: a ruled page with a blue binding. Drawn on a 16 by 16 grid, scaled to
## [param size].
static func draw_notepad(canvas: CanvasItem, origin: Vector2, size: float) -> void:
	canvas.draw_set_transform(origin, 0.0, Vector2(size / 16.0, size / 16.0))
	canvas.draw_rect(Rect2(2, 1, 12, 14), Color.WHITE)
	canvas.draw_rect(Rect2(2.5, 1.5, 11, 13), XpColors.argb(0xFF5A7DBF), false, 1.0)
	canvas.draw_rect(Rect2(2, 1, 12, 3), XpColors.argb(0xFF2B5FD1))
	for y in [7.0, 9.0, 11.0, 13.0]:
		canvas.draw_rect(Rect2(4, y, 8, 1), XpColors.argb(0xFF9DB6E4))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A yellow folder on a 16 by 16 grid.
static func draw_folder(canvas: CanvasItem, origin: Vector2, size: float = 16.0) -> void:
	canvas.draw_set_transform(origin, 0.0, Vector2(size / 16.0, size / 16.0))
	canvas.draw_rect(Rect2(1, 3, 6, 3), XpColors.argb(0xFFE2B94C))
	canvas.draw_rect(Rect2(1, 5, 14, 9), XpColors.argb(0xFFF7DA7A))
	canvas.draw_rect(Rect2(1.5, 5.5, 13, 8), XpColors.argb(0xFFC29A37), false, 1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A plain document page with a folded corner, on a 16 by 16 grid.
static func draw_document(canvas: CanvasItem, origin: Vector2, size: float = 16.0) -> void:
	canvas.draw_set_transform(origin, 0.0, Vector2(size / 16.0, size / 16.0))
	var page := PackedVector2Array([
		Vector2(3, 1), Vector2(10, 1), Vector2(13, 4), Vector2(13, 15), Vector2(3, 15)])
	canvas.draw_colored_polygon(page, Color.WHITE)
	var outline := page.duplicate()
	outline.append(page[0])
	canvas.draw_polyline(outline, XpColors.argb(0xFF7F9DB9), 1.0)
	for y in [7.0, 9.0, 11.0]:
		canvas.draw_rect(Rect2(5, y, 6, 1), XpColors.argb(0xFF9DB6E4))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The 32 by 32 icon at the left of a message box.
static func draw_message(canvas: CanvasItem, origin: Vector2, kind: int) -> void:
	canvas.draw_set_transform(origin, 0.0, Vector2.ONE)
	match kind:
		MessageKind.INFORMATION:
			canvas.draw_circle(Vector2(16, 16), 14.0, XpColors.argb(0xFF2A6BD6), true, -1.0, true)
			var font := XpFonts.ui_bold()
			var width := font.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			canvas.draw_string(font, Vector2(16.0 - width / 2.0, 16.0 + font.get_ascent(22) - font.get_height(22) / 2.0),
				"i", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		MessageKind.WARNING:
			var triangle := PackedVector2Array([Vector2(16, 2), Vector2(31, 29), Vector2(1, 29)])
			canvas.draw_colored_polygon(triangle, XpColors.argb(0xFFF2C12E))
			var outline := triangle.duplicate()
			outline.append(triangle[0])
			canvas.draw_polyline(outline, XpColors.argb(0xFF8A6A12), 1.0, true)
			canvas.draw_rect(Rect2(14.5, 10, 3, 11), XpColors.argb(0xFF1B1B1B))
			canvas.draw_rect(Rect2(14.5, 23, 3, 3), XpColors.argb(0xFF1B1B1B))
		MessageKind.ERROR:
			canvas.draw_circle(Vector2(16, 16), 14.0, XpColors.argb(0xFFD62F2F), true, -1.0, true)
			canvas.draw_line(Vector2(10, 10), Vector2(22, 22), Color.WHITE, 4.0, true)
			canvas.draw_line(Vector2(22, 10), Vector2(10, 22), Color.WHITE, 4.0, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The edge decoration at the bottom right of a window with a status bar, on a 13 by 13 grid.
static func draw_size_grip(canvas: CanvasItem, origin: Vector2) -> void:
	for offset in [0.0, 4.0, 8.0]:
		canvas.draw_line(origin + Vector2(12 - offset, 1), origin + Vector2(1, 12 - offset), XpColors.rule_dark(), 1.0)
		canvas.draw_line(origin + Vector2(13 - offset, 2), origin + Vector2(2, 13 - offset), XpColors.rule_light(), 1.0)
