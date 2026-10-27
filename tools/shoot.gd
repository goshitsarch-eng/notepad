extends SceneTree
## Starts the real app, puts it in a named state and saves a screenshot, for checking how it
## looks without a display of one's own:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/shoot.gd -- \
##       --scenario=menu-file --out=/tmp/shot.png [--open=/path/to/file.txt] [--size=600x404]
## Scenarios: main, menu-file, menu-edit, menu-format, menu-view, menu-help, find, replace,
## goto, font, page-setup, about, help, open, save-as, message, window-menu, dark, dark-menu.

var _scenario := "main"
var _out := "/tmp/xp_notepad.png"
var _open := ""
var _size := Vector2i.ZERO


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario="):
			_scenario = argument.substr(11)
		elif argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--open="):
			_open = argument.substr(7)
		elif argument.begins_with("--size="):
			var parts := argument.substr(7).split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
	_run()


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _run() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	if _size != Vector2i.ZERO:
		root.size = _size
		await _frames(3)
	var vm: NotepadViewModel = main.view_model
	var screen: NotepadScreen = main.screen
	if not _open.is_empty():
		vm.text.load_document(FileAccess.get_file_as_string(_open).replace("\r\n", "\n"))
		await _frames(3)
	match _scenario:
		"menu-file":
			vm.open_menu_at(0, true)
		"menu-edit":
			vm.text.select_all()
			vm.open_menu_at(1, true)
		"menu-format":
			vm.open_menu_at(2, true)
		"menu-view":
			vm.open_menu_at(3, true)
		"menu-help":
			vm.open_menu_at(4, true)
		"window-menu":
			vm.open_menu_at(NotepadViewModel.SYSTEM_MENU, true)
		"find":
			vm.show_find(false)
		"replace":
			vm.show_find(true)
		"goto":
			vm.toggle_word_wrap()
			vm.show_go_to()
		"font":
			vm.show_font()
		"page-setup":
			vm.edit_page_setup()
		"about":
			vm.show_about()
		"help":
			vm.show_help()
		"open":
			vm.open_document()
		"save-as":
			vm.save_as()
		"message":
			vm.text.insert_text_at_caret("changed")
			vm.new_document()
		"dark":
			vm.toggle_dark_mode()
		"dark-menu":
			vm.toggle_dark_mode()
			vm.open_menu_at(0, true)
		"nowrap":
			vm.toggle_word_wrap()
	await _frames(8)
	var image := root.get_texture().get_image()
	image.save_png(_out)
	print("saved %s (%dx%d)" % [_out, image.get_width(), image.get_height()])
	quit()
