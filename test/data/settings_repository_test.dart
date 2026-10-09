import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xp_notepad/data/repositories/settings_repository.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';

void main() {
  late Directory folder;

  setUp(
    () => folder = Directory.systemTemp.createTempSync('xp_notepad_settings'),
  );
  tearDown(() => folder.deleteSync(recursive: true));

  group('where settings are kept (F-10)', () {
    test('XDG_CONFIG_HOME is used when it is an absolute path', () {
      if (Platform.isWindows) return;
      final repository = JsonFileSettingsRepository.standard(
        environment: {'XDG_CONFIG_HOME': '/xdg', 'HOME': '/home/me'},
      );
      expect(repository.file!.path, '/xdg/xp_notepad/settings.json');
    });

    test('an empty XDG_CONFIG_HOME counts as unset and does not write to the working folder', () {
      if (Platform.isWindows) return;
      final repository = JsonFileSettingsRepository.standard(
        environment: {'XDG_CONFIG_HOME': '', 'HOME': '/home/me'},
      );
      expect(
        repository.file!.path,
        '/home/me/.config/xp_notepad/settings.json',
      );
    });

    test('a relative XDG_CONFIG_HOME is ignored, as the XDG specification requires', () {
      if (Platform.isWindows) return;
      final repository = JsonFileSettingsRepository.standard(
        environment: {'XDG_CONFIG_HOME': 'relative/dir', 'HOME': '/home/me'},
      );
      expect(
        repository.file!.path,
        '/home/me/.config/xp_notepad/settings.json',
      );
    });

    test('with no usable folder at all nothing is read or written', () async {
      if (Platform.isWindows) return;
      final repository = JsonFileSettingsRepository.standard(
        environment: {'XDG_CONFIG_HOME': '', 'HOME': ''},
      );
      expect(repository.file, isNull);
      expect(await repository.load(), isA<NotepadSettings>());
      // Must not throw, and must not create a folder in the working directory.
      await repository.save(const NotepadSettings(darkMode: true));
      expect(Directory('.config').existsSync(), isFalse);
    });
  });

  group('saving', () {
    test('settings survive a save and a load', () async {
      final repository = JsonFileSettingsRepository(
        File(p.join(folder.path, 'xp', 'settings.json')),
      );
      await repository.save(
        const NotepadSettings(darkMode: true, wordWrap: false),
      );

      final loaded = await repository.load();

      expect(loaded.darkMode, isTrue);
      expect(loaded.wordWrap, isFalse);
    });

    test('no temporary file is left behind', () async {
      final file = File(p.join(folder.path, 'xp', 'settings.json'));
      await JsonFileSettingsRepository(file).save(const NotepadSettings());

      expect(file.parent.listSync().map((e) => p.basename(e.path)), [
        'settings.json',
      ]);
    });

    test('the last save wins, however many are started together', () async {
      final repository = JsonFileSettingsRepository(
        File(p.join(folder.path, 'xp', 'settings.json')),
      );
      for (var round = 0; round < 10; round++) {
        await Future.wait([
          for (var i = 0; i < 12; i++)
            repository.save(
              NotepadSettings(lastDirectory: '/folder/$i', darkMode: i.isOdd),
            ),
        ]);
        final loaded = await repository.load();
        expect(loaded.lastDirectory, '/folder/11', reason: 'round $round');
        expect(loaded.darkMode, isTrue);
      }
    });

    test('a settings file that is a symbolic link is written through, and the link kept', () async {
      if (Platform.isWindows) {
        return;
      }
      final target = File(p.join(folder.path, 'dotfiles', 'settings.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      final link = Link(p.join(folder.path, 'xp', 'settings.json'))
        ..createSync(target.path, recursive: true);
      final repository = JsonFileSettingsRepository(File(link.path));

      await repository.save(const NotepadSettings(darkMode: true));

      expect(
        FileSystemEntity.isLinkSync(link.path),
        isTrue,
        reason: 'the link must survive',
      );
      expect((await repository.load()).darkMode, isTrue);
      expect(target.readAsStringSync(), contains('"darkMode": true'));
    });

    test('a failed save does not stop the saves after it, and leaves nothing behind', () async {
      // The settings folder cannot be created because a file is in the way.
      final blocker = File(p.join(folder.path, 'blocked'))
        ..writeAsStringSync('x');
      final failing = JsonFileSettingsRepository(
        File(p.join(blocker.path, 'settings.json')),
      );
      await expectLater(
        failing.save(const NotepadSettings()),
        throwsA(isA<FileSystemException>()),
      );

      final working = JsonFileSettingsRepository(
        File(p.join(folder.path, 'ok', 'settings.json')),
      );
      await working.save(const NotepadSettings(darkMode: true));
      expect((await working.load()).darkMode, isTrue);

      // A queue that has seen a failure keeps going.
      final queue = JsonFileSettingsRepository(
        File(p.join(blocker.path, 'settings.json')),
      );
      final first = queue.save(const NotepadSettings());
      final second = queue.save(const NotepadSettings());
      await expectLater(first, throwsA(isA<FileSystemException>()));
      await expectLater(second, throwsA(isA<FileSystemException>()));
    });
  });

  group('loading', () {
    test('a missing file gives the defaults', () async {
      final repository = JsonFileSettingsRepository(
        File(p.join(folder.path, 'none.json')),
      );
      expect((await repository.load()).wordWrap, isTrue);
    });

    test(
      'a damaged file gives the defaults, and the next save replaces it',
      () async {
        final file = File(p.join(folder.path, 'settings.json'))
          ..writeAsStringSync('{ not json');
        final repository = JsonFileSettingsRepository(file);
        expect((await repository.load()).wordWrap, isTrue);

        await repository.save(const NotepadSettings(wordWrap: false));

        expect((await repository.load()).wordWrap, isFalse);
      },
    );

    test('a file that is not valid UTF-8 gives the defaults', () async {
      final file = File(p.join(folder.path, 'settings.json'))
        ..writeAsBytesSync([0xFF, 0xFE, 0x00, 0x80]);
      expect((await JsonFileSettingsRepository(file).load()).wordWrap, isTrue);
    });
  });
}
