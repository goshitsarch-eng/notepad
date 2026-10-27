class_name LargeDocument
extends RefCounted
## A document too big for the engine's TextEdit to hold whole. TextEdit shapes every line it is
## given, which costs about 2 s and 280 MB for a megabyte of text, so a large document is edited
## through a window of its lines: the control holds the lines around what is on screen, a few
## hundred of them, and the rest wait in two stacks above and below it.
##
## The window moves as the view nears its edges, an undo list of its own survives the window
## moving, and everything else (save, Find, Replace All, Go To, the status bar) works on the whole
## document. The control shows the window, so the document's lines are numbered from the first
## line of the file and the control's lines from the first line of the window.

## The window is built about this big, in characters.
const WINDOW_CHARS := 100_000
## One step of moving the window.
const CHUNK_CHARS := 40_000
## Past this the end of the window farthest from the view is dropped.
const MAX_WINDOW_CHARS := 220_000
## The most lines a window holds, however short they are.
const MAX_WINDOW_LINES := 4000

enum Place { CARET, FIRST_VISIBLE, CENTER }

var edit: XpTextEdit
## The lines above the window, in order: the last one is next to the window.
var before := PackedStringArray()
## The lines below the window, in reverse order: the last one is next to the window.
var after := PackedStringArray()
## What the window held when it was last looked at, to tell what an edit changed.
var shadow := PackedStringArray()
## The document line number of the window's first line.
var win_start := 0
## Counts the edits, as the control's own version does for a small document.
var version := 0
var history := EditHistory.new()
## Where the caret is while it lies outside the window, as a Vector2i of document line and column,
## or null. A key typed then brings the window back to it first.
var virtual_caret: Variant = null
## A selection that may be bigger than the window, such as Select All: {"anchor", "caret"} as
## Vector2i document positions of line and column, or null.
var wide: Variant = null

var _syncing := 0
var _check_pending := false
var _cache := ""
var _cache_version := -1
var _cache_valid := false
## Counts the times the window was rebuilt, so a view position promised for one is not applied to
## the next.
var _generation := 0
## True from rebuilding the window until the view has been put where it belongs, which waits for
## the control to lay its new text out.
var _placing := false


func _init(control: XpTextEdit) -> void:
	edit = control


# ---- Building ----

## Starts over with [param lines] as the document, the window at [param start_line]. The control
## is given the lines that are in the window.
func build(
		lines: PackedStringArray, start_line: int = 0, start_column: int = 0,
		keep_history: bool = false) -> void:
	before = PackedStringArray()
	shadow = PackedStringArray()
	win_start = 0
	after = lines.duplicate()
	after.reverse()
	if not keep_history:
		history.clear()
	wide = null
	virtual_caret = null
	teleport(start_line, Place.CARET, Vector2i(start_line, start_column))


func total_lines() -> int:
	return before.size() + shadow.size() + after.size()


func line_at(document_line: int) -> String:
	if document_line < win_start:
		return before[document_line]
	var end := win_start + shadow.size()
	if document_line >= end:
		return after[after.size() - 1 - (document_line - end)]
	return shadow[document_line - win_start]


## The whole text. It is put together once and kept until the next edit, so Find Next on a big
## document does not do it again for every press.
func full_text() -> String:
	if _cache_version == version and _cache_valid:
		return _cache
	var parts := PackedStringArray()
	if not before.is_empty():
		parts.append("\n".join(before))
	parts.append(edit.get_text())
	if not after.is_empty():
		var below := after.duplicate()
		below.reverse()
		parts.append("\n".join(below))
	_cache = "\n".join(parts)
	_cache_version = version
	_cache_valid = true
	return _cache


func version_number() -> int:
	return version


# ---- Moving the window ----

