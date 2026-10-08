import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Help > About Notepad. It names this clone and carries no Microsoft branding.
class AboutDialog extends StatelessWidget {
  const AboutDialog({super.key, required this.request});

  final AboutRequest request;

  @override
  Widget build(BuildContext context) {
    void close() => request.complete(true);

    return XpDialogWindow(
      title: 'About Notepad',
      width: 330,
      onClose: close,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): close,
          const SingleActivator(LogicalKeyboardKey.enter): close,
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox.square(
                  dimension: 32,
                  child: CustomPaint(painter: NotepadIconPainter()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notepad',
                        style: XpText.ui().copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'An unofficial Flutter recreation of Windows XP Notepad.',
                        style: XpText.ui(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Not affiliated with Microsoft.',
                        style: XpText.ui(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: XpButton(
                label: 'OK',
                isDefault: true,
                autofocus: true,
                onPressed: close,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
