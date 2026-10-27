extends TestCase
## View > Dark Mode and Help > Help Topics, through the menus. (Ported from the Flutter version's
## dark_mode_and_help_test.)
##
## Not ported: the golden image tests "dark mode main window" and "dark mode File menu and Help
## dialog", which compare screenshots against stored images. What they stand for is covered by
## the behavioural checks here: the palette switches, the text and menus take its colours, and
## the Help dialog opens in dark mode.

const Requests = preload("res://src/ui/notepad/dialog_requests.gd")

const _SAMPLE := "Dark mode test.\nSecond line of text."

var rig: ViewModelRig
var screen: NotepadScreen


func before_each() -> void:
	Clipboard.set_text("")
	XpColors.dark = false
	rig = ViewModelRig.new()
	screen = NotepadScreen.new(rig.vm)
	tree.root.add_child(screen)
	await wait_frames(3)
	rig.vm.text.load_document(_SAMPLE)
	await wait_frames(1)


func after_each() -> void:
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()
	XpColors.dark = false
	XpTheme.refresh()


## The centre of the label of menu [param index] in the menu bar.
func _label_center(index: int) -> Vector2:
	var span := screen.menu_bar.label_span(index)
	return screen.menu_bar.get_global_rect().position + Vector2(span.x + span.y / 2.0, XpMetrics.MENU_BAR_HEIGHT / 2.0)


## The centre of the row at [param index] of the open popup, in window coordinates.
func _row_center(index: int) -> Vector2:
	var top := 3.0
	for position in range(index):
		top += XpMenuLayout.SEPARATOR_HEIGHT if screen.popup.items[position].is_separator else XpMetrics.MENU_ROW_HEIGHT
	return screen.popup.get_global_rect().position + Vector2(40, top + XpMetrics.MENU_ROW_HEIGHT / 2.0)


func _find_button(root: Node, label: String) -> XpButton:
	if root is XpButton and (root as XpButton).label == label:
		return root as XpButton
	for child in root.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


## Opens [param menu] on the bar and clicks the item with [param item_label].
func _choose(menu: int, item_label: String) -> void:
	await Sim.click(tree, _label_center(menu))
	assert_eq(rig.vm.open_menu(), menu)
	var row := -1
	for index in range(screen.popup.items.size()):
		if MenuLabel.parse(screen.popup.items[index].label).text == item_label:
			row = index
	assert_true(row >= 0, "the menu has %s" % item_label)
	await Sim.click(tree, _row_center(row))
	await wait_frames(2)


func test_view_dark_mode_switches_the_palette_on_and_off() -> void:
	assert_false(rig.vm.dark_mode())
	assert_false(XpColors.dark)

	await _choose(3, "Dark Mode")
	assert_true(rig.vm.dark_mode())
	assert_true(XpColors.dark)
	# The choice is kept for the next run.
	assert_not_null(rig.settings.saved)
	assert_true(rig.settings.saved.dark_mode)

	await _choose(3, "Dark Mode")
	assert_false(rig.vm.dark_mode())
	assert_false(XpColors.dark)
	assert_false(rig.settings.saved.dark_mode)


func test_dark_mode_recolours_the_text_and_the_menu_check() -> void:
	var light_paper := rig.vm.text.get_theme_color("background_color")
	var light_text := rig.vm.text.get_theme_color("font_color")
	assert_eq(light_paper, XpColors.paper())

	await _choose(3, "Dark Mode")

	assert_ne(rig.vm.text.get_theme_color("background_color"), light_paper)
	assert_ne(rig.vm.text.get_theme_color("font_color"), light_text)
	assert_eq(rig.vm.text.get_theme_color("background_color"), XpColors.paper())
	assert_eq(rig.vm.text.get_theme_color("font_color"), XpColors.text())
	# The text itself is untouched, and the item is shown as checked.
	assert_eq(rig.text(), _SAMPLE)
	await Sim.click(tree, _label_center(3))
	assert_true(screen.popup.items[2].checked)


func test_dark_mode_from_the_saved_settings_starts_the_window_dark() -> void:
	screen.queue_free()
	await wait_frames(2)
	rig.dispose()
	var initial := NotepadSettings.new().copy_with({"dark_mode": true})
	rig = ViewModelRig.new(initial)
	screen = NotepadScreen.new(rig.vm)
	tree.root.add_child(screen)
	await wait_frames(3)

	assert_true(rig.vm.dark_mode())
	assert_true(XpColors.dark)
	assert_eq(rig.vm.text.get_theme_color("background_color"), XpColors.paper())


func test_help_help_topics_lists_the_shortcuts_and_closes_with_ok() -> void:
	await _choose(4, "Help Topics")

	assert_not_null(modal_of(rig.vm, Requests.HelpRequest))
	var dialog := screen.modal_host.dialog as HelpDialog
	assert_not_null(dialog)
	if dialog == null:
		return
	# The table draws these rows.
	assert_contains(HelpDialog.SHORTCUTS, ["Ctrl+N", "New document"])
	assert_contains(HelpDialog.SHORTCUTS, ["F3", "Find next"])
	assert_true(dialog.table.is_visible_in_tree())

	await Sim.click(tree, Sim.center_of(_find_button(dialog, "OK")))
	await wait_frames(2)
	assert_null(rig.vm.modal())


func test_the_help_dialog_opens_in_dark_mode_and_closes_with_ok() -> void:
	rig.vm.toggle_dark_mode()
	await wait_frames(2)

	var showing := Pending.start(rig.vm.show_help)
	await wait_frames(3)
	var dialog := screen.modal_host.dialog as HelpDialog
	assert_not_null(dialog)
	if dialog == null:
		return
	await Sim.click(tree, Sim.center_of(_find_button(dialog, "OK")))
	await wait_frames(2)

	assert_null(rig.vm.modal())
	await showing.wait()
