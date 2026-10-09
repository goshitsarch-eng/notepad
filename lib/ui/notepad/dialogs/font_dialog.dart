import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Format > Font: family, style and size lists, with a sample line.
class FontDialog extends StatefulWidget {
  const FontDialog({super.key, required this.request});

  final FontRequest request;

  @override
  State<FontDialog> createState() => _FontDialogState();
}

class _FontDialogState extends State<FontDialog> {
  late String _family = widget.request.initial.family;
  late FontFaceStyle _style = widget.request.initial.style;
  late double _size = widget.request.initial.sizePoints;
  late final TextEditingController _sizeText = TextEditingController(
    text: _format(_size),
  );
  final _sizeFocus = FocusNode(debugLabel: 'font size');
  String? _sizeError;

  static final _numeric = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  static final _rangeMessage =
      'Enter a size from ${EditorFont.minimumSizePoints.toInt()} to '
      '${EditorFont.maximumSizePoints.toInt()} points.';

  static String _format(double size) {
    return size == size.roundToDouble()
        ? size.toStringAsFixed(0)
        : size.toString();
  }

  @override
  void dispose() {
    _sizeText.dispose();
    _sizeFocus.dispose();
    super.dispose();
  }

  /// The size in the box, or null when it is empty or outside the range the dialog accepts.
  static double? _parseSize(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null ||
        parsed < EditorFont.minimumSizePoints ||
        parsed > EditorFont.maximumSizePoints) {
      return null;
    }
    return parsed;
  }

  /// Enter in the Size box applies the typed size to the list and the sample at once.
  void _typedSize(String text) {
    final parsed = _parseSize(text);
    if (parsed == null) {
      setState(() => _sizeError = _rangeMessage);
      return;
    }
    setState(() {
      _size = parsed;
      _sizeError = null;
    });
  }

  void _pickSize(double size) {
    setState(() {
      _size = size;
      _sizeError = null;
    });
    _sizeText.text = _format(size);
  }

  /// OK uses whatever the Size box holds, so a size typed without pressing Enter counts.
  /// A size outside the range keeps the dialog open and says why.
  void _submit() {
    final size = _parseSize(_sizeText.text);
    if (size == null) {
      setState(() => _sizeError = _rangeMessage);
      _sizeFocus.requestFocus();
      return;
    }
    widget.request.complete(
      EditorFont(family: _family, sizePoints: size, style: _style),
    );
  }

  void _cancel() => widget.request.complete(null);

  @override
  Widget build(BuildContext context) {
    final sample = XpText.editor(
      EditorFont(family: _family, sizePoints: _size, style: _style),
    );
    return XpDialogWindow(
      title: 'Font',
      width: 500,
      onClose: _cancel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font:', style: XpText.ui()),
                      const SizedBox(height: 4),
                      XpListBox<String>(
                        semanticLabel: 'Font',
                        options: [
                          for (final family in EditorFont.families)
                            XpOption(family, family),
                        ],
                        value: _family,
                        height: 150,
                        // The family list opens with focus, so the arrow keys work at once.
                        autofocus: true,
                        onChanged: (family) => setState(() => _family = family),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font style:', style: XpText.ui()),
                      const SizedBox(height: 4),
                      XpListBox<FontFaceStyle>(
                        semanticLabel: 'Font style',
                        options: [
                          for (final style in FontFaceStyle.values)
                            XpOption(style.label, style),
                        ],
                        value: _style,
                        height: 150,
                        onChanged: (style) => setState(() => _style = style),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Size:', style: XpText.ui()),
                      const SizedBox(height: 4),
                      XpTextBox(
                        controller: _sizeText,
                        focusNode: _sizeFocus,
                        semanticLabel: 'Size',
                        inputFormatters: [_numeric],
                        onSubmitted: _typedSize,
                      ),
                      const SizedBox(height: 4),
                      XpListBox<double>(
                        semanticLabel: 'Size',
                        options: [
                          for (final size in EditorFont.sizes)
                            XpOption('$size', size.toDouble()),
                        ],
                        value: _size,
                        height: 150,
                        onChanged: _pickSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    XpButton(label: 'OK', isDefault: true, onPressed: _submit),
                    const SizedBox(height: 6),
                    XpButton(label: 'Cancel', onPressed: _cancel),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: XpGroupBox(
                    label: 'Sample',
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text('AaBbYyZz', style: sample, maxLines: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Script:', style: XpText.ui()),
                      const SizedBox(height: 4),
                      XpComboBox<String>(
                        semanticLabel: 'Script',
                        options: const [XpOption('Western', 'Western')],
                        value: 'Western',
                        width: 120,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_sizeError != null) ...[
              const SizedBox(height: 8),
              Text(_sizeError!, style: XpText.ui()),
            ],
          ],
        ),
      ),
    );
  }
}
