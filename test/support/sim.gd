class_name Sim
extends RefCounted
## Simulated input for the tests of the window. Events go through the window's whole input path,
## as the operating system's would: the screen's own key handling, then the focused control.
##   await Sim.key(tree, KEY_F, {"alt": true})
##   await Sim.click(tree, Vector2(30, 40))

## Presses and releases [param keycode]. [param mods] may hold "ctrl", "alt", "shift" and "meta",
## and "text" for the character the key types.
static func key(tree: SceneTree, keycode: int, mods: Dictionary = {}) -> void:
	await key_down(tree, keycode, mods)
	await key_up(tree, keycode, mods)


static func key_down(tree: SceneTree, keycode: int, mods: Dictionary = {}) -> void:
	tree.root.push_input(_key_event(keycode, mods, true), true)
	await tree.process_frame


static func key_up(tree: SceneTree, keycode: int, mods: Dictionary = {}) -> void:
	tree.root.push_input(_key_event(keycode, mods, false), true)
	await tree.process_frame


## Types [param content] one character at a time, as a keyboard would.
static func type(tree: SceneTree, content: String) -> void:
	for index in range(content.length()):
		var character := content[index]
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		event.keycode = _keycode_of(character)
		event.physical_keycode = event.keycode
		tree.root.push_input(event, true)
		var release := event.duplicate() as InputEventKey
		release.pressed = false
		tree.root.push_input(release, true)
	await tree.process_frame


## Moves the pointer to [param position], in window coordinates.
static func move(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	tree.root.push_input(event, true)
	await tree.process_frame


## Presses and releases a mouse button at [param position].
static func click(tree: SceneTree, position: Vector2, button: int = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	await move(tree, position)
	await press(tree, position, button, double)
	await release(tree, position, button)


static func press(tree: SceneTree, position: Vector2, button: int = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.button_mask = 1 << (button - 1)
	event.pressed = true
	event.double_click = double
	tree.root.push_input(event, true)
	await tree.process_frame


static func release(tree: SceneTree, position: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = false
	tree.root.push_input(event, true)
	await tree.process_frame


## The centre of [param control], in window coordinates.
static func center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


static func _key_event(keycode: int, mods: Dictionary, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.ctrl_pressed = mods.get("ctrl", false)
	event.alt_pressed = mods.get("alt", false)
	event.shift_pressed = mods.get("shift", false)
	event.meta_pressed = mods.get("meta", false)
	if mods.has("text"):
		event.unicode = String(mods["text"]).unicode_at(0)
	return event


static func _keycode_of(character: String) -> int:
	var upper := character.to_upper()
	var code := upper.unicode_at(0)
	if code >= KEY_A and code <= KEY_Z or code >= KEY_0 and code <= KEY_9 or character == " ":
		return code
	return KEY_NONE
