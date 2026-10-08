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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() => widget.onChanged(!widget.value);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
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
              Text(widget.label, style: XpText.ui()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Luna radio button with its label. Clicking selects it. Parents keep the group state.
class XpRadioButton extends StatefulWidget {
  const XpRadioButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  State<XpRadioButton> createState() => _XpRadioButtonState();
}

class _XpRadioButtonState extends State<XpRadioButton> {
  final _focusNode = FocusNode(debugLabel: 'XpRadioButton');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.space) {
          widget.onSelected();
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
              Text(widget.label, style: XpText.ui()),
            ],
          ),
        ),
      ),
    );
  }
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
