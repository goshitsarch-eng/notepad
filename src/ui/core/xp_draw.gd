class_name XpDraw
extends RefCounted
## Drawing helpers shared by the app's controls. All of them draw onto a CanvasItem while it
## is in its draw callback.


## True while the keyboard was the last input, so focus cues are drawn. A click turns it off,
## as the dotted focus rectangle of XP shows only while the keyboard is in use.
static var keyboard_active: bool = true

static var _box_textures: Dictionary = {}


## Draws [param text] with its top left at [param top_left].
static func text(
		canvas: CanvasItem, top_left: Vector2, content: String, color: Color,
		font: Font = null, size: int = 0) -> void:
	var used_font := font if font != null else XpFonts.ui()
	var used_size := size if size > 0 else XpFonts.ui_size()
	var baseline := top_left.y + used_font.get_ascent(used_size)
	canvas.draw_string(used_font, Vector2(top_left.x, floorf(baseline)), content,
		HORIZONTAL_ALIGNMENT_LEFT, -1, used_size, color)


## Draws [param content] so that it is centred vertically in [param box], starting at its left.
static func text_in(
		canvas: CanvasItem, box: Rect2, content: String, color: Color,
		font: Font = null, size: int = 0, align_x: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var used_font := font if font != null else XpFonts.ui()
	var used_size := size if size > 0 else XpFonts.ui_size()
	var width := used_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, used_size).x
	var x := box.position.x
	if align_x == HORIZONTAL_ALIGNMENT_CENTER:
		x = box.position.x + floorf((box.size.x - width) / 2.0)
	elif align_x == HORIZONTAL_ALIGNMENT_RIGHT:
		x = box.position.x + box.size.x - width
	var height := used_font.get_height(used_size)
	var top := box.position.y + floorf((box.size.y - height) / 2.0)
	text(canvas, Vector2(x, top), content, color, used_font, used_size)


static func text_width(content: String, font: Font = null, size: int = 0) -> float:
	var used_font := font if font != null else XpFonts.ui()
	var used_size := size if size > 0 else XpFonts.ui_size()
	return used_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, used_size).x


## [param content] shortened with an ellipsis to fit in [param width], as a list shows a long
## name.
static func fit(content: String, width: float, font: Font = null, size: int = 0) -> String:
	if text_width(content, font, size) <= width:
		return content
	var low := 0
	var high := content.length()
	while low < high:
		var middle := (low + high + 1) / 2
		if text_width(content.substr(0, middle) + "...", font, size) <= width:
			low = middle
		else:
			high = middle - 1
	return content.substr(0, low) + "..."


## One-pixel border round [param rect], drawn inside it.
static func border(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1, rect.size.x, 1), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + 1, 1, rect.size.y - 2), color)
	canvas.draw_rect(Rect2(rect.end.x - 1, rect.position.y + 1, 1, rect.size.y - 2), color)


## A rounded box with a one-pixel border and a vertical gradient fill.
static func gradient_box(
		canvas: CanvasItem, rect: Rect2, radius: int, border_color: Color, gradient: Array) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = XpGradients.sample(gradient, 0.5)
	box.border_color = border_color
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	canvas.draw_style_box(box, rect)
	# The gradient fills the inside, a row at a time, with the corners trimmed to the curve.
	var inner := rect.grow(-1.0)
	var rows := maxi(1, roundi(inner.size.y))
	var inner_radius := maxi(radius - 1, 0)
	for row in range(rows):
		var inset := 0.0
		var from_top := float(row)
		var from_bottom := float(rows - 1 - row)
		var nearest := minf(from_top, from_bottom)
		if inner_radius > 0 and nearest < float(inner_radius):
			var dy := float(inner_radius) - nearest - 0.5
			inset = float(inner_radius) - sqrt(maxf(float(inner_radius * inner_radius) - dy * dy, 0.0))
			inset = roundf(inset)
		var t := (float(row) + 0.5) / float(rows)
		canvas.draw_rect(Rect2(
			inner.position.x + inset, inner.position.y + row, inner.size.x - 2.0 * inset, 1.0),
			XpGradients.sample(gradient, t))


## The dotted rectangle XP draws round the control that has keyboard focus: one pixel on,
## one off, just outside [param box].
static func focus_cue(canvas: CanvasItem, box: Rect2, color: Color) -> void:
	var outer := box.grow(1.0)
	var x := outer.position.x
	while x < outer.end.x:
		canvas.draw_rect(Rect2(x, outer.position.y, 1, 1), color)
		canvas.draw_rect(Rect2(x, outer.end.y - 1, 1, 1), color)
		x += 2.0
	var y := outer.position.y
	while y < outer.end.y:
		canvas.draw_rect(Rect2(outer.position.x, y, 1, 1), color)
		canvas.draw_rect(Rect2(outer.end.x - 1, y, 1, 1), color)
		y += 2.0


## The 13 by 13 box of a check box or a radio button, with its gradient and border.
static func box_texture(circle: bool) -> Texture2D:
	var key := "%s|%s" % [circle, XpColors.dark]
	if _box_textures.has(key):
		return _box_textures[key]
	var gradient := XpGradients.check_box()
	var image := Image.create(13, 13, false, Image.FORMAT_RGBA8)
	for y in range(13):
		for x in range(13):
			var coverage: float
			var inner: float
			if circle:
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6.5, 6.5))
				coverage = clampf(6.5 - distance + 0.5, 0.0, 1.0)
				inner = clampf(5.5 - distance + 0.5, 0.0, 1.0)
			else:
				coverage = XpImages._coverage(Vector2(x + 0.5, y + 0.5), Vector2(13, 13), 2.0, 0.0)
				inner = XpImages._coverage(Vector2(x + 0.5, y + 0.5), Vector2(13, 13), 2.0, 1.0)
			if coverage <= 0.0:
				continue
			# Corner to corner, so the gradient is read along the diagonal.
			var t := (float(x) + float(y)) / 24.0
			var color := XpColors.box_border().lerp(XpGradients.sample(gradient, t), inner)
			color.a = coverage
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_box_textures[key] = texture
	return texture
