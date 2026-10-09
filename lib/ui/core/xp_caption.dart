import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// The 30px Luna title bar: an icon, the title, and minimize, maximize and close buttons.
/// Dragging the bar moves the window, and two quick presses toggle maximize, as in XP.
class XpCaption extends StatefulWidget {
  const XpCaption({
    super.key,
    required this.title,
    required this.active,
    required this.maximized,
    required this.onDragStart,
    required this.onToggleMaximize,
    required this.onMinimize,
    required this.onClose,
    this.onWindowMenu,
  });

  final String title;
  final bool active;
  final bool maximized;
  final VoidCallback onDragStart;
  final VoidCallback onToggleMaximize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  /// Opens the window menu: a click on the icon, or a right click on the bar.
  final VoidCallback? onWindowMenu;

  @override
  State<XpCaption> createState() => _XpCaptionState();
}

class _XpCaptionState extends State<XpCaption> {
  static const _doubleClickTime = Duration(milliseconds: 400);
  static const _doubleClickSlop = 6.0;

  Duration? _lastPressTime;
  Offset? _lastPressPosition;

  /// Detects a double click from raw pointer events. A gesture-based double tap would make
  /// the buttons on this bar wait out the double-click window before they respond.
  void _onPointerDown(PointerDownEvent event) {
    if ((event.buttons & kSecondaryButton) != 0) {
      widget.onWindowMenu?.call();
      return;
    }
    // Only the primary button counts. Two quick right-button presses are not a double click.
    if ((event.buttons & kPrimaryButton) == 0) return;
    final lastTime = _lastPressTime;
    final lastPosition = _lastPressPosition;
    final isDoubleClick =
        lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime < _doubleClickTime &&
        (event.localPosition - lastPosition).distance < _doubleClickSlop;
    if (isDoubleClick) {
      _lastPressTime = null;
      _lastPressPosition = null;
      widget.onToggleMaximize();
    } else {
      _lastPressTime = event.timeStamp;
      _lastPressPosition = event.localPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: XpMetrics.captionHeight,
      decoration: BoxDecoration(
        gradient: widget.active
            ? XpGradients.titleActive
            : XpGradients.titleInactive,
      ),
      child: Stack(
        children: [
          // The background takes drags and double clicks. The buttons sit above it.
          Positioned.fill(
            child: Listener(
              onPointerDown: _onPointerDown,
              child: GestureDetector(
                // Dragging the bar is not something assistive technology can do, so it
                // is not offered as a scrollable area.
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => widget.onDragStart(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 7,
            child: Semantics(
              container: true,
              button: true,
              label: 'Window menu',
              onTap: widget.onWindowMenu,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: widget.onWindowMenu,
                child: const CustomPaint(
                  size: Size.square(16),
                  painter: NotepadIconPainter(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 75,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: XpText.title(active: widget.active),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                XpCaptionButton(
                  kind: XpCaptionButtonKind.minimize,
                  active: widget.active,
                  onPressed: widget.onMinimize,
                ),
                const SizedBox(width: 2),
                XpCaptionButton(
                  kind: widget.maximized
                      ? XpCaptionButtonKind.restore
                      : XpCaptionButtonKind.maximize,
                  active: widget.active,
                  onPressed: widget.onToggleMaximize,
                ),
                const SizedBox(width: 2),
                XpCaptionButton(
                  kind: XpCaptionButtonKind.close,
                  active: widget.active,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum XpCaptionButtonKind { minimize, maximize, restore, close }

/// A 21×21 Luna caption button with hover and pressed states.
class XpCaptionButton extends StatefulWidget {
  const XpCaptionButton({
    super.key,
    required this.kind,
    required this.active,
    required this.onPressed,
  });

  final XpCaptionButtonKind kind;
  final bool active;
  final VoidCallback onPressed;

  @override
  State<XpCaptionButton> createState() => _XpCaptionButtonState();
}

class _XpCaptionButtonState extends State<XpCaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _background {
    final isClose = widget.kind == XpCaptionButtonKind.close;
    if (isClose) {
      if (_pressed) return XpColors.closeButtonPressed;
      if (_hovered) return XpColors.closeButtonHover;
      return XpColors.closeButton;
    }
    if (!widget.active) return XpColors.captionInactive;
    if (_pressed) return XpColors.captionPressed;
    if (_hovered) return XpColors.captionHover;
    return XpColors.captionActive;
  }

  String get _label => switch (widget.kind) {
    XpCaptionButtonKind.minimize => 'Minimize',
    XpCaptionButtonKind.maximize => 'Maximize',
    XpCaptionButtonKind.restore => 'Restore',
    XpCaptionButtonKind.close => 'Close',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: _label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: SizedBox.square(
          dimension: 21,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: XpColors.buttonGlyphEdge),
            ),
            child: CustomPaint(painter: _CaptionGlyphPainter(widget.kind)),
          ),
        ),
      ),
    );
  }
}

class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter(this.kind);

  final XpCaptionButtonKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = const Color(0xFFFFFFFF);
    switch (kind) {
      case XpCaptionButtonKind.minimize:
        canvas.drawRect(const Rect.fromLTWH(5, 13, 7, 3), white);
      case XpCaptionButtonKind.maximize:
        canvas.drawRect(const Rect.fromLTWH(5, 5, 11, 3), white);
        canvas.drawRect(const Rect.fromLTWH(5, 8, 1, 7), white);
        canvas.drawRect(const Rect.fromLTWH(15, 8, 1, 7), white);
        canvas.drawRect(const Rect.fromLTWH(5, 14, 11, 1), white);
      case XpCaptionButtonKind.restore:
        canvas.drawRect(const Rect.fromLTWH(8, 4, 8, 2), white);
        canvas.drawRect(const Rect.fromLTWH(15, 4, 1, 6), white);
        canvas.drawRect(const Rect.fromLTWH(4, 8, 9, 3), white);
        canvas.drawRect(const Rect.fromLTWH(4, 11, 1, 5), white);
        canvas.drawRect(const Rect.fromLTWH(12, 11, 1, 5), white);
        canvas.drawRect(const Rect.fromLTWH(4, 15, 9, 1), white);
      case XpCaptionButtonKind.close:
        final cross = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 2;
        canvas.drawLine(const Offset(6, 6), const Offset(15, 15), cross);
        canvas.drawLine(const Offset(15, 6), const Offset(6, 15), cross);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyphPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
