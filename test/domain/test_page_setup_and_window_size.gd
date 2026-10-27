extends TestCase
## Port of page_setup_and_window_size_test.dart.

# ---- page margins ----


func test_the_default_margins_can_be_printed() -> void:
	assert_eq(PageSetup.new().margin_problem(), "")


func test_a_margin_outside_0_to_6_inches_is_rejected() -> void:
	assert_ne(PageSetup.new().copy_with({"top_inches": -1.0}).margin_problem(), "")
	assert_ne(PageSetup.new().copy_with({"left_inches": 6.5}).margin_problem(), "")
	assert_ne(PageSetup.new().copy_with({"bottom_inches": NAN}).margin_problem(), "")


func test_top_and_bottom_must_leave_an_inch_of_printable_height() -> void:
	assert_ne(
		PageSetup.new().copy_with({"top_inches": 6.0, "bottom_inches": 6.0}).margin_problem(), "")
	assert_eq(
		PageSetup.new().copy_with({"top_inches": 4.5, "bottom_inches": 4.5}).margin_problem(), "")


func test_left_and_right_must_leave_an_inch_of_printable_width() -> void:
	assert_ne(
		PageSetup.new().copy_with({"left_inches": 4.0, "right_inches": 4.0}).margin_problem(), "")
	assert_eq(
		PageSetup.new().copy_with({"left_inches": 3.0, "right_inches": 3.5}).margin_problem(), "")


# ---- settings loaded from a damaged file ----


func test_margins_that_leave_no_room_to_print_fall_back_to_the_defaults() -> void:
	var settings := NotepadSettings.from_json({
		"pageSetup": {"top": 6, "bottom": 6, "header": "Mine"},
	})
	assert_eq(settings.page_setup.top_inches, PageSetup.new().top_inches)
	assert_eq(settings.page_setup.bottom_inches, PageSetup.new().bottom_inches)
	# The header is kept, because it does not affect the layout.
	assert_eq(settings.page_setup.header, "Mine")


func test_a_margin_outside_the_allowed_range_falls_back_to_its_default() -> void:
	var settings := NotepadSettings.from_json({"pageSetup": {"left": -2, "right": 0.5}})
	assert_eq(settings.page_setup.left_inches, PageSetup.new().left_inches)
	assert_eq(settings.page_setup.right_inches, 0.5)


func test_a_window_side_below_the_minimum_is_raised_to_the_minimum() -> void:
	var settings := NotepadSettings.from_json({"windowWidth": 10, "windowHeight": 20})
	assert_eq(settings.window_width, NotepadSettings.MINIMUM_WINDOW_WIDTH)
	assert_eq(settings.window_height, NotepadSettings.MINIMUM_WINDOW_HEIGHT)


func test_an_absurdly_large_window_side_is_capped() -> void:
	var settings := NotepadSettings.from_json({"windowWidth": 1e9})
	assert_eq(settings.window_width, 8192.0)


func test_a_reasonable_window_size_is_kept_as_saved() -> void:
	var settings := NotepadSettings.from_json({"windowWidth": 720, "windowHeight": 500})
	assert_eq(settings.window_width, 720.0)
	assert_eq(settings.window_height, 500.0)
