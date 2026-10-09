import 'dart:math' as math;

import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_caption.dart';
import 'package:xp_notepad/ui/core/xp_frame.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// An XP dialog window: a 25px title bar with a close button, the window frame, and
/// [child] as the body. Dragging the title bar moves the dialog inside the Notepad window,
/// and never so far that the title bar is out of reach.
class XpDialogWindow extends StatefulWidget {
  const XpDialogWindow({
    super.key,
    required this.title,
    required this.width,
    required this.child,
    this.onClose,
    this.alert = false,
  });

  final String title;
  final double width;
  final Widget child;
  final VoidCallback? onClose;

  /// True for a message box, which a screen reader announces as an alert.
  final bool alert;

  @override
  State<XpDialogWindow> createState() => _XpDialogWindowState();
}

class _XpDialogWindowState extends State<XpDialogWindow> {
  /// How far the dialog has been dragged from the centre of the window.
  Offset _offset = Offset.zero;
  final _dialogKey = GlobalKey();

  void _drag(DragUpdateDetails details, Size area) {
    final size = _dialogKey.currentContext?.size;
    if (size == null) return;
    // Clamped as it is stored, so a drag past the edge does not have to be dragged back
    // before the dialog moves again.
    setState(
      () => _offset = _DialogLayout.clamp(_offset + details.delta, area, size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        return CustomSingleChildLayout(
          delegate: _DialogLayout(_offset),
          child: Semantics(
            role: widget.alert
                ? SemanticsRole.alertDialog
                : SemanticsRole.dialog,
            label: widget.title,
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            child: SizedBox(
              key: _dialogKey,
              width: widget.width,
              child: XpWindowFrame(
                active: true,
                // Dialog bodies are opaque in XP. Without this the dialog showed the editor
                // and any window behind it through its labels and empty areas.
                background: XpColors.face,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      // Dragging the title bar is not offered to assistive technology.
                      excludeFromSemantics: true,
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) => _drag(details, area),
                      child: _DialogTitleBar(
                        title: widget.title,
                        onClose: widget.onClose,
                      ),
                    ),
                    Padding(
                      // Content padding of 11px on the sides, 8px above the 4px bottom frame.
                      padding: const EdgeInsets.fromLTRB(
                        11,
                        11,
                        11,
                        8 + XpMetrics.frame,
                      ),
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Centres the dialog in the window, then applies the drag offset. The title bar always
/// stays inside the window with at least [_grab] pixels of it showing to the side, so the
/// dialog can be found and moved back. A dialog taller than the window starts with its
/// title bar at the top edge rather than above it.
class _DialogLayout extends SingleChildLayoutDelegate {
  const _DialogLayout(this.offset);

  final Offset offset;

  static const _grab = 48.0;

  /// [offset] limited to the drags that leave the title bar reachable.
  static Offset clamp(Offset offset, Size area, Size dialog) {
    final centreX = (area.width - dialog.width) / 2;
    final centreY = (area.height - dialog.height) / 2;
    final minX = math.min(_grab - dialog.width, area.width - _grab);
    final maxX = math.max(_grab - dialog.width, area.width - _grab);
    final minY = 0.0;
    final maxY = math.max(0.0, area.height - XpMetrics.dialogTitleHeight);
    return Offset(
      (centreX + offset.dx).clamp(minX, maxX) - centreX,
      (centreY + offset.dy).clamp(minY, maxY) - centreY,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final centre = Offset(
      (size.width - childSize.width) / 2,
      (size.height - childSize.height) / 2,
    );
    return centre + clamp(offset, size, childSize);
  }

  @override
  bool shouldRelayout(_DialogLayout oldDelegate) =>
      oldDelegate.offset != offset;
}

/// Swallows pointer input over the window while a modal dialog is open.
class XpModalBarrier extends StatelessWidget {
  const XpModalBarrier({super.key});

  @override
  Widget build(BuildContext context) {
    // The barrier also hides what lies behind the dialog from assistive technology, so a
    // screen reader cannot reach the menus or the text under it.
    return BlockSemantics(
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: XpMetrics.dialogTitleHeight,
      decoration: BoxDecoration(gradient: XpGradients.titleActive),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            right: 26,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: XpText.title(active: true),
              ),
            ),
          ),
          if (onClose != null)
            Positioned(
              top: 2,
              right: 3,
              child: XpCaptionButton(
                kind: XpCaptionButtonKind.close,
                active: true,
                onPressed: onClose!,
              ),
            ),
        ],
      ),
    );
  }
}
