import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/domain/models/file_filter.dart';

void main() {
  const service = LocalFileSystemService();
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('xp_notepad_fs'));
  tearDown(() {
    // A folder the test made unreadable has to be opened up before it can be removed.
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['-R', 'u+rwx', folder.path]);
    }
    folder.deleteSync(recursive: true);
  });

  List<String> names(List<DirectoryEntry> entries) => [
    for (final e in entries) e.name,
  ];

  test(
    'folders come first, then files, each sorted without regard to case',
    () async {
      File(p.join(folder.path, 'banana.txt')).writeAsStringSync('b');
      File(p.join(folder.path, 'Apple.txt')).writeAsStringSync('a');
      Directory(p.join(folder.path, 'zeta')).createSync();
      Directory(p.join(folder.path, 'Alpha')).createSync();

      final entries = await service.listDirectory(
        folder.path,
        textDocumentsFilter,
      );

      expect(names(entries), ['Alpha', 'zeta', 'Apple.txt', 'banana.txt']);
      expect(entries.first.isDirectory, isTrue);
      expect(entries.last.size, 1);
    },
  );

  test('hidden entries and files the filter hides are left out', () async {
    File(p.join(folder.path, '.hidden.txt')).writeAsStringSync('h');
    File(p.join(folder.path, 'notes.txt')).writeAsStringSync('n');
    File(p.join(folder.path, 'photo.png')).writeAsStringSync('p');
    Directory(p.join(folder.path, '.git')).createSync();

    expect(
      names(await service.listDirectory(folder.path, textDocumentsFilter)),
      ['notes.txt'],
    );
    expect(names(await service.listDirectory(folder.path, allFilesFilter)), [
      'notes.txt',
      'photo.png',
    ]);
  });

  test(
    'a folder with hundreds of entries lists completely and in order',
    () async {
      for (var i = 0; i < 400; i++) {
        File(p.join(folder.path, 'file${i.toString().padLeft(3, '0')}.txt'))
            .writeAsStringSync('$i');
      }

      final entries = await service.listDirectory(
        folder.path,
        textDocumentsFilter,
      );

      expect(entries, hasLength(400));
      expect(entries.first.name, 'file000.txt');
      expect(entries.last.name, 'file399.txt');
    },
  );

  test(
    'one entry that cannot be read does not hide the others (F-11)',
    () async {
      if (Platform.isWindows) return;
      File(p.join(folder.path, 'good.txt')).writeAsStringSync('g');
      // A link to nothing: listing it works, examining it fails.
      Link(p.join(folder.path, 'dangling.txt'))
          .createSync(p.join(folder.path, 'gone'));
      Directory(p.join(folder.path, 'sub')).createSync();

      final entries = await service.listDirectory(
        folder.path,
        textDocumentsFilter,
      );

      expect(names(entries), ['sub', 'good.txt']);
    },
  );

  test(
    'a folder that does not exist reports it instead of listing nothing (F-11)',
    () async {
      await expectLater(
        service.listDirectory(
          p.join(folder.path, 'missing'),
          textDocumentsFilter,
        ),
        throwsA(isA<PathNotFoundException>()),
      );
    },
  );

  test('a folder that cannot be read reports why instead of listing nothing (F-11)', () async {
    if (Platform.isWindows) return;
    final locked = Directory(p.join(folder.path, 'locked'))..createSync();
    File(p.join(locked.path, 'inside.txt')).writeAsStringSync('i');
    Process.runSync('chmod', ['000', locked.path]);
    // Root can read anything, which makes the folder readable and this check moot.
    if (_canList(locked)) {
      markTestSkipped('running as a user that can read every folder');
      return;
    }

    await expectLater(
      service.listDirectory(locked.path, textDocumentsFilter),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('directoryExists tells folders from files and from nothing', () async {
    final file = File(p.join(folder.path, 'a.txt'))..writeAsStringSync('a');

    expect(await service.directoryExists(folder.path), isTrue);
    expect(await service.directoryExists(file.path), isFalse);
    expect(await service.directoryExists(p.join(folder.path, 'nope')), isFalse);
    expect(await service.fileExists(file.path), isTrue);
  });

  test('the home folder is never empty', () {
    expect(service.homeDirectory, isNotEmpty);
  });
}

bool _canList(Directory directory) {
  try {
    directory.listSync();
    return true;
  } on FileSystemException {
    return false;
  }
}
