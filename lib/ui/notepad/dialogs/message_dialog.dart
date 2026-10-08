import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// The XP message box: an icon, the message, and a centred row of buttons. The first
/// button is the default. Escape and the close button choose the cancelling answer.
class MessageDialog extends StatelessWidget {
  const MessageDialog({super.key, required this.request});

  final MessageRequest request;

  MessageChoice get _cancelChoice {
    final choices = request.choices;
    if (choices.contains(MessageChoice.cancel)) return MessageChoice.cancel;
    if (choices.contains(MessageChoice.no)) return MessageChoice.no;
    return choices.first;
  }

  XpMessageIconKind get _iconKind => switch (request.icon) {
    MessageIcon.question => XpMessageIconKind.question,
    MessageIcon.information => XpMessageIconKind.information,
    MessageIcon.warning => XpMessageIconKind.warning,
    MessageIcon.error => XpMessageIconKind.error,
  };

  static String _label(MessageChoice choice) => switch (choice) {
    MessageChoice.yes => 'Yes',
    MessageChoice.no => 'No',
    MessageChoice.cancel => 'Cancel',
    MessageChoice.ok => 'OK',
  };

  @override
  Widget build(BuildContext context) {
    return XpDialogWindow(
      title: request.title,
      width: 340,
      onClose: () => request.complete(_cancelChoice),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              request.complete(_cancelChoice),
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 32,
                  child: CustomPaint(painter: MessageIconPainter(_iconKind)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(request.text, style: XpText.ui())),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, choice) in request.choices.indexed) ...[
                  if (index > 0) const SizedBox(width: 6),
                  XpButton(
                    label: _label(choice),
                    isDefault: index == 0,
                    autofocus: index == 0,
                    onPressed: () => request.complete(choice),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
