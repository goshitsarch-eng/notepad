import 'dart:typed_data';

import 'package:xp_notepad/data/encoding/text_codec.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/data/repositories/settings_repository.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/data/services/printing_service.dart';
import 'package:xp_notepad/data/services/window_service.dart';
import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/file_filter.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/utils/result.dart';

/// In-memory documents keyed by path.
class FakeDocumentRepository implements DocumentRepository {
  final Map<String, Uint8List> files = {};
  final List<({String path, String text, FileEncoding encoding})> writes = [];

  @override
  Future<Result<TextFile>> read(String path) async {
    final bytes = files[path];
    if (bytes == null) return Failure<TextFile>(StateError('missing $path'));
    return Success(readText(bytes));
  }

  @override
  Future<Result<void>> write(
    String path,
    String text,
    FileEncoding encoding,
  ) async {
    writes.add((path: path, text: text, encoding: encoding));
    files[path] = encodeText(text, encoding);
    return const Success<void>(null);
  }
}

class FakeSettingsRepository implements SettingsRepository {
  NotepadSettings? saved;

  @override
  Future<NotepadSettings> load() async => saved ?? const NotepadSettings();

  @override
  Future<void> save(NotepadSettings settings) async => saved = settings;
}

class FakeFileSystemService implements FileSystemService {
  final Set<String> existing = {};

  @override
  String get homeDirectory => '/home/tester';

  @override
  Future<bool> fileExists(String path) async => existing.contains(path);

  @override
  Future<List<DirectoryEntry>> listDirectory(
    String directory,
    FileTypeFilter filter,
  ) async {
    return const [];
  }
}

class FakePrintingService implements PrintingService {
  final List<String> printed = [];

  @override
  Future<Result<void>> printDocument({
    required String text,
    required String documentName,
    required PageSetup setup,
  }) async {
    printed.add(documentName);
    return const Success<void>(null);
  }
}

class FakeWindowService implements WindowService {
  WindowEventHandler? handler;
  String? title;
  bool preventClose = false;
  bool closed = false;
  bool maximized = false;
  ({double width, double height}) size = (width: 500.0, height: 400.0);

  @override
  void attach(WindowEventHandler handler) => this.handler = handler;

  @override
  Future<({double width, double height})> currentSize() async => size;

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> setSize(double width, double height) async =>
      size = (width: width, height: height);

  @override
  Future<void> setTitle(String title) async => this.title = title;

  @override
  Future<void> setPreventClose(bool prevent) async => preventClose = prevent;

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> startResizing(ResizeDirection direction) async {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> closeWindow() async => closed = true;
}
