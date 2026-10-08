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
  JsonFileSettingsRepository(this.file);

  /// %APPDATA%\xp_notepad\settings.json on Windows, otherwise
  /// $XDG_CONFIG_HOME/xp_notepad/settings.json (or ~/.config).
  factory JsonFileSettingsRepository.standard({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final base = Platform.isWindows
        ? env['APPDATA'] ?? env['USERPROFILE'] ?? '.'
        : env['XDG_CONFIG_HOME'] ?? p.join(env['HOME'] ?? '.', '.config');
    return JsonFileSettingsRepository(
      File(p.join(base, 'xp_notepad', 'settings.json')),
    );
  }

  final File file;

  @override
  Future<NotepadSettings> load() async {
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
  Future<void> save(NotepadSettings settings) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
