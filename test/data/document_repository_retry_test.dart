import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/utils/result.dart';

/// On Windows a virus scanner, a search indexer or a backup program can hold a file for a
/// moment right after it is written, and moving the finished file over the document then
/// fails with "access denied" or a sharing violation. The save waits a little and tries
/// again, instead of reporting a failure that a second later would not have happened.
void main() {
  late Directory folder;
  late String path;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('xp_notepad_retry_');
    path = '${folder.path}/a.txt';
  });

  tearDown(() => folder.deleteSync(recursive: true));

  String textOf(String path) => readText(File(path).readAsBytesSync()).text;

  List<String> names() =>
      folder.listSync().map((e) => e.path.split('/').last).toList()..sort();

  FileSystemException busy(String path, [int code = 32]) => FileSystemException(
    'Cannot rename the file',
    path,
    OSError('The process cannot access the file because it is in use', code),
  );

  /// A rename that fails [failures] times with [error] before it really happens.
  ({FileDocumentRepository repository, List<int> attempts}) flaky(
    int failures,
    FileSystemException Function(String path) error, {
    List<Duration> delays = const [Duration.zero, Duration.zero, Duration.zero],
  }) {
    final attempts = <int>[];
    final repository = FileDocumentRepository(
      replaceFile: (temporary, target) async {
        attempts.add(attempts.length + 1);
        if (attempts.length <= failures) throw error(target);
        await temporary.rename(target);
      },
      replaceRetryDelays: delays,
    );
    return (repository: repository, attempts: attempts);
  }

  test('a save that is blocked for a moment succeeds on a later try', () async {
    File(path).writeAsStringSync('original');
    final rig = flaky(2, busy);

    final result = await rig.repository.write(
      path,
      'changed',
      FileEncoding.ansi,
    );

    expect(result, isA<Success<void>>());
    expect(rig.attempts.length, 3);
    expect(textOf(path), 'changed');
    expect(names(), ['a.txt']);
  });

  test('access denied and a lock violation are retried as well', () async {
    for (final code in [5, 33]) {
      File(path).writeAsStringSync('original');
      final rig = flaky(1, (p) => busy(p, code));

      final result = await rig.repository.write(
        path,
        'changed',
        FileEncoding.ansi,
      );

      expect(result, isA<Success<void>>(), reason: 'error $code');
      expect(rig.attempts.length, 2);
    }
  });

  test('a save that stays blocked fails after the last try and leaves the old text', () async {
    File(path).writeAsStringSync('original');
    final rig = flaky(100, busy);

    final result = await rig.repository.write(
      path,
      'changed',
      FileEncoding.ansi,
    );

    expect(result, isA<Failure<void>>());
    expect(rig.attempts.length, 4, reason: 'one try and one per pause');
    expect(textOf(path), 'original');
    expect(names(), ['a.txt'], reason: 'the temporary file is removed');
  });

  test('another kind of failure is not retried', () async {
    File(path).writeAsStringSync('original');
    final rig = flaky(
      100,
      (p) => FileSystemException(
        'Cannot rename the file',
        p,
        OSError('No such file or directory', 2),
      ),
    );

    final result = await rig.repository.write(
      path,
      'changed',
      FileEncoding.ansi,
    );

    expect(result, isA<Failure<void>>());
    expect(rig.attempts.length, 1);
    expect(textOf(path), 'original');
  });

  test('the pauses are taken between the tries', () async {
    File(path).writeAsStringSync('original');
    final watch = Stopwatch()..start();
    final rig = flaky(
      2,
      busy,
      delays: const [Duration(milliseconds: 120), Duration(milliseconds: 120)],
    );

    await rig.repository.write(path, 'changed', FileEncoding.ansi);

    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(220));
  });

  test('without pauses a blocked save is tried once', () async {
    File(path).writeAsStringSync('original');
    final rig = flaky(1, busy, delays: const []);

    final result = await rig.repository.write(
      path,
      'changed',
      FileEncoding.ansi,
    );

    expect(result, isA<Failure<void>>());
    expect(rig.attempts.length, 1);
  });

  test('by default only Windows waits and tries again', () async {
    File(path).writeAsStringSync('original');
    final attempts = <int>[];
    final repository = FileDocumentRepository(
      replaceFile: (temporary, target) async {
        attempts.add(1);
        if (attempts.length == 1) throw busy(target);
        await temporary.rename(target);
      },
    );

    final result = await repository.write(path, 'changed', FileEncoding.ansi);

    if (Platform.isWindows) {
      expect(result, isA<Success<void>>());
      expect(attempts.length, 2);
    } else {
      // The same numbers mean other things elsewhere, so nothing is retried.
      expect(result, isA<Failure<void>>());
      expect(attempts.length, 1);
    }
  });
}
