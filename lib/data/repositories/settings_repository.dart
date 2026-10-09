import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xp_notepad/domain/models/notepad_settings.dart';

/// Source of truth for the settings that survive between runs.
abstract interface class SettingsRepository {
  Future<NotepadSettings> load();

  Future<void> save(NotepadSettings settings);
}

/// Stores settings as JSON. XP keeps them in the registry; this clone uses a file.
class JsonFileSettingsRepository implements SettingsRepository {
  /// [file] is null when the system gives no place to keep settings. The defaults then
  /// apply on every run and nothing is written.
  JsonFileSettingsRepository(this.file);

  /// %APPDATA%\xp_notepad\settings.json on Windows, otherwise
  /// $XDG_CONFIG_HOME/xp_notepad/settings.json (or ~/.config). A variable that is empty,
  /// or a relative path, is ignored, as the XDG Base Directory specification says. With no
  /// usable folder at all, settings are not kept: a relative guess would put the file in
  /// whatever folder the app was started from.
  factory JsonFileSettingsRepository.standard({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    String? absolute(String? value) =>
        value != null && value.isNotEmpty && p.isAbsolute(value) ? value : null;
    final base = Platform.isWindows
        ? absolute(env['APPDATA']) ?? absolute(env['USERPROFILE'])
        : absolute(env['XDG_CONFIG_HOME']) ??
              switch (absolute(env['HOME'])) {
                final home? => p.join(home, '.config'),
                null => null,
              };
    return JsonFileSettingsRepository(
      base == null ? null : File(p.join(base, 'xp_notepad', 'settings.json')),
    );
  }

  final File? file;

  /// The save in progress, if any. Saves run one after another, so an older save can never
  /// finish after a newer one and bring back a setting the user has since changed.
  Future<void> _queue = Future<void>.value();

  @override
  Future<NotepadSettings> load() async {
    final file = this.file;
    if (file == null) return const NotepadSettings();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        return NotepadSettings.fromJson(decoded);
      }
    } on FileSystemException {
      // No settings yet, so the defaults apply.
    } on FormatException {
      // A damaged file is replaced by defaults on the next save.
    }
    return const NotepadSettings();
  }

  @override
  Future<void> save(NotepadSettings settings) {
    final file = this.file;
    if (file == null) return Future<void>.value();
    // Encoded now, so the file holds the settings as they were when save was called.
    final json = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    final run = _queue.then((_) => _write(file, json));
    // A failed save must not stop the ones queued after it.
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Writes a temporary file beside the settings and moves it into place, so a crash
  /// during the write leaves the old settings, never half of the new ones.
  static Future<void> _write(File file, String json) async {
    await file.parent.create(recursive: true);
    // A settings file that is a symbolic link, as a dotfile manager makes it, is written
    // through to its target, so the link itself is kept.
    final target = await file.exists()
        ? File(await file.resolveSymbolicLinks())
        : file;
    final temporary = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(json, flush: true);
      await temporary.rename(target.path);
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
