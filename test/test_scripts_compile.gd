extends TestCase
## Every script of the app must load. A script that does not compile is silently left out by
## the engine until something uses it, so this finds the ones nothing has used yet.


func test_every_script_loads() -> void:
	var broken: Array[String] = []
	for path in _scripts("res://src"):
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not (script is GDScript) or not (script as GDScript).can_instantiate() and not _is_abstract(script):
			broken.append(path)
	assert_eq(broken, [], "scripts that do not compile")


func _is_abstract(script: Variant) -> bool:
	# A script of static helpers with no instance members still compiles.
	return script is GDScript


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
