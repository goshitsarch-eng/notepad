extends SceneTree
## Measures editing a large document in the real window, for the README's table:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/bench_large.gd -- --mb=5 [--nowrap]
## It builds a text of about the given size in megabytes, shows it, and times the load, one
## typed character (the edit and the frame that draws it), a jump to the end, and Select All.

var _megabytes := 1
var _wrap := true


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mb="):
			_megabytes = int(argument.substr(5))
		elif argument == "--nowrap":
			_wrap = false
	_run()


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _run() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var vm: NotepadViewModel = main.view_model
	if not _wrap:
		vm.toggle_word_wrap()
	await _frames(3)

	var line := "The quick brown fox jumps over the lazy dog, 0123456789. Pack my box with five dozen liquor jugs.\n"
	var count := int(_megabytes * 1024 * 1024 / line.length())
	var text := line.repeat(count)
	var started_memory := OS.get_static_memory_usage()
	print("document: %d MB, %d lines, %d characters, word wrap %s" % [_megabytes, count, text.length(), _wrap])

	var started := Time.get_ticks_usec()
	vm.text.load_document(text)
	var loaded := Time.get_ticks_usec()
	await _frames(2)
	var shown := Time.get_ticks_usec()
	print("load into the editor: %.0f ms, first frame after: %.0f ms" % [
		(loaded - started) / 1000.0, (shown - loaded) / 1000.0])
	print("memory (static): %.0f MB" % (OS.get_static_memory_usage() / 1048576.0))

	# One typed character in the middle of the document, and the frame that follows.
	vm.text.go_to_document_line(count / 2)
	await _frames(3)
	vm.text.set_caret_column(10)
	var samples: Array[float] = []
	for _round in range(8):
		var begin := Time.get_ticks_usec()
		vm.text.insert_text_at_caret("x")
		await process_frame
		await process_frame
		samples.append((Time.get_ticks_usec() - begin) / 1000.0)
	samples.sort()
	print("one typed character + frames: median %.1f ms, worst %.1f ms" % [samples[samples.size() / 2], samples[-1]])

	var begin := Time.get_ticks_usec()
	vm.text.go_to_document_line(count)
	await _frames(3)
	print("jump to the end + frames: %.0f ms" % ((Time.get_ticks_usec() - begin) / 1000.0))

	begin = Time.get_ticks_usec()
	vm.text.go_to_document_line(1)
	await _frames(3)
	print("jump to the start + frames: %.0f ms" % ((Time.get_ticks_usec() - begin) / 1000.0))

	begin = Time.get_ticks_usec()
	vm.text.select_all_document()
	await _frames(3)
	print("select all + frames: %.0f ms" % ((Time.get_ticks_usec() - begin) / 1000.0))

	begin = Time.get_ticks_usec()
	var whole := vm.text.document_text()
	print("whole text (what Save, Print and Find do): %.0f ms (%d characters)" % [
		(Time.get_ticks_usec() - begin) / 1000.0, whole.length()])
	quit()
