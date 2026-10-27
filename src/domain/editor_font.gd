class_name EditorFont
extends RefCounted
## The editor font chosen in Format > Font. Sizes are points, as the XP dialog shows them.

## Families listed in the Font dialog. Fonts missing on a platform fall back at draw time.
const FAMILIES: Array[String] = [
	"Arial",
	"Comic Sans MS",
	"Courier New",
	"Georgia",
	"Impact",
	"Lucida Console",
	"Lucida Sans Unicode",
	"Microsoft Sans Serif",
	"Palatino Linotype",
	"Tahoma",
	"Times New Roman",
	"Trebuchet MS",
	"Verdana",
]

const SIZES: Array[int] = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72]

## The smallest and largest sizes, in points, that the Font dialog accepts. A size read
## from the settings file outside this range falls back to the default.
const MINIMUM_SIZE_POINTS := 1.0
const MAXIMUM_SIZE_POINTS := 1638.0

var family: String = "Lucida Console"
var size_points: float = 10.0
var style: int = FontFaceStyle.REGULAR


func _init(
		font_family: String = "Lucida Console", font_size_points: float = 10.0,
		font_style: int = FontFaceStyle.REGULAR) -> void:
	family = font_family
	size_points = font_size_points
	style = font_style


## Pixel size at 96 DPI, which is how Windows XP draws point sizes.
func size_pixels() -> float:
	return size_points * 96.0 / 72.0


func copy_with(changes: Dictionary) -> EditorFont:
	return EditorFont.new(
		changes.get("family", family),
		changes.get("size_points", size_points),
		changes.get("style", style))


func equals(other: EditorFont) -> bool:
	return other != null and other.family == family \
		and other.size_points == size_points and other.style == style


func to_json() -> Dictionary:
	return {
		"family": family,
		"size": size_points,
		"style": FontFaceStyle.style_name(style),
	}


static func from_json(json: Dictionary) -> EditorFont:
	return EditorFont.new(
		SettingsValues.text(json.get("family"), "Lucida Console"),
		_font_points(json.get("size"), 10.0),
		FontFaceStyle.from_name(json.get("style"), FontFaceStyle.REGULAR))


## A font size from the settings file, or the fallback when the Font dialog could not have
## chosen it. Sizes such as negative or huge ones leave the editor blank.
static func _font_points(value: Variant, fallback: float) -> float:
	var points := SettingsValues.number(value, fallback)
	if is_finite(points) and points >= MINIMUM_SIZE_POINTS and points <= MAXIMUM_SIZE_POINTS:
		return points
	return fallback