## Moves the window to hold the lines around [param target_line], and puts the view as
## [param place] says. The caret stays where it was in the document, unless [param caret] gives
## another place for it.
func teleport(target_line: int, place: int = Place.CARET, caret: Variant = null) -> void:
	var keep: Vector2i = caret if caret != null else caret_document()
	var total := total_lines()
	var target := clampi(target_line, 0, maxi(total - 1, 0))
	# Every line above the target goes into `before`, and the target and all below it into `after`.
	before.append_array(shadow)
	shadow = PackedStringArray()
	if target < before.size():
		var moved := before.slice(target)
		moved.reverse()
		after.append_array(moved)
		before.resize(target)
	elif target > before.size():
		var count := target - before.size()
		var taken := after.slice(after.size() - count)
		taken.reverse()
		before.append_array(taken)
		after.resize(after.size() - count)
	# The window is some lines back from the target and some forward.
	var window := _take_back(WINDOW_CHARS / 3)
	win_start = before.size()
	window.append_array(_take_forward(WINDOW_CHARS * 2 / 3))
	shadow = window
	_set_window_text()
	var local := target - win_start
	match place:
		Place.FIRST_VISIBLE:
			edit.set_line_as_first_visible(local)
		Place.CENTER:
			edit.set_line_as_first_visible(maxi(local - 10, 0))
	set_caret_document(keep)
	_apply_wide()
	edit.document_changed.emit()
	_place_after_layout(target, place)


## The control works out how far it can scroll only when it has laid its new text out, so a view
## position asked for at once is cut short. It is asked for again after the next frame.
func _place_after_layout(target: int, place: int) -> void:
	_generation += 1
	var generation := _generation
	_placing = true
	if not edit.is_inside_tree():
		_placing = false
		return
	await edit.get_tree().process_frame
	if generation != _generation or not is_instance_valid(edit) or not edit.is_inside_tree():
		return
	_placing = false
	if shadow.is_empty():
		return
	if place == Place.FIRST_VISIBLE:
		edit.set_line_as_first_visible(clampi(target - win_start, 0, shadow.size() - 1))
	elif virtual_caret == null and place == Place.CENTER:
		edit.center_viewport_to_caret()
	elif virtual_caret == null:
		edit.adjust_viewport_to_caret()
	edit.document_changed.emit()
	_schedule_check()


## Takes lines from the end of `before`, about [param budget] characters of them, and returns them
## in order.
func _take_back(budget: int) -> PackedStringArray:
	var index := before.size()
	var chars := 0
	var count := 0
	while index > 0 and chars < budget and count < MAX_WINDOW_LINES / 3:
		index -= 1
		count += 1
		chars += before[index].length() + 1
	var lines := before.slice(index)
	before.resize(index)
	return lines


## Takes lines from the end of `after`, which are the lines just below the window, about
## [param budget] characters of them (and at least one), and returns them in order.
func _take_forward(budget: int) -> PackedStringArray:
	var index := after.size()
	var chars := 0
	var count := 0
	while index > 0 and (chars < budget or count < 1) and count < MAX_WINDOW_LINES * 2 / 3:
		index -= 1
		count += 1
		chars += after[index].length() + 1
	var lines := after.slice(index)
	lines.reverse()
	after.resize(index)
	return lines


func _set_window_text() -> void:
	_syncing += 1
	edit.text = "\n".join(shadow)
	edit.clear_undo_history()
	_syncing -= 1


## Makes sure the window holds the document lines [param first] to [param last], moving it if not.
func ensure_window(first: int, last: int) -> void:
	if first >= win_start and last < win_start + shadow.size():
		return
	teleport(first, Place.CENTER)


## Scrolls the view so that [param line] is the first one in it.
func scroll_to(line: int) -> void:
	var target := clampi(line, 0, maxi(total_lines() - 1, 0))
	var local := target - win_start
	var visible := _visible_lines()
	var low := 0 if before.is_empty() else _trigger()
	var high := 0 if after.is_empty() else _trigger()
	if local >= low and local + visible < shadow.size() - high:
		edit.set_line_as_first_visible(local)
		edit.document_changed.emit()
		_schedule_check()
	else:
		teleport(target, Place.FIRST_VISIBLE)


func _visible_lines() -> int:
	if not edit.is_inside_tree():
		return 20
	return maxi(edit.get_last_full_visible_line() - edit.get_first_visible_line() + 1, 5)


func _trigger() -> int:
	return maxi(60, _visible_lines() * 2)


