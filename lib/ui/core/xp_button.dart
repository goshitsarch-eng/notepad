import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// A Luna push button, 75×23 by default. Enter or Space presses it while it has focus.
/// A default button gets the blue inner ring that XP gives the dialog's main action.
class XpButton extends StatefulWidget {
  const XpButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDefault = false,
    this.autofocus = false,
    this.width = XpMetrics.buttonWidth,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDefault;
  final bool autofocus;
  final double width;

  @override
  State<XpButton> createState() => _XpButtonState();
}

class _XpButtonState extends State<XpButton> {
  final _focusNode = FocusNode(debugLabel: 'XpButton');
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final activates =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (!activates || event is! KeyDownEvent || widget.onPressed == null) {
      return KeyEventResult.ignored;
    }
    widget.onPressed!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: widget.onPressed,
          child: SizedBox(
            width: widget.width,
            height: XpMetrics.buttonHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _pressed
                    ? XpGradients.buttonPressed
                    : XpGradients.buttonFace,
                border: Border.all(color: XpColors.buttonBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: CustomPaint(
                painter: _ButtonRingPainter(
                  isDefault: widget.isDefault,
                  hovered: _hovered && enabled,
                  focused: _focused,
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    style: XpText.ui(
                      color: enabled ? XpColors.text : XpColors.grayText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonRingPainter extends CustomPainter {
  const _ButtonRingPainter({
    required this.isDefault,
    required this.hovered,
    required this.focused,
  });

  final bool isDefault;
  final bool hovered;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (isDefault) {
      paint.color = XpColors.buttonDefaultRing;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(2),
        ),
        paint,
      );
    }
    if (hovered) {
      paint.color = XpColors.buttonHoverRing;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
          const Radius.circular(2),
        ),
        paint,
      );
    }
    if (focused) {
      paint.color = XpColors.buttonFocusRing;
      canvas.drawRect(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonRingPainter oldDelegate) {
    return oldDelegate.isDefault != isDefault ||
        oldDelegate.hovered != hovered ||
        oldDelegate.focused != focused;
  }
}
