class_name OpenSaveDialog
extends XpDialogWindow
## The Open and Save As dialogs. They list folders and files with the XP columns, and provide
## "Look in", "File name", "Files of type" and "Encoding".

const _WIDTH := 510.0
const _LABEL_WIDTH := 72.0
const _LIST_HEIGHT := 200.0

var request: DialogRequests.FileRequest
var file_system: FileSystemService
var directory: String
var encoding: int
## What the Open dialog reads the file as. DETECT is to detect it from the file.
var open_as: int = FileEncoding.DETECT
var filter: FileTypeFilter = FileTypeFilter.text_documents()
var entries: Array = []
var selected: int = -1
## Why the current folder cannot be shown, or an empty string when it listed normally.
var problem: String = ""

var look_in_combo: XpComboBox
var up_button: XpButton
var list: FileListView
var name_box: XpTextBox
var type_combo: XpComboBox
var encoding_combo: XpComboBox
var action_button: XpButton
var cancel_button: XpButton

var _folder_values: Array[String] = []


func _init(file_request: DialogRequests.FileRequest, files: FileSystemService) -> void:
	super("Save As" if file_request.mode == DialogRequests.FileDialogMode.SAVE else "Open", _WIDTH)
	request = file_request
	file_system = files
	directory = request.start_directory
	encoding = request.encoding
	close_requested.connect(cancel)
	var is_save := is_save_mode()

	look_in_combo = XpComboBox.new()
	look_in_combo.accessible_name = "Save in" if is_save else "Look in"
	look_in_combo.changed.connect(func(index: int) -> void: navigate(_folder_values[index]))
	Ui.expand(look_in_combo)
	up_button = XpButton.new("Up", false, 40.0)
	up_button.pressed.connect(go_up)
	var top_row := Ui.hbox([
		_row_label("Save in:" if is_save else "Look in:"), look_in_combo, Ui.spacer(6), up_button])

	list = FileListView.new(_LIST_HEIGHT)
	list.row_selected.connect(select_row)
	list.row_activated.connect(func(index: int) -> void: activate(entries[index]))

	name_box = XpTextBox.new()
	name_box.accessible_name = "File name"
	name_box.text = request.suggested_name
	name_box.text_submitted.connect(func(_text: String) -> void: submit())
	Ui.expand(name_box)

	type_combo = XpComboBox.new(PackedStringArray([
		FileTypeFilter.text_documents().label, FileTypeFilter.all_files().label]))
	type_combo.accessible_name = "Files of type"
	type_combo.changed.connect(func(index: int) -> void:
		filter = FileTypeFilter.text_documents() if index == 0 else FileTypeFilter.all_files()
		load_directory())
	Ui.expand(type_combo)

	var encoding_labels := PackedStringArray()
	if not is_save:
		encoding_labels.append("Detect automatically")
	for kind in FileEncoding.ALL:
		encoding_labels.append(FileEncoding.label(kind))
	encoding_combo = XpComboBox.new(encoding_labels)
	encoding_combo.accessible_name = "Encoding"
	encoding_combo.selected = encoding if is_save else 0
	encoding_combo.changed.connect(func(index: int) -> void:
		if is_save:
			encoding = FileEncoding.ALL[index]
		else:
			open_as = FileEncoding.DETECT if index == 0 else FileEncoding.ALL[index - 1])
	Ui.expand(encoding_combo)

	var fields := Ui.expand(Ui.vbox([
		Ui.hbox([_row_label("File name:"), name_box]), Ui.spacer(0, 8),
		Ui.hbox([_row_label("Files of type:"), type_combo]), Ui.spacer(0, 8),
		Ui.hbox([_row_label("Encoding:"), encoding_combo])]))
	action_button = XpButton.new("Save" if is_save else "Open", true)
	action_button.pressed.connect(submit)
	cancel_button = XpButton.new("Cancel")
	cancel_button.pressed.connect(cancel)
	var buttons := Ui.vbox([action_button, Ui.spacer(0, 6), cancel_button])
	set_content(Ui.vbox([
		top_row, Ui.spacer(0, 8), list, Ui.spacer(0, 8), Ui.hbox([fields, Ui.spacer(12), buttons])]))
	load_directory()