## The scroll bar of the whole document: its position, its size, and what one page is.
func scroll_state() -> Dictionary:
	var first := edit.get_first_visible_line() if edit.is_inside_tree() else 0
	return {"value": win_start + first, "max": total_lines(), "page": _visible_lines()}


## The view scrolled. The window is looked at when things are quiet, not in the middle of it.
func on_scrolled() -> void:
	edit.document_changed.emit()
	_schedule_check()


func _schedule_check() -> void:
	if _check_pending:
		return
	_check_pending = true
	check_edges.call_deferred()


## Moves the window when the view is close to one of its edges, and drops the far end when it has
## grown too big.
func check_edges() -> void:
	_check_pending = false
	if not is_instance_valid(edit):
		return
	if _syncing > 0 or _placing or shadow.is_empty() or not edit.is_inside_tree():
		return
	edit.clear_undo_history()
	var first := edit.get_first_visible_line()
	var last := mini(edit.get_last_full_visible_line(), shadow.size() - 1)
	var trigger := _trigger()
	var moved := false
	if first < trigger and not before.is_empty():
		_extend_up()
		moved = true
	elif last > shadow.size() - 1 - trigger and not after.is_empty():
		_extend_down()
		moved = true
	if moved:
		_trim()
		_apply_wide()
		edit.document_changed.emit()


func _extend_up() -> void:
	var lines := _take_back(CHUNK_CHARS)
	if lines.is_empty():
		return
	var added := lines.size()
	var first := edit.get_first_visible_line()
	_syncing += 1
	edit.insert_text("\n".join(lines) + "\n", 0, 0)
	lines.append_array(shadow)
	shadow = lines
	win_start = before.size()
	edit.set_line_as_first_visible(first + added)
	_syncing -= 1


func _extend_down() -> void:
	var lines := _take_forward(CHUNK_CHARS)
	if lines.is_empty():
		return
	_syncing += 1
	var last := edit.get_line_count() - 1
	edit.insert_text("\n" + "\n".join(lines), last, edit.get_line(last).length())
	shadow.append_array(lines)
	_syncing -= 1


## Drops lines from whichever end of the window is farther from the view, while the window is too
## big, and keeping room beyond the view.
func _trim() -> void:
	var chars := 0
	for text in shadow:
		chars += text.length() + 1
	if chars <= MAX_WINDOW_CHARS and shadow.size() <= MAX_WINDOW_LINES:
		return
	var first := edit.get_first_visible_line()
	var last := mini(edit.get_last_full_visible_line(), shadow.size() - 1)
	var keep := _trigger() * 3
	var room_above := first - keep
	var room_below := shadow.size() - 1 - last - keep
	if room_above >= room_below and room_above > 0:
		_drop_top(_lines_to_drop_from_top(room_above, chars))
	elif room_below > 0:
		_drop_bottom(_lines_to_drop_from_bottom(room_below, chars))


func _lines_to_drop_from_top(room: int, chars: int) -> int:
	var dropped := 0
	var remaining := chars
	while dropped < room and (remaining > WINDOW_CHARS or shadow.size() - dropped > MAX_WINDOW_LINES / 2):
		remaining -= shadow[dropped].length() + 1
		dropped += 1
	return dropped


func _lines_to_drop_from_bottom(room: int, chars: int) -> int:
	var dropped := 0
	var remaining := chars
	while dropped < room and (remaining > WINDOW_CHARS or shadow.size() - dropped > MAX_WINDOW_LINES / 2):
		remaining -= shadow[shadow.size() - 1 - dropped].length() + 1
		dropped += 1
	return dropped


func _drop_top(count: int) -> void:
	if count <= 0 or count >= shadow.size():
		return
	var caret := caret_document()
	var first := edit.get_first_visible_line()
	before.append_array(shadow.slice(0, count))
	_syncing += 1
	edit.remove_text(0, 0, count, 0)
	shadow = shadow.slice(count)
	win_start += count
	edit.set_line_as_first_visible(maxi(first - count, 0))
	_syncing -= 1
	set_caret_document(caret)


