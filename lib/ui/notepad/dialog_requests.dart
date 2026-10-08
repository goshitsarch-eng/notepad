import 'dart:async';

import 'package:xp_notepad/domain/models/file_encoding.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';

/// A dialog that blocks the window until it is answered. The view model awaits [result].
sealed class ModalRequest<R> {
  final Completer<R?> _completer = Completer<R?>();

  Future<R?> get result => _completer.future;

  /// Answers the dialog. A null [value] means the dialog was cancelled.
  void complete(R? value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }
}

enum MessageIcon { question, information, warning, error }

enum MessageChoice { yes, no, cancel, ok }

final class MessageRequest extends ModalRequest<MessageChoice> {
  MessageRequest({
    required this.title,
    required this.text,
    required this.icon,
    required this.choices,
  });

  final String title;
  final String text;
  final MessageIcon icon;
  final List<MessageChoice> choices;
}

final class GoToRequest extends ModalRequest<int> {
  GoToRequest({required this.currentLine, required this.lineCount});

  final int currentLine;
  final int lineCount;
}

final class FontRequest extends ModalRequest<EditorFont> {
  FontRequest({required this.initial});

  final EditorFont initial;
}

final class PageSetupRequest extends ModalRequest<PageSetup> {
  PageSetupRequest({required this.initial});

  final PageSetup initial;
}

final class AboutRequest extends ModalRequest<bool> {}

enum FileDialogMode { open, save }

/// The file a user picked in the Open or Save As dialog, and the encoding to save with.
class FileChoice {
  const FileChoice(this.path, this.encoding);

  final String path;
  final FileEncoding encoding;
}

final class FileRequest extends ModalRequest<FileChoice> {
  FileRequest({
    required this.mode,
    required this.startDirectory,
    required this.encoding,
    this.suggestedName,
  });

  final FileDialogMode mode;
  final String startDirectory;
  final FileEncoding encoding;
  final String? suggestedName;
}

/// The modeless Find or Replace dialog. It stays open while the document is edited.
class FindState {
  const FindState({required this.replace});

  final bool replace;
}

/// Help > Help Topics. Shows the keyboard shortcuts the app responds to.
final class HelpRequest extends ModalRequest<bool> {}
