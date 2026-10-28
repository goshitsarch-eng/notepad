class_name XpFonts
extends RefCounted
## Fonts for the XP chrome and the editor. Each lists fallbacks, so the look holds where the
## original Microsoft fonts are missing (Linux, for example). Godot draws text at whole
## pixel sizes.

const _UI_FAMILY := "Tahoma"
const _UI_FALLBACK: Array[String] = ["Liberation Sans", "Arial", "Helvetica", "sans-serif"]
const _MONO_FALLBACK: Array[String] = [
	"Liberation Mono", "Noto Sans Mono", "DejaVu Sans Mono", "Consolas", "Courier New", "monospace"]

static var _ui: SystemFont
static var _title: SystemFont
static var _ui_bold: SystemFont
static var _editor_cache: Dictionary = {}


## Tahoma 8pt is 11px. Where Tahoma is missing, Liberation Sans is drawn at 95%, which
## rounds to 10px.
static func ui_size() -> int:
	return 11 if OS.get_name() == "Windows" else roundi(11.0 * 0.95)


static func ui() -> Font:
	if _ui == null:
		_ui = _system_font(_names(_UI_FAMILY, _UI_FALLBACK), false, false)
	return _ui


static func ui_bold() -> Font:
	if _ui_bold == null:
		_ui_bold = _system_font(_names(_UI_FAMILY, _UI_FALLBACK), true, false)
	return _ui_bold


static func title() -> Font:
	if _title == null:
		_title = _system_font(_names("Trebuchet MS", _UI_FALLBACK), true, false)
	return _title


## The editor font. The default Lucida Console 10pt uses XP's 13px line pitch.
static func editor(font: EditorFont) -> Font:
	var key := "%s|%d" % [font.family, font.style]
	if not _editor_cache.has(key):
		var fallback: Array[String] = _MONO_FALLBACK if is_monospaced(font.family) else _UI_FALLBACK
		_editor_cache[key] = _system_font(
			_names(font.family, fallback), FontFaceStyle.is_bold(font.style), FontFaceStyle.is_italic(font.style))
	return _editor_cache[key]


static func editor_size(font: EditorFont) -> int:
	return maxi(1, roundi(font.size_pixels()))


static func is_monospaced(family: String) -> bool:
	return family == "Lucida Console" or family == "Courier New" or family == "Consolas"


## The height of a line of the editor: 13px for the default font, as in XP, and the font's
## own height otherwise.
static func editor_line_height(font: EditorFont) -> int:
	var natural := int(ceil(editor(font).get_height(editor_size(font))))
	if font.family == "Lucida Console" and font.size_points == 10.0:
		return 13
	return natural


static func measure_ui(text: String) -> float:
	return ui().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ui_size()).x


static func _names(family: String, fallback: Array[String]) -> PackedStringArray:
	var names := PackedStringArray([family])
	names.append_array(PackedStringArray(fallback))
	return names


static func _system_font(names: PackedStringArray, bold: bool, italic: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = names
	font.font_weight = 700 if bold else 400
	font.font_italic = italic
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.allow_system_fallback = true
	# The engine's own font is always there, so text shows even where no listed font is.
	font.fallbacks = [ThemeDB.fallback_font]
	return font
