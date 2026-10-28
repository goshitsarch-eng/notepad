class_name XpTheme
extends RefCounted
## The engine Theme the app puts on its text editor: Luna scroll bars. It is rebuilt when
## Dark Mode changes. Everything else is drawn by the app's own controls.


static var _shared: Theme


## The one Theme every scroll bar of the app uses. It is filled in again, in place, when
## Dark Mode changes, so the scroll bars that hold it follow.
static func shared() -> Theme:
	if _shared == null:
		_shared = Theme.new()
		_fill(_shared)
	return _shared


static func refresh() -> void:
	if _shared != null:
		_shared.clear()
		_fill(_shared)


static func _fill(theme: Theme) -> void:
	_add_scroll_bar(theme, "VScrollBar", true)
	_add_scroll_bar(theme, "HScrollBar", false)


static func _add_scroll_bar(theme: Theme, type: String, vertical: bool) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = XpColors.scroll_track()
	track.set_content_margin_all(0)
	theme.set_stylebox("scroll", type, track)
	theme.set_stylebox("scroll_focus", type, track)

	var thumb_image := XpImages.rounded_gradient(
		Vector2i(17, 17),
		3.0, XpColors.thumb_border(), XpGradients.scroll_thumb(), vertical)
	var thumb := StyleBoxTexture.new()
	thumb.texture = ImageTexture.create_from_image(thumb_image)
	# The corners are kept, and the middle is stretched along the bar.
	thumb.set_texture_margin_all(5)
	thumb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	thumb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# A thumb is never shorter than 15 pixels along the bar.
	if vertical:
		thumb.content_margin_top = 7.5
		thumb.content_margin_bottom = 7.5
		thumb.content_margin_left = 0
		thumb.content_margin_right = 0
	else:
		thumb.content_margin_left = 7.5
		thumb.content_margin_right = 7.5
		thumb.content_margin_top = 0
		thumb.content_margin_bottom = 0
	theme.set_stylebox("grabber", type, thumb)
	theme.set_stylebox("grabber_highlight", type, thumb)
	theme.set_stylebox("grabber_pressed", type, thumb)

	var decrement_direction := Vector2i.UP if vertical else Vector2i.LEFT
	var increment_direction := Vector2i.DOWN if vertical else Vector2i.RIGHT
	var decrement := ImageTexture.create_from_image(
		XpImages.scroll_button(decrement_direction, XpColors.scroll_button(), XpColors.scroll_arrow()))
	var increment := ImageTexture.create_from_image(
		XpImages.scroll_button(increment_direction, XpColors.scroll_button(), XpColors.scroll_arrow()))
	for name in ["decrement", "decrement_highlight", "decrement_pressed"]:
		theme.set_icon(name, type, decrement)
	for name in ["increment", "increment_highlight", "increment_pressed"]:
		theme.set_icon(name, type, increment)
	# The bar has no extra padding round its parts.
	theme.set_constant("h_separation", type, 0)
