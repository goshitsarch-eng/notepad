extends TestCase
## The real screen, on fakes: typing reaches the text, keys open menus, and clicks work.

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


func test_the_text_has_focus_when_the_window_opens() -> void:
	assert_eq(tree.root.gui_get_focus_owner(), rig.vm.text)


func test_typing_reaches_the_text() -> void:
	await Sim.type(tree, "hello")
	assert_eq(rig.text(), "hello")
	assert_true(rig.vm.is_modified())


func test_alt_f_opens_the_file_menu_and_escape_closes_it() -> void:
	await Sim.key_down(tree, KEY_ALT, {"alt": true})
	await Sim.key(tree, KEY_F, {"alt": true})
	await Sim.key_up(tree, KEY_ALT)
	assert_eq(rig.vm.open_menu(), 0)
	await Sim.key(tree, KEY_ESCAPE)
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)


func test_tab_inserts_a_tab_character_instead_of_moving_focus() -> void:
	await Sim.key(tree, KEY_TAB)
	assert_eq(rig.text(), "\t")
	assert_eq(tree.root.gui_get_focus_owner(), rig.vm.text)


func test_f5_inserts_the_time_and_date() -> void:
	await Sim.key(tree, KEY_F5)
	assert_eq(rig.text(), "3:05 PM 10/7/2026")


func test_ctrl_f_opens_find() -> void:
	await Sim.key(tree, KEY_F, {"ctrl": true})
	assert_not_null(rig.vm.find_state())
	assert_not_null(screen.find_dialog)


func test_clicking_a_menu_label_opens_it_and_clicking_an_item_runs_it() -> void:
	var label := screen.menu_bar.get_global_rect().position + Vector2(screen.menu_bar.label_span(2).x + 10, 8)
	await Sim.click(tree, label)
	assert_eq(rig.vm.open_menu(), 2)
	assert_not_null(screen.popup)
	# Word Wrap is the first row of Format.
	await Sim.click(tree, screen.popup.get_global_rect().position + Vector2(40, 14))
	assert_false(rig.vm.word_wrap())
	assert_eq(rig.vm.open_menu(), NotepadViewModel.NO_MENU)
