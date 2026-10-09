import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// A Luna check box with its label. Click or Space toggles it.
class XpCheckBox extends StatefulWidget {
  const XpCheckBox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool autofocus;

  @override
  State<XpCheckBox> createState() => _XpCheckBoxState();
}

class _XpCheckBoxState extends State<XpCheckBox> {
  final _focusNode = FocusNode(debugLabel: 'XpCheckBox');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() => widget.onChanged(!widget.value);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      checked: widget.value,
      label: widget.label,
      focusable: true,
      focused: _focused,
      onTap: _toggle,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.space) {
            _toggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              _toggle();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Box(
                  shape: BoxShape.rectangle,
                  child: widget.value
                      ? CustomPaint(painter: _CheckPainter())
                      : null,
                ),
                const SizedBox(width: 6),
                _FocusCue(
                  focused: _focused,
                  child: Text(widget.label, style: XpText.ui()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Luna radio button with its label. Clicking selects it. Parents keep the group state.
/// The arrow keys call [onMove] with -1 (left or up) or 1 (right or down), and the parent
/// then selects and focuses the neighbour, as the arrow keys do in a Windows radio group.
class XpRadioButton extends StatefulWidget {
  const XpRadioButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.onMove,
    this.focusNode,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<int>? onMove;

  /// Lets the parent move focus to this button. Null uses a node of the button's own.
  final FocusNode? focusNode;

  @override
  State<XpRadioButton> createState() => _XpRadioButtonState();
}

class _XpRadioButtonState extends State<XpRadioButton> {
  FocusNode? _ownNode;
  bool _focused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'XpRadioButton'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      widget.onSelected();
      return KeyEventResult.handled;
    }
    final onMove = widget.onMove;
    if (onMove == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      onMove(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      onMove(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      checked: widget.selected,
      inMutuallyExclusiveGroup: true,
      label: widget.label,
      focusable: true,
      focused: _focused,
      onTap: widget.onSelected,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              widget.onSelected();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Box(
                  shape: BoxShape.circle,
                  child: widget.selected
                      ? Center(
                          child: SizedBox.square(
                            dimension: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: XpColors.checkMark,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                _FocusCue(
                  focused: _focused,
                  child: Text(widget.label, style: XpText.ui()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dotted rectangle XP draws round the label of the control that has keyboard focus.
/// It shows only while the keyboard is in use, so clicking a box does not draw it.
class _FocusCue extends StatelessWidget {
  const _FocusCue({required this.focused, required this.child});

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    // The rectangle is drawn just outside the label, so showing it moves nothing.
    return CustomPaint(
      foregroundPainter: visible ? _DottedRectPainter(XpColors.text) : null,
      child: child,
    );
  }
}

class _DottedRectPainter extends CustomPainter {
  const _DottedRectPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final box = Offset.zero & size;
    final outer = box.inflate(1);
    // One pixel on, one off, along each side.
    for (var x = outer.left; x < outer.right; x += 2) {
      canvas.drawRect(Rect.fromLTWH(x, outer.top, 1, 1), paint);
      canvas.drawRect(Rect.fromLTWH(x, outer.bottom - 1, 1, 1), paint);
    }
    for (var y = outer.top; y < outer.bottom; y += 2) {
      canvas.drawRect(Rect.fromLTWH(outer.left, y, 1, 1), paint);
      canvas.drawRect(Rect.fromLTWH(outer.right - 1, y, 1, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Box extends StatelessWidget {
  const _Box({required this.shape, this.child});

  final BoxShape shape;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == BoxShape.circle;
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: shape,
        gradient: XpGradients.checkBox,
        border: Border.all(color: XpColors.boxBorder),
        borderRadius: isCircle ? null : BorderRadius.circular(2),
      ),
      child: child,
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter() : dark = XpColors.dark;

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, 6.5)
      ..lineTo(5.5, 9)
      ..lineTo(10, 3.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = XpColors.checkMark,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.dark != dark;
}
