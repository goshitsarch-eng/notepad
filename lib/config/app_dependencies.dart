import 'package:xp_notepad/data/repositories/document_repository.dart';
import 'package:xp_notepad/data/repositories/settings_repository.dart';
import 'package:xp_notepad/data/services/file_system_service.dart';
import 'package:xp_notepad/data/services/printing_service.dart';
import 'package:xp_notepad/data/services/window_service.dart';

/// The repositories and services the app is built from. Tests build the same graph with
/// fakes, so nothing in the view layer reaches for a global object.
class AppDependencies {
  const AppDependencies({
    required this.documents,
    required this.settings,
    required this.fileSystem,
    required this.printing,
    required this.window,
  });

  factory AppDependencies.standard() {
    return AppDependencies(
      documents: const FileDocumentRepository(),
      settings: JsonFileSettingsRepository.standard(),
      fileSystem: const LocalFileSystemService(),
      printing: const PdfPrintingService(),
      window: WindowManagerService(),
    );
  }

  final DocumentRepository documents;
  final SettingsRepository settings;
  final FileSystemService fileSystem;
  final PrintingService printing;
  final WindowService window;
}
