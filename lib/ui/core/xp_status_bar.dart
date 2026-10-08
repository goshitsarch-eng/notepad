import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// The 19px status bar under the editor, with a sunken "Ln 1, Col 1" field and a size grip.
class XpStatusBar extends StatelessWidget {
  const XpStatusBar({super.key, required this.text, this.onResizeStart});

  final String text;

  /// Starts a window resize when the size grip is dragged.
  final VoidCallback? onResizeStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      // No top margin: a gap there would show the transparent window behind the bar.
      margin: const EdgeInsets.symmetric(horizontal: XpMetrics.frame),
      height: XpMetrics.statusBarHeight,
      padding: const EdgeInsets.only(left: 2),
      color: XpColors.face,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(minWidth: 110),
              height: 17,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: XpColors.ruleDark),
                  left: BorderSide(color: XpColors.ruleDark),
                  bottom: BorderSide(color: XpColors.ruleLight),
                  right: BorderSide(color: XpColors.ruleLight),
                ),
              ),
              child: Text(text, maxLines: 1, style: XpText.ui()),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.resizeDownRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: onResizeStart == null
                  ? null
                  : (_) => onResizeStart!(),
              child: SizedBox(
                width: 13,
                height: 13,
                child: CustomPaint(painter: SizeGripPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
