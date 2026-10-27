class_name PageSetup
extends RefCounted
## Header, footer and margins from File > Page Setup. Margins are in inches. The printer
## lays out letter paper, so margins must leave at least an inch of printable space.

const MAXIMUM_MARGIN_INCHES := 6.0
const _LETTER_WIDTH_INCHES := 8.5
const _LETTER_HEIGHT_INCHES := 11.0
const _MINIMUM_PRINTABLE_INCHES := 1.0

var header: String = "&f"
var footer: String = "Page &p"
var left_inches: float = 0.75
var top_inches: float = 1.0
var right_inches: float = 0.75
var bottom_inches: float = 1.0


func _init(
		page_header: String = "&f", page_footer: String = "Page &p",
		left: float = 0.75, top: float = 1.0, right: float = 0.75, bottom: float = 1.0) -> void:
	header = page_header
	footer = page_footer
	left_inches = left
	top_inches = top
	right_inches = right
	bottom_inches = bottom


## Why these margins cannot be used, or an empty string when they can.
func margin_problem() -> String:
	for margin in [left_inches, top_inches, right_inches, bottom_inches]:
		if not is_finite(margin) or margin < 0.0 or margin > MAXIMUM_MARGIN_INCHES:
			return "Each margin must be from 0 to 6 inches."
	if left_inches + right_inches > _LETTER_WIDTH_INCHES - _MINIMUM_PRINTABLE_INCHES:
		return "The left and right margins leave no room to print."
	if top_inches + bottom_inches > _LETTER_HEIGHT_INCHES - _MINIMUM_PRINTABLE_INCHES:
		return "The top and bottom margins leave no room to print."
	return ""


func copy_with(changes: Dictionary) -> PageSetup:
	return PageSetup.new(
		changes.get("header", header),
		changes.get("footer", footer),
		changes.get("left_inches", left_inches),
		changes.get("top_inches", top_inches),
		changes.get("right_inches", right_inches),
		changes.get("bottom_inches", bottom_inches))


func equals(other: PageSetup) -> bool:
	return other != null and other.header == header and other.footer == footer \
		and other.left_inches == left_inches and other.top_inches == top_inches \
		and other.right_inches == right_inches and other.bottom_inches == bottom_inches


func to_json() -> Dictionary:
	return {
		"header": header,
		"footer": footer,
		"left": left_inches,
		"top": top_inches,
		"right": right_inches,
		"bottom": bottom_inches,
	}


static func from_json(json: Dictionary) -> PageSetup:
	# A margin outside the allowed range, or one that leaves no room to print, is damaged.
	# Those settings fall back to the defaults rather than failing the print later.
	var loaded := PageSetup.new(
		SettingsValues.text(json.get("header"), "&f"),
		SettingsValues.text(json.get("footer"), "Page &p"),
		_inches(json.get("left"), 0.75),
		_inches(json.get("top"), 1.0),
		_inches(json.get("right"), 0.75),
		_inches(json.get("bottom"), 1.0))
	if loaded.margin_problem().is_empty():
		return loaded
	return PageSetup.new(loaded.header, loaded.footer)


## A margin in inches from the settings file, or the fallback when it is not a usable
## number.
static func _inches(value: Variant, fallback: float) -> float:
	var inches := SettingsValues.number(value, fallback)
	if is_finite(inches) and inches >= 0.0 and inches <= MAXIMUM_MARGIN_INCHES:
		return inches
	return fallback
