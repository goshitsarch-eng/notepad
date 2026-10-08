import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/config/app_dependencies.dart';
import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/data/repositories/settings_repository.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/data/services/printing_service.dart';
import 'package:xp_notepad/data/services/window_service.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/notepad/notepad_screen.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// Root of the app. It provides the repositories, services and view model, then shows the
/// Notepad window. WidgetsApp is used rather than MaterialApp: every control is drawn in
/// the Luna style, so no Material theme is involved.
class XpNotepadApp extends StatelessWidget {
  const XpNotepadApp({
    super.key,
    required this.dependencies,
    required this.settings,
    this.initialPath,
  });

  final AppDependencies dependencies;
  final NotepadSettings settings;
  final String? initialPath;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DocumentRepository>.value(value: dependencies.documents),
        Provider<SettingsRepository>.value(value: dependencies.settings),
        Provider<FileSystemService>.value(value: dependencies.fileSystem),
        Provider<PrintingService>.value(value: dependencies.printing),
        Provider<WindowService>.value(value: dependencies.window),
        ChangeNotifierProvider<NotepadViewModel>(
          create: (context) => NotepadViewModel(
            documents: context.read<DocumentRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
            fileSystem: context.read<FileSystemService>(),
            printing: context.read<PrintingService>(),
            window: context.read<WindowService>(),
            settings: settings,
          )..start(initialPath: initialPath),
        ),
      ],
      child: WidgetsApp(
        title: 'Untitled - Notepad',
        debugShowCheckedModeBanner: false,
        color: XpColors.face,
        pageRouteBuilder: _pageRoute,
        home: const NotepadScreen(),
      ),
    );
  }

  static PageRoute<T> _pageRoute<T>(
    RouteSettings settings,
    WidgetBuilder builder,
  ) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    );
  }
}
