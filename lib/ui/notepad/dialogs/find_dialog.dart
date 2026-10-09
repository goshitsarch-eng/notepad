import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:xp_notepad/domain/text/text_search.dart';
import 'package:xp_notepad/ui/core/xp_button.dart';
import 'package:xp_notepad/ui/core/xp_check.dart';
import 'package:xp_notepad/ui/core/xp_dialog.dart';
import 'package:xp_notepad/ui/core/xp_fields.dart';
import 'package:xp_notepad/ui/notepad/notepad_view_model.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Edit > Find and Edit > Replace. The dialog is modeless, as in XP: the text stays
/// editable while it is open, and clicking into the text moves focus there.
class FindDialog extends StatefulWidget {
  const FindDialog({super.key, required this.replace});

  final bool replace;

  @override
  State<FindDialog> createState() => _FindDialogState();
}

class _FindDialogState extends State<FindDialog> {
  late final NotepadViewModel _vm;
  late final TextEditingController _find;
  final _replace = TextEditingController();
  final _findFocus = FocusNode(debugLabel: 'find what');
  final _replaceFocus = FocusNode(debugLabel: 'replace with');
  final _upFocus = FocusNode(debugLabel: 'direction up');
  final _downFocus = FocusNode(debugLabel: 'direction down');
  late bool _matchCase;
  late bool _wholeWord;
  late bool _down;

  @override
  void initState() {
    super.initState();
    _vm = context.read<NotepadViewModel>();
    final last = _vm.lastSearch;
    // The query starts out selected, so typing replaces it instead of adding to it.
    _find = TextEditingController.fromValue(
      TextEditingValue(
        text: last.query,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: last.query.length,
        ),
      ),
    );
    _matchCase = last.matchCase;
    _wholeWord = last.wholeWord;
    _down = last.forward;
    _vm.findRequests.addListener(_onFindRequested);
    _vm.findFocusRequests.addListener(_focusFindBox);
  }

  /// Ctrl+F, Edit > Find and Ctrl+H asked again while this dialog is open. The box loads
  /// the current query and takes focus, so typing goes to the dialog, not the document.
  void _onFindRequested() {
    final query = _vm.lastSearch.query;
    _find.value = TextEditingValue(
      text: query,
      selection: TextSelection(baseOffset: 0, extentOffset: query.length),
    );
    _findFocus.requestFocus();
  }

  /// Gives focus back to the Find box when a message or menu closes, without touching the
  /// text the user has typed there.
  void _focusFindBox() => _findFocus.requestFocus();

  @override
  void dispose() {
    _vm.findRequests.removeListener(_onFindRequested);
    _vm.findFocusRequests.removeListener(_focusFindBox);
    _find.dispose();
    _replace.dispose();
    _findFocus.dispose();
    _replaceFocus.dispose();
    _upFocus.dispose();
    _downFocus.dispose();
    super.dispose();
  }

  /// The Replace dialog has no Direction group, so it always searches down. Otherwise an
  /// earlier Find upwards would make Replace search upwards with nothing on screen to say so.
  SearchOptions get _options => SearchOptions(
    query: _find.text,
    matchCase: _matchCase,
    wholeWord: _wholeWord,
    forward: widget.replace || _down,
  );

  void _findNext() {
    if (_find.text.isEmpty) return;
    _vm.findNext(_options);
  }

  void _replaceOne() {
    if (_find.text.isEmpty) return;
    _vm.replaceCurrent(_options, _replace.text);
  }

  void _replaceEvery() {
    if (_find.text.isEmpty) return;
    _vm.replaceAllMatches(_options, _replace.text);
  }

  void _close() => _vm.closeFind();

  @override
  Widget build(BuildContext context) {
    // Its own focus scope lets the Find box take focus even though the editor is focused.
    return FocusScope(child: _dialog());
  }

  Widget _dialog() {
    final replace = widget.replace;
    return XpDialogWindow(
      title: replace ? 'Replace' : 'Find',
      width: 380,
      onClose: _close,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _labeled(
                    'Find what:',
                    XpTextBox(
                      controller: _find,
                      focusNode: _findFocus,
                      autofocus: true,
                      semanticLabel: 'Find what',
                      onSubmitted: (_) => _findNext(),
                    ),
                  ),
                  if (replace) ...[
                    const SizedBox(height: 6),
                    _labeled(
                      'Replace with:',
                      XpTextBox(
                        controller: _replace,
                        focusNode: _replaceFocus,
                        semanticLabel: 'Replace with',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  XpCheckBox(
                    label: 'Match whole word only',
                    value: _wholeWord,
                    onChanged: (value) => setState(() => _wholeWord = value),
                  ),
                  const SizedBox(height: 4),
                  XpCheckBox(
                    label: 'Match case',
                    value: _matchCase,
                    onChanged: (value) => setState(() => _matchCase = value),
                  ),
                  if (!replace) ...[
                    const SizedBox(height: 8),
                    _directionGroup(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 75,
              child: Column(
                children: [
                  XpButton(
                    label: 'Find Next',
                    isDefault: true,
                    onPressed: _findNext,
                  ),
                  if (replace) ...[
                    const SizedBox(height: 6),
                    XpButton(label: 'Replace', onPressed: _replaceOne),
                    const SizedBox(height: 6),
                    XpButton(label: 'Replace All', onPressed: _replaceEvery),
                  ],
                  const SizedBox(height: 6),
                  XpButton(label: 'Cancel', onPressed: _close),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: XpText.ui())),
        const SizedBox(width: 6),
        Expanded(child: field),
      ],
    );
  }

  /// The arrow keys in the Direction group select the neighbour and move focus to it.
  void _moveDirection(int step) {
    setState(() => _down = step > 0);
    (step > 0 ? _downFocus : _upFocus).requestFocus();
  }

  Widget _directionGroup() {
    return XpGroupBox(
      label: 'Direction',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          XpRadioButton(
            label: 'Up',
            selected: !_down,
            focusNode: _upFocus,
            onSelected: () => setState(() => _down = false),
            onMove: _moveDirection,
          ),
          const SizedBox(width: 24),
          XpRadioButton(
            label: 'Down',
            selected: _down,
            focusNode: _downFocus,
            onSelected: () => setState(() => _down = true),
            onMove: _moveDirection,
          ),
        ],
      ),
    );
  }
}
