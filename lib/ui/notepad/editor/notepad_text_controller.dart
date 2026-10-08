import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// Editor text that draws the selected characters in white over the blue highlight,
/// as XP's edit control does. Selection painting itself stays with the text layout.
class NotepadTextController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final range = selection;
    // EditableText passes withComposing whenever the editor has focus, so only an active
    // IME composition (composing range) should hand the span to the framework.
    if ((withComposing && value.composing.isValid) ||
        !range.isValid ||
        range.isCollapsed ||
        range.end > text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, range.start)),
        TextSpan(
          text: text.substring(range.start, range.end),
          style: TextStyle(color: XpColors.highlightText),
        ),
        TextSpan(text: text.substring(range.end)),
      ],
    );
  }
}