func _drop_bottom(count: int) -> void:
	var n := shadow.size()
	if count <= 0 or count >= n:
		return
	var caret := caret_document()
	var moved := shadow.slice(n - count)
	moved.reverse()
	after.append_array(moved)
	_syncing += 1
	edit.remove_text(n - count - 1, edit.get_line(n - count - 1).length(), n - 1, edit.get_line(n - 1).length())
	shadow.resize(n - count)
	_syncing -= 1
	set_caret_document(caret)


# ---- Keeping up with edits ----

## Called for each edit of the control, with the lines it touched. The edit is written into the
## shadow of the window, and into the undo list.
func on_edited(from_line: int, to_line: int) -> void:
	if _syncing > 0:
		return
	var count := edit.get_line_count()
	var delta := count - shadow.size()
	var old_lo: int
	var old_hi: int
	var new_lo: int
	var new_hi: int
	if to_line >= from_line and to_line - from_line == delta:
		old_lo = from_line
		old_hi = from_line
		new_lo = from_line
		new_hi = to_line
	elif to_line < from_line and to_line - from_line == delta:
		old_lo = to_line
		old_hi = from_line
		new_lo = to_line
		new_hi = to_line
	else:
		# What the control did is not what was expected, so the window is read again whole.
		old_lo = 0
		old_hi = shadow.size() - 1
		new_lo = 0
		new_hi = count - 1
	old_hi = mini(old_hi, shadow.size() - 1)
	var removed := shadow.slice(old_lo, old_hi + 1)
	var inserted := PackedStringArray()
	for index in range(new_lo, new_hi + 1):
		inserted.append(edit.get_line(index))
	var head := shadow.slice(0, old_lo)
	head.append_array(inserted)
	head.append_array(shadow.slice(old_hi + 1))
	shadow = head
	version += 1
	history.record(win_start + old_lo, removed, inserted)
	wide = null
	virtual_caret = null
	_schedule_check()
	edit.document_changed.emit()


func can_undo() -> bool:
	return history.can_undo()


func undo() -> void:
	var entry := history.take()
	if entry == null:
		return
	restore_caret()
	if entry.whole:
		var caret_line := entry.line
		build(entry.removed, caret_line, 0, true)
		version += 1
		return
	var count := entry.inserted.size()
	ensure_window(entry.line, entry.line + count - 1)
	var local := entry.line - win_start
	_syncing += 1
	edit.remove_text(local, 0, local + count - 1, edit.get_line(local + count - 1).length())
	edit.insert_text("\n".join(entry.removed), local, 0)
	var head := shadow.slice(0, local)
	head.append_array(entry.removed)
	head.append_array(shadow.slice(local + count))
	shadow = head
	_syncing -= 1
	version += 1
	# The caret goes to where the two versions of the line first differ, which is where the
	# change was made.
	var column := 0
	var restored: String = entry.removed[0]
	var undone: String = entry.inserted[0]
	while column < restored.length() and column < undone.length() and restored[column] == undone[column]:
		column += 1
	edit.deselect()
	edit.set_caret_line(local)
	edit.set_caret_column(mini(column, edit.get_line(local).length()))
	edit.adjust_viewport_to_caret()
	wide = null
	virtual_caret = null
	_schedule_check()
	edit.document_changed.emit()


# ---- Caret and selection ----

## The caret's place in the document, as a Vector2i of line and column.
func caret_document() -> Vector2i:
	if virtual_caret != null:
		return virtual_caret
	if shadow.is_empty():
		return Vector2i.ZERO
	return Vector2i(win_start + edit.get_caret_line(), edit.get_caret_column())


## Puts the caret at [param position] of the document. When that is outside the window, the control's
## caret goes to the nearest end of the window and the real place is remembered.
func set_caret_document(position: Vector2i) -> void:
	var local := position.x - win_start
	if local >= 0 and local < shadow.size():
		edit.set_caret_line(local)
		edit.set_caret_column(mini(position.y, edit.get_line(local).length()))
		virtual_caret = null
		return
	virtual_caret = position
	if local < 0:
		edit.set_caret_line(0)
		edit.set_caret_column(0)
	else:
		var last := edit.get_line_count() - 1
		edit.set_caret_line(last)
		edit.set_caret_column(edit.get_line(last).length())


