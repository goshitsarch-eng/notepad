class_name SettingsValues
extends RefCounted
## Reads values out of a settings file whose contents may be of any type. A value of the
## wrong type gives the fallback instead of failing.


static func text(value: Variant, fallback: String) -> String:
	return value if value is String else fallback


static func number(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


static func flag(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback
