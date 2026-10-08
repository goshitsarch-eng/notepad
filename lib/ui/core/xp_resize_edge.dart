import 'package:flutter/widgets.dart';

/// An invisible strip over the window frame. Dragging it starts an OS resize.
class XpResizeEdge extends StatelessWidget {
  const XpResizeEdge({super.key, required this.cursor, required this.onStart});

  final MouseCursor cursor;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onStart(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
