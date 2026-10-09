import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Every shortcut listed here is handled by the app. Ctrl+G works only while Word Wrap is off.
const _shortcuts = <(String, String)>[
  ('Ctrl+N', 'New document'),
  ('Ctrl+O', 'Open a file'),
  ('Ctrl+S', 'Save'),
  ('Ctrl+P', 'Print'),
  ('Ctrl+Z  or  Alt+Backspace', 'Undo'),
  ('Ctrl+X', 'Cut'),
  ('Ctrl+C  or  Ctrl+Insert', 'Copy'),
  ('Ctrl+V  or  Shift+Insert', 'Paste'),
  ('Del', 'Delete the selection'),
  ('Ctrl+A', 'Select all'),
  ('Ctrl+F', 'Find'),
  ('F3', 'Find next'),
  ('Ctrl+H', 'Replace'),
  ('Ctrl+G', 'Go To line (Word Wrap off)'),
  ('F5', 'Insert time and date'),
  ('F1', 'Help topics'),
  ('Alt + letter', 'Open a menu, e.g. Alt+F for File'),
  ('Alt+Space', 'Open the window menu: minimize, maximize, close'),
  ('Esc', 'Close a menu or dialog'),
  ('Tab', 'Insert a tab character'),
  ('Enter', 'Press the highlighted button in a dialog'),
];

/// Help > Help Topics: a scrollable table of shortcuts, then OK.
class HelpDialog extends StatefulWidget {
  const HelpDialog({super.key, required this.request});

  final HelpRequest request;

  @override
  State<HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends State<HelpDialog> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _close() => widget.request.complete(true);

  @override
  Widget build(BuildContext context) {
    return XpDialogWindow(
      title: 'Notepad Help',
      width: 400,
      onClose: _close,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(LogicalKeyboardKey.enter): _close,
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keyboard shortcuts',
              style: XpText.ui().copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: XpColors.paper,
                  border: Border.all(color: XpColors.editBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          itemExtent: 18,
                          itemCount: _shortcuts.length,
                          itemBuilder: (context, index) {
                            final (keys, action) = _shortcuts[index];
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 170,
                                    child: Text(
                                      keys,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: XpText.ui(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      action,
                                      maxLines: 1,
                                      overflow: TextOverflow.clip,
                                      style: XpText.ui(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      XpScrollBar(
                        controller: _scroll,
                        axis: Axis.vertical,
                        lineStep: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: XpButton(
                label: 'OK',
                isDefault: true,
                autofocus: true,
                onPressed: _close,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