## Brings the window back to the caret, when the view has been scrolled away from it.
func restore_caret() -> void:
	if virtual_caret == null:
		return
	var position: Vector2i = virtual_caret
	teleport(position.x, Place.CENTER, position)


## Selects from [param from] to [param to], two document positions, with the caret at the end, and
## scrolls them into view.
func select_range(from: Vector2i, to: Vector2i) -> void:
	wide = null
	ensure_window(from.x, to.x)
	var first_line := from.x - win_start
	var last_line := to.x - win_start
	last_line = mini(last_line, shadow.size() - 1)
	edit.select(first_line, mini(from.y, edit.get_line(first_line).length()),
		last_line, mini(to.y, edit.get_line(last_line).length()))
	virtual_caret = null
	edit.set_caret_line(last_line)
	edit.set_caret_column(mini(to.y, edit.get_line(last_line).length()))
	edit.adjust_viewport_to_caret()


## Puts the caret at the start of document line [param line] and shows it.
func go_to(line: int) -> void:
	wide = null
	var target := clampi(line, 0, total_lines() - 1)
	ensure_window(target, target)
	edit.deselect()
	virtual_caret = null
	edit.set_caret_line(target - win_start)
	edit.set_caret_column(0)
	edit.adjust_viewport_to_caret()


## The last position of the document.
func end_position() -> Vector2i:
	var last := total_lines() - 1
	return Vector2i(last, line_at(last).length())


## Selects the whole document.
func select_all() -> void:
	set_wide(Vector2i.ZERO, end_position())


## A selection from [param anchor] to [param caret] that may be bigger than the window. The window
## goes to the caret.
func set_wide(anchor: Vector2i, caret: Vector2i) -> void:
	wide = {"anchor": anchor, "caret": caret}
	ensure_window(caret.x, caret.x)
	virtual_caret = null
	_apply_wide()
	edit.document_changed.emit()


func clear_wide() -> void:
	wide = null


## Shows as much of the wide selection as the window holds.
func _apply_wide() -> void:
	if wide == null or shadow.is_empty():
		return
	var from: Vector2i = wide["anchor"]
	var to: Vector2i = wide["caret"]
	if _after(from, to):
		var swapped := from
		from = to
		to = swapped
	var window_end := Vector2i(win_start + shadow.size() - 1, shadow[shadow.size() - 1].length())
	if _after(Vector2i(win_start, 0), to) or _after(from, window_end):
		edit.deselect()
		return
	if _after(Vector2i(win_start, 0), from):
		from = Vector2i(win_start, 0)
	if _after(to, window_end):
		to = window_end
	edit.select(from.x - win_start, from.y, to.x - win_start, to.y)
	var caret: Vector2i = wide["caret"]
	if caret.x - win_start >= 0 and caret.x - win_start < shadow.size():
		edit.set_caret_line(caret.x - win_start)
		edit.set_caret_column(mini(caret.y, edit.get_line(caret.x - win_start).length()))


## True when position [param a] is after position [param b].
static func _after(a: Vector2i, b: Vector2i) -> bool:
	return a.x > b.x or (a.x == b.x and a.y > b.y)


## Replaces the wide selection, or the whole document, by [param value], as one entry of the undo
## list when it is not too big. Returns nothing; the caret goes after the new text.
func replace_range(from: Vector2i, to: Vector2i, value: String) -> void:
	var full := full_text()
	var start := XpTextEdit.offset_of(full, from.x, from.y)
	var end := XpTextEdit.offset_of(full, to.x, to.y)
	var old_lines := full.split("\n")
	var combined := full.substr(0, start) + value + full.substr(end)
	var new_lines := combined.split("\n")
	var caret_offset := start + value.length()
	var caret := XpTextEdit.position_of(combined, caret_offset)
	var fits := full.length() + combined.length() <= history.max_characters
	build(new_lines, caret.x, caret.y, true)
	if fits:
		history.record(0, old_lines, new_lines, true)
	else:
		history.clear()
	version += 1
	edit.center_viewport_to_caret()
	edit.document_changed.emit()
