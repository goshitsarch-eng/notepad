import 'dart:io';

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

  /// Folders first, then matching files, each sorted by name. Hidden entries are skipped.
  Future<List<DirectoryEntry>> listDirectory(
    String directory,
    FileTypeFilter filter,
  );
}

class LocalFileSystemService implements FileSystemService {
  const LocalFileSystemService();

  @override
  String get homeDirectory {
    final env = Platform.environment;
    return env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
  }

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<List<DirectoryEntry>> listDirectory(
    String directory,
    FileTypeFilter filter,
  ) async {
    final folders = <DirectoryEntry>[];
    final files = <DirectoryEntry>[];
    try {
      await for (final entity in Directory(
        directory,
      ).list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        final stat = await entity.stat();
        if (stat.type == FileSystemEntityType.directory) {
          folders.add(
            DirectoryEntry(
              name: name,
              path: entity.path,
              isDirectory: true,
              size: 0,
              modified: stat.modified,
            ),
          );
        } else if (stat.type == FileSystemEntityType.file &&
            filter.matches(name)) {
          files.add(
            DirectoryEntry(
              name: name,
              path: entity.path,
              isDirectory: false,
              size: stat.size,
              modified: stat.modified,
            ),
          );
        }
      }
    } on FileSystemException {
      return const [];
    }
    int byName(DirectoryEntry a, DirectoryEntry b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    folders.sort(byName);
    files.sort(byName);
    return [...folders, ...files];
  }
}
