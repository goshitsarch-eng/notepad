class_name XpGradients
extends RefCounted
## Luna gradients for title bars, buttons, check boxes and scroll bar thumbs. A gradient is
## a list of stops (0 to 1) and a list of colours; [method sample] reads it, and
## [method fill_vertical] and [method fill_horizontal] paint it in one-pixel strips.


static func title_active() -> Array:
	var stops := PackedFloat32Array([0.0, 0.08, 0.40, 0.88, 0.93, 0.95, 0.96, 1.0])
	if XpColors.dark:
		return [stops, _colors([
			0xFF3D6EA8, 0xFF2A5C96, 0xFF244F85, 0xFF1F4679,
			0xFF1D4272, 0xFF1A3B66, 0xFF16345A, 0xFF16345A])]
	return [stops, _colors([
		0xFF0997FF, 0xFF0053EE, 0xFF0050EE, 0xFF0066FF,
		0xFF0066FF, 0xFF005BFF, 0xFF003DD7, 0xFF003DD7])]


static func title_inactive() -> Array:
	var stops := PackedFloat32Array([0.0, 0.08, 0.88, 0.93, 0.96, 1.0])
	if XpColors.dark:
		return [stops, _colors([
			0xFF4B5563, 0xFF3A4250, 0xFF3A4250, 0xFF424B5A, 0xFF3A4250, 0xFF3A4250])]
	return [stops, _colors([
		0xFFA6B9E6, 0xFF7A96DF, 0xFF7A96DF, 0xFF8CA5E4, 0xFF7A96DF, 0xFF7A96DF])]


static func button_face() -> Array:
	var stops := PackedFloat32Array([0.0, 0.86, 1.0])
	if XpColors.dark:
		return [stops, _colors([0xFF4A4A4F, 0xFF3A3A3E, 0xFF303034])]
	return [stops, _colors([0xFFFFFFFF, 0xFFECEBE5, 0xFFD8D0C4])]


static func button_pressed() -> Array:
	var stops := PackedFloat32Array([0.0, 0.08, 0.94, 1.0])
	if XpColors.dark:
		return [stops, _colors([0xFF2A2A2D, 0xFF303034, 0xFF323236, 0xFF3A3A3E])]
	return [stops, _colors([0xFFCDCAC3, 0xFFE3E3DB, 0xFFE5E5DE, 0xFFF2F2F1])]


## Corner to corner, so it is read along the diagonal.
static func check_box() -> Array:
	var stops := PackedFloat32Array([0.0, 1.0])
	if XpColors.dark:
		return [stops, _colors([0xFF3C3C40, 0xFF2E2E31])]
	return [stops, _colors([0xFFFFFFFF, 0xFFF0F0EA])]


## Read across the thumb, left to right.
static func scroll_thumb() -> Array:
	var stops := PackedFloat32Array([0.0, 1.0])
	if XpColors.dark:
		return [stops, _colors([0xFF5B5B60, 0xFF46464B])]
	return [stops, _colors([0xFFF6F9FF, 0xFFC1D2EE])]


static func _colors(values: Array[int]) -> Array[Color]:
	var colors: Array[Color] = []
	for value in values:
		colors.append(XpColors.argb(value))
	return colors


## The colour of [param gradient] at [param t], from 0 to 1.
static func sample(gradient: Array, t: float) -> Color:
	var stops: PackedFloat32Array = gradient[0]
	var colors: Array[Color] = gradient[1]
	if t <= stops[0]:
		return colors[0]
	for index in range(1, stops.size()):
		if t <= stops[index]:
			var span := stops[index] - stops[index - 1]
			var weight := 0.0 if span <= 0.0 else (t - stops[index - 1]) / span
			return colors[index - 1].lerp(colors[index], weight)
	return colors[colors.size() - 1]


## Paints [param gradient] in rows over [param rect], top to bottom.
static func fill_vertical(canvas: CanvasItem, rect: Rect2, gradient: Array) -> void:
	var rows := maxi(1, roundi(rect.size.y))
	for row in range(rows):
		var t := (float(row) + 0.5) / float(rows)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + row, rect.size.x, 1.0), sample(gradient, t))


## Paints [param gradient] in columns over [param rect], left to right.
static func fill_horizontal(canvas: CanvasItem, rect: Rect2, gradient: Array) -> void:
	var columns := maxi(1, roundi(rect.size.x))
	for column in range(columns):
		var t := (float(column) + 0.5) / float(columns)
		canvas.draw_rect(Rect2(rect.position.x + column, rect.position.y, 1.0, rect.size.y), sample(gradient, t))
