extends TestCase
## Every script of the app must load. A script that does not compile is silently left out by
## the engine until something uses it, so this finds the ones nothing has used yet. The
## scripts are loaded as the app loads them, not again: a second copy of a class would
## replace the live one under the tests that follow.


func test_every_script_loads() -> void:
	var broken: Array[String] = []
	for path in _scripts("res://src"):
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			broken.append(path)
	assert_eq(broken, [], "scripts that do not compile")


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	var access := DirAccess.open(folder)
	if access == null:
		return found
	for file_name in access.get_files():
		if file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for sub in access.get_directories():
		found.append_array(_scripts(folder.path_join(sub)))
	return found
