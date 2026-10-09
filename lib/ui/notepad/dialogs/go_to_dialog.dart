import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Edit > Go To: a line-number box, pre-filled with the caret's line.
class GoToDialog extends StatefulWidget {
  const GoToDialog({super.key, required this.request});

  final GoToRequest request;

  @override
  State<GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<GoToDialog> {
  // The line number starts out selected, so typing replaces it instead of adding to it.
  late final TextEditingController _line = TextEditingController.fromValue(
    TextEditingValue(
      text: '${widget.request.currentLine}',
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: '${widget.request.currentLine}'.length,
      ),
    ),
  );
  final _focus = FocusNode(debugLabel: 'line number');

  @override
  void dispose() {
    _line.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _line.text.trim();
    // Only digits can be typed. One too long for an int is simply a line past the end of
    // the text, which goes to the last line, not a number to ignore.
    final line =
        int.tryParse(typed) ??
        (RegExp(r'^[0-9]+$').hasMatch(typed) ? _pastTheEnd : null);
    if (line == null) return;
    widget.request.complete(line);
  }

  static const _pastTheEnd = 0x7FFFFFFF;

  void _cancel() => widget.request.complete(null);

  @override
  Widget build(BuildContext context) {
    return XpDialogWindow(
      title: 'Go To Line',
      width: 230,
      onClose: _cancel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Line Number:', style: XpText.ui()),
            const SizedBox(height: 4),
            XpTextBox(
              controller: _line,
              focusNode: _focus,
              autofocus: true,
              semanticLabel: 'Line number',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                XpButton(label: 'Go To', isDefault: true, onPressed: _submit),
                const SizedBox(width: 6),
                XpButton(label: 'Cancel', onPressed: _cancel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
