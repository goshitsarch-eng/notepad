import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/notepad/dialogs/about_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/file_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/font_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/go_to_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/help_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/message_dialog.dart';
import 'package:xp_notepad/ui/notepad/dialogs/page_setup_dialog.dart';

/// Shows the blocking dialog for [request] centred over the window. The barrier keeps
/// clicks from reaching the text until the dialog is answered.
class ModalDialogHost extends StatelessWidget {
  const ModalDialogHost({super.key, required this.request});

  final ModalRequest<Object?> request;

  @override
  Widget build(BuildContext context) {
    final dialog = switch (request) {
      final MessageRequest r => MessageDialog(request: r),
      final GoToRequest r => GoToDialog(request: r),
      final FontRequest r => FontDialog(request: r),
      final PageSetupRequest r => PageSetupDialog(request: r),
      final AboutRequest r => AboutDialog(request: r),
      final HelpRequest r => HelpDialog(request: r),
      final FileRequest r => FileDialog(request: r),
    };
    // Escape cancels whichever dialog has focus, even when focus is on the dialog itself
    // rather than one of its fields. A cancelled request completes with null.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            request.complete(null),
      },
      child: Stack(
        children: [
          const Positioned.fill(child: XpModalBarrier()),
          // Each dialog gets its own focus scope, so its autofocus field wins over the
          // editor.
          Positioned.fill(
            child: Center(child: FocusScope(child: dialog)),
          ),
        ],
      ),
    );
  }
}
