import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// A Luna scrollbar bound to a [ScrollController]. It has arrow buttons at both ends, a
/// track that pages when clicked, and a gradient thumb that can be dragged.
class XpScrollBar extends StatefulWidget {
  const XpScrollBar({
    super.key,
    required this.controller,
    required this.axis,
    this.lineStep = 13,
  });

  final ScrollController controller;
  final Axis axis;

  /// Distance one arrow click scrolls, in logical pixels.
  final double lineStep;

  @override
  State<XpScrollBar> createState() => _XpScrollBarState();
}

class _XpScrollBarState extends State<XpScrollBar> {
  Timer? _repeatTimer;
  bool _draggingThumb = false;
  double _dragStartAlong = 0;
  double _dragStartOffset = 0;

  bool get _vertical => widget.axis == Axis.vertical;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  _Geometry? _geometry(double length) {
    final controller = widget.controller;
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return null;
    }
    final position = controller.position;
    final track = length - 2 * XpMetrics.scrollbar;
    if (track <= 0) return null;
    final max = position.maxScrollExtent;
    final viewport = position.viewportDimension;
    final thumb = max <= 0
        ? track
        : math.max(
            math.min(track * viewport / (max + viewport), track),
            math.min(15.0, track),
          );
    final travel = track - thumb;
    final thumbStart = max <= 0 ? 0.0 : travel * position.pixels / max;
    return _Geometry(
      offset: position.pixels,
      max: max,
      track: track,
      thumbStart: thumbStart,
      thumbLength: thumb,
    );
  }

  void _scrollTo(double value) {
    final position = widget.controller.position;
    final target = value < 0
        ? 0.0
        : (value > position.maxScrollExtent ? position.maxScrollExtent : value);
    widget.controller.jumpTo(target);
  }

  void _pressTrack(Offset local, double length) {
    final geometry = _geometry(length);
    if (geometry == null) return;
    final along = _vertical ? local.dy : local.dx;
    final position = widget.controller.position;
    final page = position.viewportDimension;
    if (along < XpMetrics.scrollbar) {
      _startRepeat(() => _scrollTo(position.pixels - widget.lineStep));
    } else if (along > length - XpMetrics.scrollbar) {
      _startRepeat(() => _scrollTo(position.pixels + widget.lineStep));
    } else {
      final thumbStart = XpMetrics.scrollbar + geometry.thumbStart;
      if (along < thumbStart) {
        _startRepeat(() => _scrollTo(widget.controller.position.pixels - page));
      } else if (along > thumbStart + geometry.thumbLength) {
        _startRepeat(() => _scrollTo(widget.controller.position.pixels + page));
      }
    }
  }

  void _startRepeat(VoidCallback step) {
    _repeatTimer?.cancel();
    step();
    _repeatTimer = Timer(const Duration(milliseconds: 350), () {
      _repeatTimer = Timer.periodic(
        const Duration(milliseconds: 60),
        (_) => step(),
      );
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    // The bar has a fixed Luna thickness, so it sizes itself across the axis and can sit
    // in a Row or Column without the caller wrapping it.
    return SizedBox(
      width: _vertical ? XpMetrics.scrollbar : null,
      height: _vertical ? null : XpMetrics.scrollbar,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final length = _vertical
                  ? constraints.maxHeight
                  : constraints.maxWidth;
              final geometry = _geometry(length);
              return GestureDetector(
                // The text or list the bar scrolls is the accessible part. The bar itself
                // would only add an unnamed scrollable area.
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _pressTrack(details.localPosition, length),
                onTapUp: (_) => _stopRepeat(),
                onTapCancel: _stopRepeat,
                onPanStart: (details) {
                  final geometry = _geometry(length);
                  if (geometry == null) return;
                  final along = _alongAxis(details.localPosition);
                  final thumbStart = XpMetrics.scrollbar + geometry.thumbStart;
                  _draggingThumb =
                      along >= thumbStart &&
                      along <= thumbStart + geometry.thumbLength;
                  _dragStartAlong = along;
                  _dragStartOffset = geometry.offset;
                },
                onPanUpdate: (details) {
                  final geometry = _geometry(length);
                  if (!_draggingThumb ||
                      geometry == null ||
                      geometry.max <= 0) {
                    return;
                  }
                  final travel = geometry.track - geometry.thumbLength;
                  if (travel <= 0) return;
                  final moved =
                      _alongAxis(details.localPosition) - _dragStartAlong;
                  _scrollTo(_dragStartOffset + moved * geometry.max / travel);
                },
                onPanEnd: (_) => _draggingThumb = false,
                child: CustomPaint(
                  painter: _ScrollPainter(
                    vertical: _vertical,
                    geometry: geometry,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          );
        },
      ),
    );
  }

  double _alongAxis(Offset local) => _vertical ? local.dy : local.dx;
}

class _Geometry {
  const _Geometry({
    required this.offset,
    required this.max,
    required this.track,
    required this.thumbStart,
    required this.thumbLength,
  });

  final double offset;
  final double max;
  final double track;
  final double thumbStart;
  final double thumbLength;
}

class _ScrollPainter extends CustomPainter {
  _ScrollPainter({required this.vertical, required this.geometry})
    : dark = XpColors.dark;

  final bool dark;

  final bool vertical;
  final _Geometry? geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final length = vertical ? size.height : size.width;
    final thickness = vertical ? size.width : size.height;
    Rect along(double start, double extent) {
      return vertical
          ? Rect.fromLTWH(0, start, thickness, extent)
          : Rect.fromLTWH(start, 0, extent, thickness);
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = XpColors.scrollTrack);
    const buttonExtent = XpMetrics.scrollbar;
    final buttonPaint = Paint()..color = XpColors.scrollButton;
    canvas.drawRect(along(0, buttonExtent), buttonPaint);
    canvas.drawRect(along(length - buttonExtent, buttonExtent), buttonPaint);
    _drawArrow(canvas, along(0, buttonExtent).center, towardStart: true);
    _drawArrow(
      canvas,
      along(length - buttonExtent, buttonExtent).center,
      towardStart: false,
    );

    final geometry = this.geometry;
    if (geometry == null) return;
    final thumb = along(
      buttonExtent + geometry.thumbStart,
      geometry.thumbLength,
    ).deflate(0.5);
    final rrect = RRect.fromRectAndRadius(thumb, const Radius.circular(3));
    final shader = XpGradients.scrollThumb.createShader(thumb);
    canvas.drawRRect(rrect, Paint()..shader = shader);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = XpColors.thumbBorder,
    );
  }

  void _drawArrow(Canvas canvas, Offset center, {required bool towardStart}) {
    final paint = Paint()..color = XpColors.scrollArrow;
    final path = Path();
    if (vertical) {
      final tip = towardStart ? center.dy - 2 : center.dy + 2;
      final base = towardStart ? center.dy + 2 : center.dy - 2;
      path
        ..moveTo(center.dx - 3.5, base)
        ..lineTo(center.dx + 3.5, base)
        ..lineTo(center.dx, tip)
        ..close();
    } else {
      final tip = towardStart ? center.dx - 2 : center.dx + 2;
      final base = towardStart ? center.dx + 2 : center.dx - 2;
      path
        ..moveTo(base, center.dy - 3.5)
        ..lineTo(base, center.dy + 3.5)
        ..lineTo(tip, center.dy)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScrollPainter oldDelegate) {
    final a = geometry;
    final b = oldDelegate.geometry;
    return oldDelegate.vertical != vertical ||
        a?.offset != b?.offset ||
        a?.max != b?.max ||
        a?.thumbLength != b?.thumbLength ||
        a?.track != b?.track ||
        oldDelegate.dark != dark;
  }
}
