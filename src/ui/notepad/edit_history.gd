class_name EditHistory
extends RefCounted
## The undo list of a document that is edited through a window of its lines. The window can
## move between two edits, so the list keeps each change as lines of the whole document, not as
## a step of the text control, which forgets when the window moves.
##
## One entry says: the lines [line, line + removed.size()) of the document were replaced by
## [member Entry.inserted], and are put back by undoing it. Typing and deleting one character
## at a time join into one entry when they follow each other closely, as the editor's own undo
## does.

## A change that is joined to the one before it adds or takes at most this many characters.
const JOINABLE_CHARACTERS := 64

var max_entries := 200
## Cap on the text the list holds. The oldest entries go first.
var max_characters := 16 * 1024 * 1024
## How soon after the last change the next one may be joined to it, in milliseconds.
var join_within_ms := 600
## Returns the time in milliseconds. Tests replace it.
var clock: Callable = Callable(Time, "get_ticks_msec")

var _entries: Array[Entry] = []
var _characters := 0


class Entry extends RefCounted:
	var line: int
	var removed: PackedStringArray
	var inserted: PackedStringArray
	## True for a change of the whole document: [member removed] and [member inserted] are all its
	## lines, and [member line] is 0.
	var whole := false
	var time_ms: int

	func characters() -> int:
		var total := 0
		for text in removed:
			total += text.length() + 1
		for text in inserted:
			total += text.length() + 1
		return total


func can_undo() -> bool:
	return not _entries.is_empty()


func size() -> int:
	return _entries.size()


## Records that [param removed] lines at [param line] were replaced by [param inserted].
func record(
		line: int, removed: PackedStringArray, inserted: PackedStringArray, whole: bool = false) -> void:
	if removed == inserted:
		return
	var now: int = clock.call()
	if not whole and not _entries.is_empty() and _try_join(line, removed, inserted, now):
		return
	var entry := Entry.new()
	entry.line = line
	entry.removed = removed
	entry.inserted = inserted
	entry.whole = whole
	entry.time_ms = now
	_entries.append(entry)
	_characters += entry.characters()
	_trim()


func _try_join(line: int, removed: PackedStringArray, inserted: PackedStringArray, now: int) -> bool:
	var last: Entry = _entries.back()
	if last.whole or now - last.time_ms > join_within_ms:
		return false
	# Only changes inside one line join, and only when this one starts from what the last one made.
	if last.removed.size() != 1 or last.inserted.size() != 1 \
			or removed.size() != 1 or inserted.size() != 1:
		return false
	if line != last.line or removed[0] != last.inserted[0]:
		return false
	var last_growth := last.inserted[0].length() - last.removed[0].length()
	var growth := inserted[0].length() - removed[0].length()
	# A run of typing, or a run of deleting, but not one then the other.
	if last_growth * growth <= 0 or absi(last_growth + growth) > JOINABLE_CHARACTERS:
		return false
	_characters -= last.characters()
	last.inserted = inserted
	last.time_ms = now
	_characters += last.characters()
	return true


## Takes the newest entry off the list and returns it, or null when there is none.
func take() -> Entry:
	if _entries.is_empty():
		return null
	var entry: Entry = _entries.pop_back()
	_characters -= entry.characters()
	return entry


func clear() -> void:
	_entries.clear()
	_characters = 0


func _trim() -> void:
	while _entries.size() > 1 and (_entries.size() > max_entries or _characters > max_characters):
		_characters -= _entries[0].characters()
		_entries.remove_at(0)
