extends TestCase
## Port of time_date_test.dart.


func _moment(year: int, month: int, day: int, hour: int, minute: int) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}


func test_time_date_uses_the_xp_form_time_without_seconds_then_the_short_date() -> void:
	assert_eq(TimeDate.format_time_date(_moment(2026, 10, 7, 15, 5)), "3:05 PM 10/7/2026")


func test_midnight_and_noon_are_12_not_0() -> void:
	assert_eq(TimeDate.format_time_date(_moment(2026, 1, 1, 0, 0)), "12:00 AM 1/1/2026")
	assert_eq(TimeDate.format_time_date(_moment(2026, 1, 1, 12, 30)), "12:30 PM 1/1/2026")
