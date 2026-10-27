extends TestCase
## The window menu of the title bar. The minimize, maximize and close buttons are drawn in the
## title bar and cannot be reached with Tab, so, as in XP, Alt+Space opens a menu that holds the
## same commands. (Ported from the Flutter version's system_menu_test.)

var rig: ViewModelRig
var screen: NotepadScreen


func before_each() -> void:
	Clipboard.set_text("")
	rig = ViewModelRig.new()
	screen = NotepadScreen.new(rig.vm)
	tree.root.add_child(screen)
	await wait_frames(3)


func after_each() -> void:
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()


func _alt_space() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key_down(tree, KEY_SPACE, {"alt": true, "text": " "})
	await Sim.key_up(tree, KEY_SPACE, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	await wait_frames(1)


func _press(keycode: int) -> void:
	await Sim.key(tree, keycode)
	await wait_frames(1)


## The centre of the row at [param index] of the open popup, in window coordinates.
func _row_center(index: int) -> Vector2:
	var top := 3.0
	for position in range(index):
		top += XpMenuLayout.SEPARATOR_HEIGHT if screen.popup.items[position].is_separator else XpMetrics.MENU_ROW_HEIGHT
	return screen.popup.get_global_rect().position + Vector2(40, top + XpMetrics.MENU_ROW_HEIGHT / 2.0)


func test_alt_space_opens_the_window_menu_with_its_commands() -> void:
	await _alt_space()

	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)
	assert_not_null(screen.popup)
	var labels: Array[String] = []
	var shortcuts: Array[String] = []
	for item in screen.popup.items:
		if not item.is_separator:
			labels.append(MenuLabel.parse(item.label).text)
			shortcuts.append(item.shortcut)
	assert_eq(labels, ["Restore", "Move", "Size", "Minimize", "Maximize", "Close"] as Array[String])
	assert_contains(shortcuts, "Alt+F4")


func test_the_underlined_letter_picks_a_command_n_minimizes() -> void:
	await _alt_space()

	await _press(KEY_N)

	assert_eq(rig.window.minimizes, 1)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_x_maximizes_and_c_asks_to_close() -> void:
	await _alt_space()
	await _press(KEY_X)
	assert_eq(rig.window.maximize_toggles, 1)

	await _alt_space()
	await _press(KEY_C)
	await wait_frames(2)
	assert_true(rig.window.closed)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_restore_is_available_only_when_the_window_is_maximized() -> void:
	rig.vm.on_maximized_changed(true)
	await wait_frames(1)

	await _alt_space()
	await _press(KEY_R)
	assert_eq(rig.window.maximize_toggles, 1)

	# Not maximized: Restore does nothing and the menu stays open.
	rig.vm.on_maximized_changed(false)
	await wait_frames(1)
	await _alt_space()
	await _press(KEY_R)
	assert_eq(rig.window.maximize_toggles, 1)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)


func test_the_first_command_that_can_be_chosen_is_the_one_lit_and_enter_picks_it() -> void:
	await _alt_space()

	# Restore, Move and Size are not available, so Minimize is first.
	await _press(KEY_ENTER)

	assert_eq(rig.window.minimizes, 1)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_down_moves_to_the_next_command_that_can_be_chosen() -> void:
	await _alt_space()

	await _press(KEY_DOWN) # Maximize
	await _press(KEY_ENTER)

	assert_eq(rig.window.maximize_toggles, 1)
	assert_eq(rig.window.minimizes, 0)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_up_from_the_first_command_goes_round_to_close() -> void:
	await _alt_space()

	await _press(KEY_UP)
	await _press(KEY_ENTER)
	await wait_frames(2)

	assert_true(rig.window.closed)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_escape_closes_it_and_the_key_goes_back_to_the_text() -> void:
	await _alt_space()
	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)

	await _press(KEY_ESCAPE)
	await wait_frames(2)

	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)
	assert_null(screen.popup)
	assert_eq(tree.root.gui_get_focus_owner(), rig.vm.text)


func test_right_goes_to_the_file_menu_and_left_to_the_last_one() -> void:
	await _alt_space()

	await _press(KEY_RIGHT)
	assert_eq(rig.vm.open_menu(), 0)

	# Alt+Space opens the window menu again.
	await _alt_space()
	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)
	await _press(KEY_LEFT)
	assert_eq(rig.vm.open_menu(), 4)


func test_alt_space_again_closes_it() -> void:
	await _alt_space()
	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)

	await _alt_space()

	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_a_click_on_the_title_bar_icon_opens_it_and_again_closes_it() -> void:
	await Sim.click(tree, Vector2(14, 15))
	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)

	await Sim.click(tree, Vector2(14, 15))
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_a_right_click_on_the_title_bar_opens_it() -> void:
	await Sim.click(tree, Vector2(300, 15), MOUSE_BUTTON_RIGHT)

	assert_eq(rig.vm.open_menu(), NotepadViewModel.SYSTEM_MENU)


func test_a_click_elsewhere_closes_it() -> void:
	await _alt_space()

	await Sim.click(tree, Vector2(400, 300))

	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_a_click_on_a_command_runs_it() -> void:
	await _alt_space()
	# Restore, Move, Size, Minimize: the fourth row.
	assert_eq(MenuLabel.parse(screen.popup.items[3].label).text, "Minimize")

	await Sim.click(tree, _row_center(3))

	assert_eq(rig.window.minimizes, 1)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_alt_space_does_nothing_while_a_dialog_is_open() -> void:
	var showing := Pending.start(rig.vm.show_about)
	await wait_frames(3)

	await _alt_space()

	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)
	rig.vm.modal().complete(true)
	await showing.wait()
