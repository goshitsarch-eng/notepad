class_name FakeFileSystemService
extends FileSystemService
## A file system that is a few dictionaries.

## Paths of files that exist.
var existing: Dictionary = {}
## Every folder [method list_directory] was asked for, in order.
var listed: Array[String] = []
## Folders that exist, as [method directory_exists] reports them.
var directories: Dictionary = {}
## Folders whose listing fails as if they had been deleted.
var missing_directories: Dictionary = {}
## Folders that cannot be read, with the reason their listing fails with.
var unreadable: Dictionary = {}
## What [method list_directory] returns for a folder: an Array of [DirectoryEntry]. Folders not
## named here are empty.
var listings: Dictionary = {}


func home_directory() -> String:
	return "/home/tester"


func file_exists(path: String) -> bool:
	return existing.has(path)


func directory_exists(path: String) -> bool:
	return directories.has(path)


func list_directory(directory: String, _filter: FileTypeFilter) -> Result:
	listed.append(directory)
	if missing_directories.has(directory):
		return Result.failure(FileError.make(
			"No such file or directory", directory, FileError.Kind.NOT_FOUND,
			"No such file or directory"))
	if unreadable.has(directory):
		return Result.failure(FileError.make(unreadable[directory], directory))
	return Result.success(listings.get(directory, []))
