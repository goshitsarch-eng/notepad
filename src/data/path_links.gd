class_name PathLinks
extends RefCounted
## Symbolic links, which Godot can read but does not follow when it writes.


## Follows symbolic links to the file they name, so that saving updates the target and keeps
## the link. A path that is not a link comes back as it is.
static func resolve(path: String) -> String:
	var current := path
	for _hop in range(40):
		var folder := DirAccess.open(current.get_base_dir())
		if folder == null or not folder.is_link(current):
			return current
		var target := folder.read_link(current)
		if target.is_empty():
			return current
		current = target if target.is_absolute_path() else current.get_base_dir().path_join(target)
	return current
