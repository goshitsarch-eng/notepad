class_name XpWindowFrame
extends RefCounted
## The 4px Luna window frame, painted under the content so that opaque content such as the
## caption covers it where XP does.


## Paints the frame bands on [param canvas] over a rectangle of [param size]. With a
## [param background], that colour is painted first, for a window whose body is not opaque,
## such as a dialog.
static func draw(canvas: CanvasItem, size: Vector2, active: bool, background: Color = Color(0, 0, 0, 0)) -> void:
	if background.a > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, size), background)
	var left: Array[Color] = XpColors.frame_left() if active else XpColors.frame_inactive()
	var right_bottom: Array[Color] = XpColors.frame_right_bottom() if active else XpColors.frame_inactive()
	# Inner bands first, so the outer ones paint over corners the way XP's shadows do.
	for depth in range(int(XpMetrics.FRAME) - 1, -1, -1):
		canvas.draw_rect(Rect2(0, size.y - 1 - depth, size.x, 1), right_bottom[depth])
		canvas.draw_rect(Rect2(size.x - 1 - depth, 0, 1, size.y), right_bottom[depth])
		canvas.draw_rect(Rect2(depth, 0, 1, size.y), left[depth])
