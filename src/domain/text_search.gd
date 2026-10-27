class_name TextSearch
extends RefCounted
## Plain-text search with XP's Find options.

static var _word_character: RegEx


## Finds the next match, or the previous one when [member SearchOptions.forward] is false.
## Forward searches look at or after [param from]; backward searches end at or before it.
## Like XP Notepad, the search stops at the ends of the document and does not wrap. Returns
## null when nothing matches.
static func find(text: String, options: SearchOptions, from: int) -> MatchRange:
	if options.query.is_empty():
		return null
	var start := mini(maxi(from, 0), text.length())
	var length := options.query.length()
	if options.forward:
		var position := start
		while true:
			var index := _index_of(text, options, position)
			if index < 0:
				return null
			if _is_acceptable(text, index, index + length, options):
				return MatchRange.new(index, index + length)
			position = index + length
		return null
	var previous: MatchRange = null
	var position := 0
	while true:
		var index := _index_of(text, options, position)
		if index < 0 or index + length > start:
			break
		if _is_acceptable(text, index, index + length, options):
			previous = MatchRange.new(index, index + length)
		position = index + length
	return previous


## Replaces every acceptable match in [param text] with [param replacement].
static func replace_all(text: String, options: SearchOptions, replacement: String) -> ReplaceAllResult:
	if options.query.is_empty():
		return ReplaceAllResult.new(text, 0)
	var length := options.query.length()
	var parts := PackedStringArray()
	var copied_up_to := 0
	var count := 0
	var position := 0
	while true:
		var index := _index_of(text, options, position)
		if index < 0:
			break
		position = index + length
		if not _is_acceptable(text, index, index + length, options):
			continue
		parts.append(text.substr(copied_up_to, index - copied_up_to))
		parts.append(replacement)
		copied_up_to = index + length
		count += 1
	if count == 0:
		return ReplaceAllResult.new(text, 0)
	parts.append(text.substr(copied_up_to))
	return ReplaceAllResult.new("".join(parts), count)


static func _index_of(text: String, options: SearchOptions, from: int) -> int:
	if options.match_case:
		return text.find(options.query, from)
	return text.findn(options.query, from)


static func _is_acceptable(text: String, start: int, end: int, options: SearchOptions) -> bool:
	if not options.whole_word:
		return true
	var before := start > 0 and _is_word_character(text[start - 1])
	var after := end < text.length() and _is_word_character(text[end])
	return not before and not after


static func _is_word_character(character: String) -> bool:
	if _word_character == null:
		_word_character = RegEx.create_from_string("^[\\p{L}\\p{N}_]$")
	return _word_character.search(character) != null
