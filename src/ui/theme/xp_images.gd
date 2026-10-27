class_name XpImages
extends RefCounted
## Small bitmaps drawn in code for the parts of the Luna theme that the engine's own
## controls take as textures: the arrows and thumb of a scroll bar.


## A rounded rectangle of [param size] with a one-pixel [param border] and a gradient fill
## read across (left to right) or down it. Edges are anti-aliased.
static func rounded_gradient(
		size: Vector2i, radius: float, border: Color, gradient: Array, across: bool) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in range(size.y):
		for x in range(size.x):
			var coverage := _coverage(Vector2(x + 0.5, y + 0.5), Vector2(size), radius, 0.0)
			if coverage <= 0.0:
				continue
			var inner := _coverage(Vector2(x + 0.5, y + 0.5), Vector2(size), radius, 1.0)
			var t := (float(x) + 0.5) / float(size.x) if across else (float(y) + 0.5) / float(size.y)
			var fill := XpGradients.sample(gradient, t)
			var color := border.lerp(fill, inner)
			color.a = coverage
			image.set_pixel(x, y, color)
	return image


## How much of the pixel at [param point] lies inside a rounded rectangle of [param size]
## inset by [param inset].
static func _coverage(point: Vector2, size: Vector2, radius: float, inset: float) -> float:
	var half := size / 2.0 - Vector2(inset, inset)
	var corner := maxf(radius - inset, 0.0)
	var local := (point - size / 2.0).abs() - (half - Vector2(corner, corner))
	var outside := Vector2(maxf(local.x, 0.0), maxf(local.y, 0.0)).length()
	var distance := outside + minf(maxf(local.x, local.y), 0.0) - corner
	return clampf(0.5 - distance, 0.0, 1.0)


## A scroll bar button: a flat face with a small arrow pointing [param direction]
## (Vector2i.UP, DOWN, LEFT or RIGHT), drawn the way the Flutter version drew it.
static func scroll_button(direction: Vector2i, face: Color, arrow: Color) -> Image:
	var side := int(XpMetrics.SCROLLBAR)
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(face)
	var center := Vector2(side, side) / 2.0
	var tip_offset := 2.0
	# The triangle is 7 wide at its base and 4 tall, as the Flutter painter drew it.
	for y in range(side):
		for x in range(side):
			var point := Vector2(x + 0.5, y + 0.5) - center
			var along := point.x * direction.x + point.y * direction.y
			var across := absf(point.x * direction.y - point.y * direction.x)
			# Tip at +2 along the direction, base at -2, half width 3.5 at the base.
			if along > tip_offset or along < -tip_offset:
				continue
			var half_width := 3.5 * (tip_offset - along) / (2.0 * tip_offset)
			var coverage := clampf(half_width - across + 0.5, 0.0, 1.0)
			if coverage > 0.0:
				image.set_pixel(x, y, face.lerp(arrow, coverage))
	return image
