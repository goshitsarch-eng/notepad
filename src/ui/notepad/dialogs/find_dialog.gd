class_name FindDialog
extends XpDialogWindow
## Edit > Find and Edit > Replace. The dialog is modeless, as in XP: the text stays editable
## while it is open, and clicking into the text moves focus there.

var vm: NotepadViewModel
var replace_mode: bool
var find_box: XpTextBox
var replace_box: XpTextBox
var whole_word_box: XpCheckBox
var match_case_box: XpCheckBox
var up_button: XpRadioButton
var down_button: XpRadioButton
var find_next_button: XpButton
var replace_button: XpButton
var replace_all_button: XpButton
var cancel_button: XpButton

var _down: bool


func _init(view_model: NotepadViewModel, for_replace: bool) -> void:
	super("Replace" if for_replace else "Find", 380.0)
	vm = view_model
	replace_mode = for_replace
	close_requested.connect(cancel)
	var last := vm.last_search()
	_down = last.forward

	find_box = XpTextBox.new()
	find_box.accessible_name = "Find what"
	# The query starts out selected, so typing replaces it instead of adding to it.
	find_box.set_text_selected(last.query)
	find_box.text_submitted.connect(func(_text: String) -> void: find_next())
	Ui.expand(find_box)
	var rows: Array = [_labeled("Find what:", find_box)]
	if replace_mode:
		replace_box = XpTextBox.new()
		replace_box.accessible_name = "Replace with"
		Ui.expand(replace_box)
		rows.append(Ui.spacer(0, 6))
		rows.append(_labeled("Replace with:", replace_box))
	whole_word_box = XpCheckBox.new("Match whole word only", last.whole_word)
	match_case_box = XpCheckBox.new("Match case", last.match_case)
	rows.append_array([Ui.spacer(0, 10), whole_word_box, Ui.spacer(0, 4), match_case_box])
	if not replace_mode:
		rows.append(Ui.spacer(0, 8))
		rows.append(_direction_group())
	var fields := Ui.expand(Ui.vbox(rows))

	find_next_button = XpButton.new("Find Next", true)
	find_next_button.pressed.connect(find_next)
	var buttons: Array = [find_next_button]
	if replace_mode:
		replace_button = XpButton.new("Replace")
		replace_button.pressed.connect(replace_one)
		replace_all_button = XpButton.new("Replace All")
		replace_all_button.pressed.connect(replace_every)
		buttons.append_array([Ui.spacer(0, 6), replace_button, Ui.spacer(0, 6), replace_all_button])
	cancel_button = XpButton.new("Cancel")
	cancel_button.pressed.connect(cancel)
	buttons.append_array([Ui.spacer(0, 6), cancel_button])
	set_content(Ui.hbox([fields, Ui.spacer(12), Ui.vbox(buttons)]))

	vm.find_requested.connect(_on_find_requested)
	vm.find_focus_requested.connect(focus_find_box)


func _exit_tree() -> void:
	if vm != null:
		if vm.find_requested.is_connected(_on_find_requested):
			vm.find_requested.disconnect(_on_find_requested)
		if vm.find_focus_requested.is_connected(focus_find_box):
			vm.find_focus_requested.disconnect(focus_find_box)


## Ctrl+F, Edit > Find and Ctrl+H asked again while this dialog is open. The box loads the
## current query and takes focus, so typing goes to the dialog, not the document.
func _on_find_requested() -> void:
	find_box.set_text_selected(vm.last_search().query)
	find_box.grab_focus()


## Gives focus back to the Find box when a message or menu closes, without touching the text
## the user has typed there.
func focus_find_box() -> void:
	find_box.grab_focus()


func _labeled(label: String, field: Control) -> Control:
	var holder := Ui.label(label)
	holder.custom_minimum_size = Vector2(72, 0)
	return Ui.hbox([holder, Ui.spacer(6), field])


func _direction_group() -> Control:
	up_button = XpRadioButton.new("Up", not _down)
	down_button = XpRadioButton.new("Down", _down)
	up_button.selected.connect(func() -> void: _set_direction(true, false))
	down_button.selected.connect(func() -> void: _set_direction(true, true))
	up_button.moved.connect(move_direction)
	down_button.moved.connect(move_direction)
	return XpGroupBox.new("Direction", Ui.hbox([up_button, Ui.spacer(24), down_button]))


func _set_direction(_chosen: bool, down: bool) -> void:
	_down = down
	up_button.is_selected = not down
	down_button.is_selected = down


## The arrow keys in the Direction group select the neighbour and move focus to it.
func move_direction(step: int) -> void:
	_set_direction(true, step > 0)
	(down_button if step > 0 else up_button).grab_focus()


## The Replace dialog has no Direction group, so it always searches down. Otherwise an earlier
## Find upwards would make Replace search upwards with nothing on screen to say so.
func options() -> SearchOptions:
	return SearchOptions.new(
		find_box.text, match_case_box.value, whole_word_box.value, replace_mode or _down)


func find_next() -> void:
	if find_box.text.is_empty():
		return
	vm.find_next(options())


func replace_one() -> void:
	if find_box.text.is_empty():
		return
	vm.replace_current(options(), replace_box.text)


func replace_every() -> void:
	if find_box.text.is_empty():
		return
	vm.replace_all_matches(options(), replace_box.text)


func cancel() -> void:
	vm.close_find()


func focus_target() -> Control:
	return find_box
