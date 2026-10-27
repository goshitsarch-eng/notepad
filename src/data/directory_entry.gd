class_name DirectoryEntry
extends RefCounted
## One row in the Open or Save As file list.

var name: String
var path: String
var is_directory: bool
var size: int
## Seconds since the epoch, in the local time zone's own terms: see [member modified_moment].
var modified_unix: int


func _init(
		entry_name: String = "", entry_path: String = "", entry_is_directory: bool = false,
		entry_size: int = 0, entry_modified_unix: int = 0) -> void:
	name = entry_name
	path = entry_path
	is_directory = entry_is_directory
	size = entry_size
	modified_unix = entry_modified_unix


## The modification time as a local datetime dictionary, for display.
func modified_moment() -> Dictionary:
	var offset: int = Time.get_time_zone_from_system().get("bias", 0) * 60
	return Time.get_datetime_dict_from_unix_time(modified_unix + offset)
