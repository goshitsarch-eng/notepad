import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:xp_notepad/domain/models/file_filter.dart';

/// One row in the Open or Save As file list.
class DirectoryEntry {
  const DirectoryEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;
}

/// Access to folders for the file dialogs.
abstract interface class FileSystemService {
  String get homeDirectory;

  Future<bool> fileExists(String path);

  Future<bool> directoryExists(String path);

  /// Folders first, then matching files, each sorted by name. Hidden entries are skipped,
  /// and so is any single entry that cannot be read. Throws [FileSystemException] when the
  /// folder itself cannot be listed, so the dialog can say why instead of showing nothing.
  Future<List<DirectoryEntry>> listDirectory(
    String directory,
    FileTypeFilter filter,
  );
}

class LocalFileSystemService implements FileSystemService {
  const LocalFileSystemService();

  /// How many entries are examined at once. Folders with many files are listed much
  /// faster than one entry at a time, without opening a flood of requests.
  static const _statBatch = 64;

  @override
  String get homeDirectory {
    final env = Platform.environment;
    // An empty variable counts as unset: a start folder of '' lists the wrong place.
    for (final name in const ['USERPROFILE', 'HOME']) {
      final value = env[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return Directory.current.path;
  }

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<List<DirectoryEntry>> listDirectory(
    String directory,
    FileTypeFilter filter,
  ) async {
    final candidates = <FileSystemEntity>[];
    await for (final entity in Directory(directory).list(followLinks: false)) {
      if (!p.basename(entity.path).startsWith('.')) candidates.add(entity);
    }
    final folders = <DirectoryEntry>[];
    final files = <DirectoryEntry>[];
    var examined = 0;
    FileSystemException? firstFailure;
    var failures = 0;
    for (var start = 0; start < candidates.length; start += _statBatch) {
      final end = math.min(start + _statBatch, candidates.length);
      final batch = await Future.wait([
        for (final entity in candidates.sublist(start, end))
          _entryFor(entity, filter),
      ]);
      for (final result in batch) {
        if (!result.examined) continue;
        examined++;
        final failure = result.failure;
        if (failure != null) {
          failures++;
          firstFailure ??= failure;
        }
        final entry = result.entry;
        if (entry != null) (entry.isDirectory ? folders : files).add(entry);
      }
    }
    // A folder whose names can be read but whose entries cannot be examined at all, such
    // as one without the search permission, is not empty. Say so, as for a folder that
    // cannot be listed. A single bad entry among good ones is skipped quietly.
    if (firstFailure != null && failures == examined) throw firstFailure;
    // Sort on a lower-cased name made once per entry, not once per comparison.
    List<DirectoryEntry> sorted(List<DirectoryEntry> entries) {
      final keyed = [
        for (final entry in entries) (entry.name.toLowerCase(), entry),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final (_, entry) in keyed) entry];
    }

    return [...sorted(folders), ...sorted(files)];
  }

  /// The row for [entity], or none when it is not a folder or a matching file. A link
  /// whose target is gone has nothing to show and is left out. [examined] is false when
  /// the entry was ruled out without a system call, and [failure] is set when the call
  /// itself failed.
  static Future<
    ({DirectoryEntry? entry, bool examined, FileSystemException? failure})
  >
  _entryFor(FileSystemEntity entity, FileTypeFilter filter) async {
    final name = p.basename(entity.path);
    // The listing already tells files from folders, so a file the filter hides needs no
    // further system call.
    if (entity is File && !filter.matches(name)) {
      return (entry: null, examined: false, failure: null);
    }
    try {
      final stat = await entity.stat();
      // stat does not throw: a failure comes back as "not found". The listing has just
      // shown this entry to exist, so for anything but a link (whose target may be gone)
      // that means it cannot be examined, most often for want of the search permission.
      if (stat.type == FileSystemEntityType.notFound && entity is! Link) {
        return (
          entry: null,
          examined: true,
          failure: FileSystemException(
            "Its entries cannot be examined. Check the folder's permissions",
            entity.path,
          ),
        );
      }
      if (stat.type == FileSystemEntityType.directory) {
        return (
          entry: DirectoryEntry(
            name: name,
            path: entity.path,
            isDirectory: true,
            size: 0,
            modified: stat.modified,
          ),
          examined: true,
          failure: null,
        );
      }
      if (stat.type == FileSystemEntityType.file && filter.matches(name)) {
        return (
          entry: DirectoryEntry(
            name: name,
            path: entity.path,
            isDirectory: false,
            size: stat.size,
            modified: stat.modified,
          ),
          examined: true,
          failure: null,
        );
      }
      return (entry: null, examined: true, failure: null);
    } on FileSystemException catch (error) {
      return (entry: null, examined: true, failure: error);
    }
  }
}