func is_save_mode() -> bool:
	return request.mode == DialogRequests.FileDialogMode.SAVE


func _row_label(text: String) -> Control:
	var label := Ui.label(text)
	label.custom_minimum_size = Vector2(_LABEL_WIDTH, 0)
	return label


## Lists [member directory]. A folder that has been deleted or moved since it was last used
## shows the nearest folder above it that still exists, rather than an empty list.
func load_directory() -> void:
	var folder := directory
	var found: Array = []
	var why := ""
	while true:
		var result := file_system.list_directory(folder, filter)
		if result.ok:
			found = result.value
			break
		var error: Variant = result.error
		if error is FileError and error.kind == FileError.Kind.NOT_FOUND:
			var parent := folder.get_base_dir()
			if parent != folder:
				folder = parent
				continue
		why = _folder_problem(error)
		break
	directory = folder
	entries = found
	problem = why
	selected = -1
	list.problem = problem
	list.set_entries(entries)
	_refresh_folder_list()


static func _folder_problem(error: Variant) -> String:
	var reason := FileError.describe(error)
	return "This folder cannot be opened." if reason.is_empty() \
		else "This folder cannot be opened.\n%s" % reason


## The folder hierarchy from the root down to the current folder, for "Look in".
func _refresh_folder_list() -> void:
	var labels := PackedStringArray()
	_folder_values.clear()
	var normal := directory.replace("\\", "/")
	var parts := normal.split("/")
	var current := ""
	for index in range(parts.size()):
		var part := parts[index]
		if index == 0 and part.is_empty():
			current = "/"
			labels.append("/")
			_folder_values.append("/")
			continue
		if part.is_empty():
			continue
		current = current.path_join(part) if not current.is_empty() else part
		labels.append(part)
		_folder_values.append(current)
	look_in_combo.labels = labels
	look_in_combo.selected = labels.size() - 1
	look_in_combo.queue_redraw()


func navigate(new_directory: String) -> void:
	directory = new_directory
	load_directory()


## Opens a folder that was named in the File name box. The name typed to get here is cleared,
## so it is not taken for a file name in the new folder.
func enter(new_directory: String) -> void:
	name_box.text = ""
	navigate(new_directory)


func go_up() -> void:
	var parent := directory.get_base_dir()
	if parent != directory:
		navigate(parent)


func cancel() -> void:
	request.complete(null)


func activate(entry: DirectoryEntry) -> void:
	if entry.is_directory:
		# Going into a folder from the list keeps what was typed, as Up and Look in do.
		navigate(entry.path)
		# Keep typing in the file name box after entering a folder, as XP does.
		name_box.grab_focus()
		return
	request.complete(DialogRequests.FileChoice.new(
		entry.path, encoding, FileEncoding.DETECT if is_save_mode() else open_as))


func select_row(index: int) -> void:
	selected = index
	list.selected = index
	var entry: DirectoryEntry = entries[index]
	if not entry.is_directory:
		name_box.text = entry.name


func _entry_named(entry_name: String, want_directory: bool) -> DirectoryEntry:
	for entry in entries:
		if entry.is_directory == want_directory and entry.name == entry_name:
			return entry
	return null


func submit() -> void:
	var typed := name_box.text.strip_edges()
	if typed.is_empty():
		if selected >= 0:
			activate(entries[selected])
		return
	var folder := _entry_named(typed, true)
	if folder != null:
		enter(folder.path)
		return
	var target := typed if typed.is_absolute_path() else directory.path_join(typed)
	# A typed path that names a folder opens the folder, as XP does. Without this a folder
	# path typed into Save As was saved as a file with that name.
	if file_system.directory_exists(target):
		enter(target.simplify_path())
		return
	if not is_save_mode():
		# A missing file is reported by the view model, so the user is told why nothing
		# opened.
		request.complete(DialogRequests.FileChoice.new(target, encoding, open_as))
		return
	var path := target
	if not filter.extensions.is_empty() and typed.get_extension().is_empty():
		path = target + filter.extensions[0]
	request.complete(DialogRequests.FileChoice.new(path, encoding))


func focus_target() -> Control:
	return name_box
