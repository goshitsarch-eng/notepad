class_name XpTextBox
extends LineEdit
## A single-line XP text box (21px, 1px blue-grey border). A box can be limited to the
## characters of a pattern, which stands in for the input formatters of the Flutter version.

## Characters outside this set are dropped as they are typed. Empty allows anything.
var allowed_characters: String = ""
var accessible_name: String = ""


func _init(allowed: String = "", box_width: float = 0.0) -> void:
	allowed_characters = allowed
	custom_minimum_size = Vector2(box_width, XpMetrics.FIELD_HEIGHT)
	context_menu_enabled = false
	# Enter submits a dialog's box, and the box must go on taking keys: the engine would
	# otherwise leave edit mode on Enter and ignore typing until it was clicked again.
	keep_editing_on_text_submit = true
	caret_blink = true
	select_all_on_focus = false
	deselect_on_focus_loss_enabled = false
	text_changed.connect(_on_text_changed)
	_apply()


func xp_theme_changed() -> void:
	_apply()


func _apply() -> void:
	add_theme_font_override("font", XpFonts.ui())
	add_theme_font_size_override("font_size", XpFonts.ui_size())
	add_theme_color_override("font_color", XpColors.text())
	add_theme_color_override("font_selected_color", XpColors.highlight_text())
	add_theme_color_override("selection_color", XpColors.highlight())
	add_theme_color_override("caret_color", XpColors.text())
	add_theme_constant_override("caret_width", 1)
	add_theme_constant_override("minimum_character_width", 1)
	var box := StyleBoxFlat.new()
	box.bg_color = XpColors.paper()
	box.border_color = XpColors.edit_border()
	box.set_border_width_all(1)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	for name in ["normal", "focus", "read_only"]:
		add_theme_stylebox_override(name, box)


func _on_text_changed(new_text: String) -> void:
	if allowed_characters.is_empty():
		return
	var kept := ""
	for index in range(new_text.length()):
		if allowed_characters.contains(new_text[index]):
			kept += new_text[index]
	if kept == new_text:
		return
	var column := caret_column - (new_text.length() - kept.length())
	text = kept
	caret_column = maxi(column, 0)


## Sets the text and selects all of it, so typing replaces it instead of adding to it.
func set_text_selected(value: String) -> void:
	text = value
	caret_column = value.length()
	select_all()
