import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/utils/result.dart';

/// Saves go through [FileDocumentRepository.write]. These tests use real files in a
/// temporary folder, because the point is what the file system ends up holding.
void main() {
  const repository = FileDocumentRepository();
  late Directory folder;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('xp_notepad_save_');
  });

  tearDown(() {
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['-R', 'u+rwx', folder.path]);
    }
    folder.deleteSync(recursive: true);
  });

  /// Names of everything in the folder, including hidden entries.
  List<String> names() {
    final list = folder.listSync().map(
      (e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last,
    );
    return list.toList()..sort();
  }

  String textOf(String path) => readText(File(path).readAsBytesSync()).text;

  test(
    'a new file gets its text and no temporary file is left behind',
    () async {
      final path = '${folder.path}/a.txt';

      final result = await repository.write(
        path,
        'Hello\nWorld',
        FileEncoding.utf8,
      );

      expect(result, isA<Success<void>>());
      expect(textOf(path), 'Hello\nWorld');
      expect(names(), ['a.txt']);
    },
  );

  test(
    'saving over a file replaces its text and leaves no temporary file behind',
    () async {
      final path = '${folder.path}/a.txt';
      await repository.write(path, 'one', FileEncoding.ansi);

      await repository.write(path, 'two', FileEncoding.ansi);

      expect(textOf(path), 'two');
      expect(names(), ['a.txt']);
    },
  );

  test('a save that fails at the last step leaves the old text and no temporary file', () async {
    final path = '${folder.path}/a.txt';
    await repository.write(path, 'original', FileEncoding.ansi);
    const failing = FileDocumentRepository(replaceFile: _failReplace);

    final result = await failing.write(path, 'changed', FileEncoding.ansi);

    expect(result, isA<Failure<void>>());
    expect(textOf(path), 'original');
    expect(names(), ['a.txt']);
  });

  test(
    'a save that cannot write the file fails and leaves the old text',
    () async {
      if (Platform.isWindows) {
        markTestSkipped(
          'read-only attributes are checked here on POSIX systems only',
        );
        return;
      }
      final path = '${folder.path}/a.txt';
      await repository.write(path, 'original', FileEncoding.ansi);
      Process.runSync('chmod', ['444', path]);
      final canWriteAnyway = _canOpenForWriting(path);
      if (canWriteAnyway) {
        markTestSkipped(
          'this user can write read-only files, for example as root',
        );
        return;
      }

      final result = await repository.write(path, 'changed', FileEncoding.ansi);

      expect(result, isA<Failure<void>>());
      expect(textOf(path), 'original');
      expect(names(), ['a.txt']);
    },
  );

  test('a save keeps the permission bits of the file it replaces', () async {
    if (Platform.isWindows) {
      markTestSkipped('permission bits are POSIX only');
      return;
    }
    final path = '${folder.path}/private.txt';
    await repository.write(path, 'secret', FileEncoding.ansi);
    Process.runSync('chmod', ['600', path]);

    await repository.write(path, 'still secret', FileEncoding.ansi);

    expect(File(path).statSync().mode & 0x1FF, 0x180);
    expect(textOf(path), 'still secret');
  });

  test(
    'a save through a symbolic link updates the target and keeps the link',
    () async {
      if (Platform.isWindows) {
        markTestSkipped('symbolic links need extra privilege on Windows');
        return;
      }
      final target = '${folder.path}/target.txt';
      final link = '${folder.path}/link.txt';
      await repository.write(target, 'old', FileEncoding.ansi);
      Link(link).createSync(target);

      final result = await repository.write(link, 'new', FileEncoding.ansi);

      expect(result, isA<Success<void>>());
      expect(FileSystemEntity.isLinkSync(link), isTrue);
      expect(textOf(target), 'new');
      expect(names(), ['link.txt', 'target.txt']);
    },
  );

  test(
    'a folder that cannot take a temporary file still saves the file in place',
    () async {
      if (Platform.isWindows) {
        markTestSkipped('folder permissions are POSIX only');
        return;
      }
      final path = '${folder.path}/a.txt';
      await repository.write(path, 'before', FileEncoding.ansi);
      Process.runSync('chmod', ['555', folder.path]);

      final result = await repository.write(path, 'after', FileEncoding.ansi);

      expect(result, isA<Success<void>>());
      expect(textOf(path), 'after');
    },
  );
}

/// Stands in for the final rename, so the test can fail a save after its bytes are written.
Future<void> _failReplace(File temporary, String path) async {
  throw FileSystemException('simulated failure during the rename', path);
}

/// True when the current user can open [path] for writing (root can, read-only or not).
bool _canOpenForWriting(String path) {
  try {
    File(path).openSync(mode: FileMode.append).closeSync();
    return true;
  } on FileSystemException {
    return false;
  }
}
