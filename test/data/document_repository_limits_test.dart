import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/utils/file_error.dart';
import 'package:xp_notepad/utils/result.dart';

/// Reading must stay bounded and refuse what is not a plain file, and the reasons given
/// for a failure must reach the person who has to read them.
void main() {
  late Directory folder;

  setUp(
    () => folder = Directory.systemTemp.createTempSync('xp_notepad_limits'),
  );
  tearDown(() => folder.deleteSync(recursive: true));

  Failure<TextFile> failureOf(Result<TextFile> result) {
    expect(result, isA<Failure<TextFile>>());
    return result as Failure<TextFile>;
  }

  test(
    'a file over the limit is refused with a reason that names the limit',
    () async {
      final path = '${folder.path}/big.txt';
      File(path).writeAsBytesSync(List.filled(2048, 0x61));
      const repository = FileDocumentRepository(maximumBytes: 1024);

      final failure = failureOf(await repository.read(path));

      expect(describeFileError(failure.error), contains('too large'));
      expect(describeFileError(failure.error), contains('1024 bytes'));
    },
  );

  test('a file that spans many read chunks comes back byte for byte', () async {
    // Every line is different, so a reused or overwritten chunk buffer would show.
    final text = [for (var i = 0; i < 40000; i++) 'line number $i of the file']
        .join('\n');
    final path = '${folder.path}/chunks.txt';
    File(path).writeAsStringSync(text);
    expect(File(path).lengthSync(), greaterThan(8 * 64 * 1024));
    const repository = FileDocumentRepository();

    final result = await repository.read(path);

    expect((result as Success<TextFile>).value.text, text);
  });

  test('a file exactly at the limit still opens', () async {
    final path = '${folder.path}/edge.txt';
    File(path).writeAsBytesSync(List.filled(1024, 0x61));
    const repository = FileDocumentRepository(maximumBytes: 1024);

    final result = await repository.read(path);

    expect(result, isA<Success<TextFile>>());
    expect((result as Success<TextFile>).value.text, 'a' * 1024);
  });

  test(
    'a file that reports no size, such as /dev/zero, is stopped at the limit',
    () async {
      if (Platform.isWindows) {
        markTestSkipped('POSIX devices only');
        return;
      }
      const repository = FileDocumentRepository(maximumBytes: 4096);

      final failure = failureOf(await repository.read('/dev/zero'));

      expect(describeFileError(failure.error), contains('too large'));
    },
  );

  test(
    'a folder is refused with a reason instead of an operating system error',
    () async {
      const repository = FileDocumentRepository();

      final failure = failureOf(await repository.read(folder.path));

      expect(describeFileError(failure.error), 'This is a folder, not a file');
    },
  );

  test('a named pipe is refused, so the open cannot wait for ever', () async {
    if (Platform.isWindows) {
      markTestSkipped('named pipes are POSIX only');
      return;
    }
    final pipe = '${folder.path}/pipe';
    expect(Process.runSync('mkfifo', [pipe]).exitCode, 0);
    const repository = FileDocumentRepository();

    final failure = await repository
        .read(pipe)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('read hung on a pipe'),
        )
        .then(failureOf);

    expect(describeFileError(failure.error), 'This is not a regular file');
  });

  test(
    'a missing file fails as not found, which the view model words as XP does',
    () async {
      const repository = FileDocumentRepository();

      final failure = failureOf(
        await repository.read('${folder.path}/nothing.txt'),
      );

      expect(failure.error, isA<PathNotFoundException>());
    },
  );

  test(
    'a save that fails comes back as a Failure with a readable reason',
    () async {
      const repository = FileDocumentRepository();

      // The folder does not exist, so neither a temporary file nor the file can be made.
      final result = await repository.write(
        '${folder.path}/no/such/folder/a.txt',
        'text',
        FileEncoding.ansi,
      );

      expect(result, isA<Failure<void>>());
      expect(describeFileError((result as Failure<void>).error), isNotEmpty);
    },
  );

  test(
    'describeFileError prefers the system wording and trims its full stop',
    () {
      expect(
        describeFileError(
          const FileSystemException(
            'Cannot open file',
            '/x',
            OSError('Access is denied.', 5),
          ),
        ),
        'Access is denied',
      );
      expect(
        describeFileError(
          const FileSystemException('The file is too large', '/x'),
        ),
        'The file is too large',
      );
      expect(describeFileError(StateError('not a file error')), '');
      expect(describeFileError(null), '');
    },
  );
}
