extends TestCase
## Keyboard, pointer and layout behaviour found wanting in the second audit: Alt, AltGr and the
## menu mnemonics, the caption's double and right clicks, and the menus at the smallest window.
## (Ported from the Flutter version's audit_input_test.)
##
## Not ported: the four "no-wrap editor measures its longest line only when the text changes"
## tests. They are about LongestLineMeter, which the Godot version does not have, because the
## engine's TextEdit measures its own lines.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

## A point on the blank part of the caption, between the title and the buttons.
const _SPOT := Vector2(330, 15)

var rig: ViewModelRig
var screen: NotepadScreen
var _holder: Control


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	await _open(null)


func after_each() -> void:
	_close()
	await wait_frames(2)
	rig.dispose()


## Builds the screen. A [param window_size] other than null puts it in a parent of that size,
## since the headless window cannot be resized.
func _open(window_size: Variant) -> void:
	if window_size == null:
		screen = NotepadScreen.new(rig.vm)
		tree.root.add_child(screen)
	else:
		_holder = Control.new()
		_holder.clip_contents = true
		_holder.position = Vector2.ZERO
		_holder.size = window_size
		tree.root.add_child(_holder)
		screen = NotepadScreen.new(rig.vm)
		_holder.add_child(screen)
	await wait_frames(3)


func _close() -> void:
	if _holder != null:
		_holder.queue_free()
		_holder = null
	else:
		screen.queue_free()


func _find_label(root: Node, text: String) -> Label:
	if root is Label and (root as Label).text == text:
		return root as Label
	for child in root.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


# ---- Alt and the menu accelerators ----

func test_alt_f_opens_the_file_menu() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key(tree, KEY_F, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_eq(rig.vm.open_menu(), 0)


func test_a_lost_alt_key_up_does_not_turn_later_letters_into_menu_commands() -> void:
	# Alt goes down, then the window loses the key-up, as when Alt+Tab leaves the app. The
	# next key arrives without the Alt modifier.
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key(tree, KEY_F)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_ctrl_alt_letter_which_is_altgr_on_windows_types_instead_of_opening_a_menu() -> void:
	await Sim.key_down(tree, KEY_CTRL, {"ctrl": true})
	await Sim.key_down(tree, KEY_ALT, {"ctrl": true, "alt": true})
	await Sim.key(tree, KEY_E, {"ctrl": true, "alt": true})
	await Sim.key_up(tree, KEY_ALT, {"ctrl": true})
	await Sim.key_up(tree, KEY_CTRL)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_on_windows_altgr_as_the_engine_reports_it_types_instead_of_opening_a_menu() -> void:
	# A German layout: Windows sends a Ctrl down with the AltGr key, and the engine releases
	# that Ctrl only after AltGr is released. AltGr+E types the euro sign.
	await Sim.key_down(tree, KEY_CTRL, {"ctrl": true})
	await Sim.key_down(tree, KEY_ALT, {"ctrl": true, "alt": true})
	await Sim.key_down(tree, KEY_E, {"ctrl": true, "alt": true, "text": "€"})
	await Sim.key_up(tree, KEY_E, {"ctrl": true, "alt": true})
	await Sim.key_up(tree, KEY_ALT, {"ctrl": true})
	await Sim.key_up(tree, KEY_CTRL)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)
	assert_false(rig.vm.menu_cue())


