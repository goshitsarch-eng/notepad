import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// Wraps [child] in the 4px Luna window frame. The frame is painted underneath, so opaque
/// content such as the caption covers it where XP does.
class XpWindowFrame extends StatelessWidget {
  const XpWindowFrame({
    super.key,
    required this.active,
    required this.child,
    this.background,
  });

  final bool active;
  final Widget child;

  /// Painted under the frame and the child, for a window whose body is not opaque, such as
  /// a dialog. The child is transparent in that case and shows what lies behind it.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FramePainter(active: active, background: background),
          ),
        ),
        child,
      ],
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.active, this.background}) : dark = XpColors.dark;

  final bool dark;

  final bool active;
  final Color? background;

  @override
  void paint(Canvas canvas, Size size) {
    final background = this.background;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    final left = active ? XpColors.frameLeft : XpColors.frameInactive;
    final rightBottom = active
        ? XpColors.frameRightBottom
        : XpColors.frameInactive;
    final paint = Paint();
    // Inner bands first, so the outer ones paint over corners the way XP's shadows do.
    for (var depth = XpMetrics.frame.toInt() - 1; depth >= 0; depth--) {
      paint.color = rightBottom[depth];
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 1 - depth, size.width, 1),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - 1 - depth, 0, 1, size.height),
        paint,
      );
      paint.color = left[depth];
      canvas.drawRect(
        Rect.fromLTWH(depth.toDouble(), 0, 1, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.dark != dark ||
      oldDelegate.background != background;
}
