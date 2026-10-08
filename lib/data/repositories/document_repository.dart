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
  const FileDocumentRepository({this.replaceFile = _renameOver});

  /// Moves a finished temporary file over the document. The default is the real rename.
  /// Tests replace it to fail the last step of a save.
  final Future<void> Function(File temporary, String path) replaceFile;

  static const _isolateThreshold = 512 * 1024;

  @override
  Future<Result<TextFile>> read(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final file = bytes.length > _isolateThreshold
          ? await Isolate.run(() => readText(bytes))
          : readText(bytes);
      return Success(file);
    } on FileSystemException catch (error, stack) {
      return Failure(error, stack);
    }
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
    } on FileSystemException catch (error, stack) {
      return Failure(error, stack);
    }
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
      await handle.writeFrom(bytes);
      await handle.flush();
      await handle.close();
      open = false;
      if (existing != null) await _copyMode(existing.mode, temporary);
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
  /// failure fails the save, so the file never silently changes its permissions.
  static Future<void> _copyMode(int mode, File file) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', [
      (mode & 0x1FF).toRadixString(8),
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException('Cannot keep the file permissions', file.path);
    }
  }
}
