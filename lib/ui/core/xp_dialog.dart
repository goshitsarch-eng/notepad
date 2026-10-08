import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_caption.dart';
import 'package:xp_notepad/ui/core/xp_frame.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// An XP dialog window: a 25px title bar with a close button, the window frame, and
/// [child] as the body. Dragging the title bar moves the dialog inside the Notepad window.
class XpDialogWindow extends StatefulWidget {
  const XpDialogWindow({
    super.key,
    required this.title,
    required this.width,
    required this.child,
    this.onClose,
  });

  final String title;
  final double width;
  final Widget child;
  final VoidCallback? onClose;

  @override
  State<XpDialogWindow> createState() => _XpDialogWindowState();
}

class _XpDialogWindowState extends State<XpDialogWindow> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: SizedBox(
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
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) =>
                    setState(() => _offset += details.delta),
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
    );
  }
}

/// Swallows pointer input over the window while a modal dialog is open.
class XpModalBarrier extends StatelessWidget {
  const XpModalBarrier({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: const SizedBox.expand(),
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
