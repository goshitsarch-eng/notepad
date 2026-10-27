class_name TimeDate
extends RefCounted
## Text that Edit > Time/Date inserts, in the en-US form Windows XP uses by default. Moments
## are the dictionaries Time.get_datetime_dict_from_system returns.


## The time without seconds, a space, then the short date, such as "3:45 PM 10/7/2026".
static func format_time_date(moment: Dictionary) -> String:
	return "%s %s" % [format_short_time(moment), format_short_date(moment)]


## The time without seconds, such as "3:45 PM". Midnight and noon are 12.
static func format_short_time(moment: Dictionary) -> String:
	var hour: int = moment.get("hour", 0)
	var shown := 12 if hour % 12 == 0 else hour % 12
	var minute: int = moment.get("minute", 0)
	var period := "AM" if hour < 12 else "PM"
	return "%d:%02d %s" % [shown, minute, period]


## The short date, month first, such as "10/7/2026".
static func format_short_date(moment: Dictionary) -> String:
	return "%d/%d/%d" % [moment.get("month", 1), moment.get("day", 1), moment.get("year", 1970)]


## The Open dialog's "Date Modified" form, such as "10/7/2026 3:45 PM".
static func format_modified(moment: Dictionary) -> String:
	return "%s %s" % [format_short_date(moment), format_short_time(moment)]
