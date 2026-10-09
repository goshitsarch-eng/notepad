import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/notepad/dialog_requests.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// File > Page Setup: header and footer text, and margins in inches.
class PageSetupDialog extends StatefulWidget {
  const PageSetupDialog({super.key, required this.request});

  final PageSetupRequest request;

  @override
  State<PageSetupDialog> createState() => _PageSetupDialogState();
}

class _PageSetupDialogState extends State<PageSetupDialog> {
  late final _header = TextEditingController(
    text: widget.request.initial.header,
  );
  late final _footer = TextEditingController(
    text: widget.request.initial.footer,
  );
  late final _left = TextEditingController(
    text: _inches(widget.request.initial.leftInches),
  );
  late final _top = TextEditingController(
    text: _inches(widget.request.initial.topInches),
  );
  late final _right = TextEditingController(
    text: _inches(widget.request.initial.rightInches),
  );
  late final _bottom = TextEditingController(
    text: _inches(widget.request.initial.bottomInches),
  );
  final _focusNodes = List.generate(
    6,
    (index) => FocusNode(debugLabel: 'page setup $index'),
  );

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

  static String _inches(double value) => value.toString();

  @override
  void dispose() {
    for (final controller in [_header, _footer, _left, _top, _right, _bottom]) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String? _error;

  /// Checks the entries. A bad entry keeps the dialog open and says what is wrong, rather
  /// than quietly keeping the old value.
  void _submit() {
    final left = double.tryParse(_left.text.trim());
    final top = double.tryParse(_top.text.trim());
    final right = double.tryParse(_right.text.trim());
    final bottom = double.tryParse(_bottom.text.trim());
    if (left == null || top == null || right == null || bottom == null) {
      setState(() => _error = 'Enter each margin as a number of inches.');
      return;
    }
    final setup = widget.request.initial.copyWith(
      header: _header.text,
      footer: _footer.text,
      leftInches: left,
      topInches: top,
      rightInches: right,
      bottomInches: bottom,
    );
    final problem = setup.marginProblem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    widget.request.complete(setup);
  }

  void _cancel() => widget.request.complete(null);

  @override
  Widget build(BuildContext context) {
    return XpDialogWindow(
      title: 'Page Setup',
      width: 380,
      onClose: _cancel,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledField(
                    label: 'Header:',
                    child: XpTextBox(
                      controller: _header,
                      focusNode: _focusNodes[0],
                      autofocus: true,
                      semanticLabel: 'Header',
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _LabeledField(
                    label: 'Footer:',
                    child: XpTextBox(
                      controller: _footer,
                      focusNode: _focusNodes[1],
                      semanticLabel: 'Footer',
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  XpGroupBox(
                    label: 'Margins (inches)',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _marginLabel('Left:'),
                            _marginBox(_left, _focusNodes[2], 'Left margin'),
                            const SizedBox(width: 24),
                            _marginLabel('Right:'),
                            _marginBox(_right, _focusNodes[3], 'Right margin'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _marginLabel('Top:'),
                            _marginBox(_top, _focusNodes[4], 'Top margin'),
                            const SizedBox(width: 24),
                            _marginLabel('Bottom:'),
                            _marginBox(
                              _bottom,
                              _focusNodes[5],
                              'Bottom margin',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 10),
                    Text(error, style: XpText.ui()),
                  ],
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
      ),
    );
  }

  Widget _marginLabel(String label) {
    return SizedBox(width: 46, child: Text(label, style: XpText.ui()));
  }

  Widget _marginBox(
    TextEditingController controller,
    FocusNode focusNode,
    String name,
  ) {
    return XpTextBox(
      controller: controller,
      focusNode: focusNode,
      semanticLabel: name,
      width: 60,
      inputFormatters: [_decimal],
      onSubmitted: (_) => _submit(),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: XpText.ui())),
        Expanded(child: child),
      ],
    );
  }
}
