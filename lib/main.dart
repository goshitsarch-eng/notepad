import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xp_notepad/app.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final dependencies = AppDependencies.standard();
  final settings = await dependencies.settings.load();

  // The XP caption is drawn in Flutter, so the OS title bar is removed.
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: Size(settings.windowWidth, settings.windowHeight),
      minimumSize: Size(kMinimumWindowSize.width, kMinimumWindowSize.height),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Untitled - Notepad',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    XpNotepadApp(
      dependencies: dependencies,
      settings: settings,
      initialPath: args.isEmpty ? null : args.first,
    ),
  );
}
