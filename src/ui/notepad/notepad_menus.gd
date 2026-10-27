class_name NotepadMenus
extends RefCounted
## The Notepad menu bar, with items, shortcuts, and enabled or checked states that follow the
## view model. Menu wording and order follow Windows XP Notepad.


static func build(vm: NotepadViewModel) -> Array[XpMenu]:
	var menus: Array[XpMenu] = []
	menus.append(XpMenu.new("&File", [
		XpMenuItem.make("&New", "Ctrl+N", true, false, false, vm.new_document),
		XpMenuItem.make("&Open...", "Ctrl+O", true, false, false, vm.open_document),
		XpMenuItem.make("&Save", "Ctrl+S", true, false, false, vm.save),
		XpMenuItem.make("Save &As...", "", true, false, false, vm.save_as),
		XpMenuItem.separator(),
		XpMenuItem.make("Page Se&tup...", "", true, false, false, vm.edit_page_setup),
		XpMenuItem.make("&Print...", "Ctrl+P", true, false, false, vm.print_document),
		XpMenuItem.separator(),
		XpMenuItem.make("E&xit", "", true, false, false, vm.request_exit),
	] as Array[XpMenuItem]))
	menus.append(XpMenu.new("&Edit", [
		XpMenuItem.make("&Undo", "Ctrl+Z", vm.can_undo(), false, false, vm.undo),
		XpMenuItem.separator(),
		XpMenuItem.make("Cu&t", "Ctrl+X", vm.has_selection(), false, false, vm.cut),
		XpMenuItem.make("&Copy", "Ctrl+C", vm.has_selection(), false, false, vm.copy),
		XpMenuItem.make("&Paste", "Ctrl+V", vm.clipboard_has_text(), false, false, vm.paste),
		XpMenuItem.make("De&lete", "Del", vm.has_selection(), false, false, vm.delete_selection),
		XpMenuItem.separator(),
		XpMenuItem.make("&Find...", "Ctrl+F", true, false, false, vm.show_find.bind(false)),
		XpMenuItem.make("Find &Next", "F3", not vm.last_search().query.is_empty(), false, false, vm.repeat_find),
		XpMenuItem.make("&Replace...", "Ctrl+H", true, false, false, vm.show_find.bind(true)),
		XpMenuItem.make("&Go To...", "Ctrl+G", not vm.word_wrap(), false, false, vm.show_go_to),
		XpMenuItem.separator(),
		XpMenuItem.make("Select &All", "Ctrl+A", vm.has_text(), false, false, vm.select_all),
		XpMenuItem.make("Time/&Date", "F5", true, false, false, vm.insert_time_date),
	] as Array[XpMenuItem]))
	menus.append(XpMenu.new("F&ormat", [
		XpMenuItem.make("&Word Wrap", "", true, vm.word_wrap(), true, vm.toggle_word_wrap),
		XpMenuItem.make("&Font...", "", true, false, false, vm.show_font),
	] as Array[XpMenuItem]))
	menus.append(XpMenu.new("&View", [
		XpMenuItem.make("&Status Bar", "", not vm.word_wrap(), vm.status_bar_checked(), true, vm.toggle_status_bar),
		XpMenuItem.separator(),
		XpMenuItem.make("&Dark Mode", "", true, vm.dark_mode(), true, vm.toggle_dark_mode),
	] as Array[XpMenuItem]))
	menus.append(XpMenu.new("&Help", [
		XpMenuItem.make("&Help Topics", "F1", true, false, false, vm.show_help),
		XpMenuItem.separator(),
		XpMenuItem.make("&About Notepad", "", true, false, false, vm.show_about),
	] as Array[XpMenuItem]))
	return menus


## The window menu, opened with Alt+Space or from the icon in the title bar. It holds the
## commands of the minimize, maximize and close buttons, which have no keyboard route of their
## own. Move and Size are listed as XP lists them but are not available: the window is moved
## and sized by the window manager.
static func build_system_menu(vm: NotepadViewModel) -> Array[XpMenuItem]:
	return [
		XpMenuItem.make("&Restore", "", vm.is_maximized(), false, false, vm.toggle_maximize),
		XpMenuItem.make("&Move", "", false),
		XpMenuItem.make("&Size", "", false),
		XpMenuItem.make("Mi&nimize", "", true, false, false, vm.minimize),
		XpMenuItem.make("Ma&ximize", "", not vm.is_maximized(), false, false, vm.toggle_maximize),
		XpMenuItem.separator(),
		XpMenuItem.make("&Close", "Alt+F4", true, false, false, vm.request_exit),
	] as Array[XpMenuItem]
