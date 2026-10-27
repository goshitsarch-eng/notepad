extends TestCase
## Port of notepad_settings_test.dart.


func test_defaults_match_xp_notepad_word_wrap_on_lucida_console_10pt_0_75_1_inch_margins() -> void:
	var settings := NotepadSettings.new()
	assert_true(settings.word_wrap)
	assert_eq(settings.font.family, "Lucida Console")
	assert_eq(settings.font.size_points, 10.0)
	assert_almost_eq(settings.font.size_pixels(), 13.333, 0.001)
	assert_eq(settings.page_setup.left_inches, 0.75)
	assert_eq(settings.page_setup.top_inches, 1.0)


func test_settings_survive_a_json_round_trip() -> void:
	var original := NotepadSettings.new().copy_with({
		"word_wrap": false,
		"status_bar_visible": false,
		"font": EditorFont.new("Courier New", 12.0, FontFaceStyle.BOLD_ITALIC),
		"page_setup": PageSetup.new().copy_with({"header": "Report", "left_inches": 1.25}),
		"last_directory": "/home/tester/docs",
		"window_width": 640.0,
		"window_height": 480.0,
	})
	var restored := NotepadSettings.from_json(original.to_json())
	assert_false(restored.word_wrap)
	assert_false(restored.status_bar_visible)
	assert_true(restored.font.equals(original.font), "the font is restored")
	assert_eq(restored.font.style, FontFaceStyle.BOLD_ITALIC)
	assert_eq(restored.page_setup.header, "Report")
	assert_eq(restored.page_setup.left_inches, 1.25)
	assert_eq(restored.last_directory, "/home/tester/docs")
	assert_eq(restored.window_width, 640.0)
	assert_eq(restored.window_height, 480.0)


func test_settings_survive_a_trip_through_json_text() -> void:
	# The same round trip, through the text the settings file really holds.
	var original := NotepadSettings.new().copy_with({
		"word_wrap": false,
		"font": EditorFont.new("Courier New", 12.5, FontFaceStyle.BOLD),
		"last_directory": "/home/tester/docs",
		"window_width": 640.0,
	})
	var parsed: Variant = JSON.parse_string(JSON.stringify(original.to_json()))
	assert_true(parsed is Dictionary, "the settings parse back as an object")
	var restored := NotepadSettings.from_json(parsed)
	assert_false(restored.word_wrap)
	assert_true(restored.font.equals(original.font))
	assert_eq(restored.last_directory, "/home/tester/docs")
	assert_eq(restored.window_width, 640.0)


func test_wrong_types_in_the_file_fall_back_to_defaults_instead_of_throwing() -> void:
	var restored := NotepadSettings.from_json({
		"wordWrap": "yes",
		"font": "Arial",
		"windowWidth": "wide",
	})
	assert_true(restored.word_wrap)
	assert_eq(restored.font.family, "Lucida Console")
	assert_eq(restored.window_width, 600.0)


func test_a_font_size_the_font_dialog_cannot_choose_falls_back_to_10_points() -> void:
	for size in [0, -5, 1e9]:
		var restored := NotepadSettings.from_json({"font": {"size": size}})
		assert_eq(restored.font.size_points, 10.0, "size %s" % size)
	for size in [1, 12.5, 1638]:
		var restored := NotepadSettings.from_json({"font": {"size": size}})
		assert_eq(restored.font.size_points, float(size), "size %s" % size)
