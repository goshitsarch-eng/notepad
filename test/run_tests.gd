extends SceneTree
## Runs every test file under res://test, or the ones chosen on the command line:
##   godot --headless --path . -s test/run_tests.gd -- [--filter=text] [--file=name] [--list]
## --filter keeps the tests whose "file:test" name contains the text; --file keeps one file.
## The exit code is 1 when a test failed, and 0 when all passed.

var _filter := ""
var _only_file := ""
var _list_only := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--filter="):
			_filter = argument.substr(9)
		elif argument.begins_with("--file="):
			_only_file = argument.substr(7)
		elif argument == "--list":
			_list_only = true
	_run()


func _run() -> void:
	var files := _find_test_files("res://test")
	files.sort()
	var passed := 0
	var failed := 0
	var skipped := 0
	var failed_names: Array[String] = []
	for path in files:
		var file_name: String = path.get_file().get_basename()
		if not _only_file.is_empty() and not file_name.contains(_only_file):
			continue
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL  %s: the script does not load" % file_name)
			failed += 1
			failed_names.append(file_name)
			continue
		var tests: Array[String] = []
		for method in script.get_script_method_list():
			if str(method.name).begins_with("test_"):
				tests.append(method.name)
		tests.sort()
		for test_name in tests:
			var full_name := "%s:%s" % [file_name, test_name]
			if not _filter.is_empty() and not full_name.contains(_filter):
				continue
			if _list_only:
				print(full_name)
				continue
			var test_case: TestCase = script.new()
			test_case.tree = self
			await test_case.before_each()
			await test_case.call(test_name)
			await test_case.after_each()
			test_case.cleanup_files()
			if not test_case.skipped_reason.is_empty():
				skipped += 1
				print("SKIP  %s (%s)" % [full_name, test_case.skipped_reason])
			elif test_case.failures.is_empty():
				passed += 1
				print("PASS  %s" % full_name)
			else:
				failed += 1
				failed_names.append(full_name)
				print("FAIL  %s" % full_name)
				for message in test_case.failures:
					print("        " + message.replace("\n", "\n        "))
	if _list_only:
		quit(0)
		return
	print("")
	print("%d passed, %d failed, %d skipped" % [passed, failed, skipped])
	if failed > 0:
		print("Failed:")
		for name in failed_names:
			print("  " + name)
	quit(1 if failed > 0 else 0)


func _find_test_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	var access := DirAccess.open(folder)
	if access == null:
		return found
	for file_name in access.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for sub in access.get_directories():
		if sub != "support":
			found.append_array(_find_test_files(folder.path_join(sub)))
	return found
