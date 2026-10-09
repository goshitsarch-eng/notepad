import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/utils/result.dart';

/// Source of truth for documents on disk.
abstract interface class DocumentRepository {
  Future<Result<TextFile>> read(String path);

  Future<Result<void>> write(String path, String text, FileEncoding encoding);
}

/// Reads and writes documents with dart:io. Large files are converted in a background
/// isolate so that typing and painting stay smooth, as the performance guide suggests.
class FileDocumentRepository implements DocumentRepository {
  const FileDocumentRepository({
    this.replaceFile = _renameOver,
    this.maximumBytes = defaultMaximumBytes,
  });

  /// Moves a finished temporary file over the document. The default is the real rename.
  /// Tests replace it to fail the last step of a save.
  final Future<void> Function(File temporary, String path) replaceFile;

  static const _isolateThreshold = 512 * 1024;

  /// The largest file Notepad opens by default. The editor lays out the whole text, so a
  /// bigger file would freeze the window or exhaust memory long before it was usable. The
  /// limit is enforced while reading, so it also stops a device such as /dev/zero, which
  /// reports no size, and a file that grows while it is read.
  static const defaultMaximumBytes = 64 * 1024 * 1024;

  /// The limit this repository applies. Tests lower it to avoid writing huge files.
  final int maximumBytes;

  @override
  Future<Result<TextFile>> read(String path) async {
    try {
      final bytes = await _readBounded(path);
      final file = bytes.length > _isolateThreshold
          ? await Isolate.run(() => readText(bytes))
          : readText(bytes);
      return Success(file);
    } on Exception catch (error, stack) {
      return Failure(error, stack);
    }
  }

  /// Reads [path] in chunks and gives up once it passes [maximumBytes]. A folder, a
  /// named pipe or a socket is refused before reading: opening a pipe would wait for a
  /// writer for ever.
  Future<Uint8List> _readBounded(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.directory) {
      throw FileSystemException('This is a folder, not a file', path);
    }
    if (type == FileSystemEntityType.pipe ||
        type == FileSystemEntityType.unixDomainSock) {
      throw FileSystemException('This is not a regular file', path);
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in File(path).openRead()) {
      total += chunk.length;
      if (total > maximumBytes) {
        throw FileSystemException(
          'The file is too large. Notepad opens files up to '
          '${_describeSize(maximumBytes)}',
          path,
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Future<Result<void>> write(
    String path,
    String text,
    FileEncoding encoding,
  ) async {
    try {
      final bytes = text.length > _isolateThreshold
          ? await Isolate.run(() => encodeText(text, encoding))
          : encodeText(text, encoding);
      await _save(path, bytes);
      return const Success<void>(null);
    } on Exception catch (error, stack) {
      return Failure(error, stack);
    }
  }

  static String _describeSize(int bytes) {
    const megabyte = 1024 * 1024;
    return bytes >= megabyte ? '${bytes ~/ megabyte} MB' : '$bytes bytes';
  }

  /// Writes [bytes] to a temporary file beside the document, then moves it over the
  /// document. An interrupted save therefore leaves either the old file or the new one,
  /// never a truncated mix, and the temporary file is removed when a step fails.
  ///
  /// Symbolic links are followed, so the link itself is kept. On POSIX systems the
  /// permission bits of the old file are copied to the new one. A document that is
  /// read-only is still refused, as before. A folder that cannot take a temporary file
  /// gets the bytes written in place, which is the only case that is not atomic.
  Future<void> _save(String path, Uint8List bytes) async {
    final target = await _resolve(path);
    final existing = await target.exists() ? await target.stat() : null;
    if (existing != null) {
      // Opening for append changes nothing, but fails on a read-only file.
      (await target.open(mode: FileMode.append)).closeSync();
    }

    final temporary = File(
      p.join(
        p.dirname(target.path),
        '.${p.basename(target.path)}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    final RandomAccessFile handle;
    try {
      handle = await temporary.open(mode: FileMode.writeOnly);
    } on FileSystemException {
      await target.writeAsBytes(bytes, flush: true);
      return;
    }
    var open = true;
    try {
      // The permissions are set while the file is still empty, so a private document
      // never has its text sitting in a file that other users can read.
      if (existing != null) await _copyMode(existing.mode, temporary);
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      open = false;
      await replaceFile(temporary, target.path);
    } on Object {
      if (open) await handle.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<File> _resolve(String path) async {
    final file = File(path);
    if (await file.exists()) return File(await file.resolveSymbolicLinks());
    return file;
  }

  static Future<void> _renameOver(File temporary, String path) async {
    await temporary.rename(path);
  }

  /// Copies the POSIX permission bits, which Dart cannot set itself, with chmod. A
  /// failure fails the save, so the file never silently changes its permissions. The
  /// `--` comes before the mode, where strict option parsing (BSD and POSIXLY_CORRECT)
  /// needs it, and keeps a folder name that starts with a dash from being read as an
  /// option.
  static Future<void> _copyMode(int mode, File file) async {
    if (Platform.isWindows) return;
    final ProcessResult result;
    try {
      result = await Process.run('chmod', [
        '--',
        (mode & 0x1FF).toRadixString(8),
        file.path,
      ]);
    } on ProcessException {
      throw FileSystemException('Cannot keep the file permissions', file.path);
    }
    if (result.exitCode != 0) {
      throw FileSystemException('Cannot keep the file permissions', file.path);
    }
  }
}