func test_on_windows_alt_e_opens_edit_although_windows_reports_the_letter_it_types() -> void:
	# The engine gives a key pressed with Alt the printable character of its WM_SYSCHAR
	# message, so Alt+E arrives with the character e.
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key_down(tree, KEY_E, {"alt": true, "text": "e"})
	await Sim.key_up(tree, KEY_E, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_eq(rig.vm.open_menu(), 1)


func test_elsewhere_alt_f_opens_file_even_though_the_key_reports_its_letter() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key_down(tree, KEY_F, {"alt": true, "text": "f"})
	await Sim.key_up(tree, KEY_F, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_eq(rig.vm.open_menu(), 0)


func test_tapping_altgr_does_not_light_up_the_menu_underlines() -> void:
	await Sim.key_down(tree, KEY_CTRL, {"ctrl": true})
	await Sim.key_down(tree, KEY_ALT, {"ctrl": true, "alt": true})
	await Sim.key_up(tree, KEY_ALT, {"ctrl": true})
	await Sim.key_up(tree, KEY_CTRL)
	assert_false(rig.vm.menu_cue())


func test_tapping_alt_alone_does_light_them_up() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_true(rig.vm.menu_cue())


func test_alt_e_still_works_after_a_lost_alt_key_up_once_alt_is_pressed_again() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	# The key-up is lost. Alt is pressed again.
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key(tree, KEY_E, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_eq(rig.vm.open_menu(), 1)


# ---- F-27: the caption maximizes only on a primary-button double click ----
# The engine counts the clicks and marks the second press of a double click, so the caption
# acts on that mark and keeps no count of its own.

func test_two_quick_left_clicks_toggle_the_window_size() -> void:
	await Sim.click(tree, _SPOT)
	await Sim.click(tree, _SPOT, MOUSE_BUTTON_LEFT, true)
	assert_eq(rig.window.maximize_toggles, 1)


func test_one_left_click_does_not_toggle_the_window_size() -> void:
	await Sim.click(tree, _SPOT)
	assert_eq(rig.window.maximize_toggles, 0)


func test_two_quick_right_clicks_do_nothing() -> void:
	await Sim.click(tree, _SPOT, MOUSE_BUTTON_RIGHT)
	await Sim.click(tree, _SPOT, MOUSE_BUTTON_RIGHT, true)
	assert_eq(rig.window.maximize_toggles, 0)


func test_a_right_click_between_two_left_clicks_does_not_make_a_double_click() -> void:
	# The engine does not flag a press as a double click after a click of another button, so
	# the second left press arrives as a plain one and the window stays as it is.
	await Sim.click(tree, _SPOT)
	await Sim.click(tree, _SPOT, MOUSE_BUTTON_RIGHT)
	await Sim.click(tree, _SPOT)
	assert_eq(rig.window.maximize_toggles, 0)


func test_the_caption_buttons_still_work() -> void:
	await Sim.click(tree, Sim.center_of(screen.caption.maximize_button()))
	assert_eq(rig.window.maximize_toggles, 1)
	assert_null(rig.vm.modal())


# ---- F-07: every menu fits in the smallest window ----

func test_the_tallest_popup_ends_above_the_bottom_frame_at_the_minimum_height() -> void:
	var popup_top := XpMetrics.CAPTION_HEIGHT + XpMetrics.MENU_BAR_HEIGHT
	for menu in NotepadMenus.build(rig.vm):
		var bottom := popup_top + XpMenuLayout.popup_height(menu.items)
		assert_true(bottom + XpMetrics.FRAME <= NotepadSettings.MINIMUM_WINDOW_HEIGHT,
			"the %s menu would be cut off in the smallest window" % menu.label)


func test_the_edit_menu_shows_its_last_item_at_the_minimum_window_size() -> void:
	# The text control belongs to the screen that shows it, so this screen gets its own view model.
	_close()
	await wait_frames(2)
	rig.dispose()
	rig = ViewModelRig.new()
	await _open(Vector2(NotepadSettings.MINIMUM_WINDOW_WIDTH, NotepadSettings.MINIMUM_WINDOW_HEIGHT))

	rig.vm.open_menu_at(1, true)
	await wait_frames(3)

	assert_not_null(screen.popup)
	var popup := screen.popup.get_global_rect()
	assert_true(popup.end.y <= NotepadSettings.MINIMUM_WINDOW_HEIGHT - XpMetrics.FRAME,
		"the popup ends at %s" % popup.end.y)
	# Time/Date is the last row, above the popup's bottom padding.
	var items := screen.items_of(1)
	assert_eq(items.back().label, "Time/&Date")
	var last_bottom := popup.end.y - 3.0
	# And it can be reached: a click on the row runs it.
	await Sim.click(tree, Vector2(popup.position.x + 40, last_bottom - XpMetrics.MENU_ROW_HEIGHT / 2.0))
	assert_eq(rig.text(), "3:05 PM 10/7/2026")


func test_the_minimum_size_is_enforced_when_a_settings_file_asks_for_less() -> void:
	var settings := NotepadSettings.from_json({"windowWidth": 300.0, "windowHeight": 200.0})
	assert_eq(settings.window_height, NotepadSettings.MINIMUM_WINDOW_HEIGHT)
	assert_eq(settings.window_width, NotepadSettings.MINIMUM_WINDOW_WIDTH)


# ---- F-25 ----

func test_help_about_names_the_version() -> void:
	var showing := Pending.start(rig.vm.show_about)
	await wait_frames(3)
	assert_not_null(screen.modal_host)
	assert_not_null(_find_label(screen.modal_host, "Version %s" % AppInfo.version()))
	rig.vm.modal().complete(true)
	await showing.wait()
