import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// Icons drawn with canvas primitives. They evoke the XP shell icons without copying them.
enum XpMessageIconKind { information, warning, error }

/// A notepad: a ruled page with a blue binding. Drawn on a 16×16 grid, scaled to [size].
class NotepadIconPainter extends CustomPainter {
  const NotepadIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawRect(
      const Rect.fromLTWH(2, 1, 12, 14),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawRect(
      const Rect.fromLTWH(2, 1, 12, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF5A7DBF),
    );
    canvas.drawRect(
      const Rect.fromLTWH(2, 1, 12, 3),
      Paint()..color = const Color(0xFF2B5FD1),
    );
    final rule = Paint()..color = const Color(0xFF9DB6E4);
    for (final y in [7.0, 9.0, 11.0, 13.0]) {
      canvas.drawRect(Rect.fromLTWH(4, y, 8, 1), rule);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NotepadIconPainter oldDelegate) => false;
}

/// A yellow folder on a 16×16 grid.
class FolderIconPainter extends CustomPainter {
  const FolderIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawRect(
      const Rect.fromLTWH(1, 3, 6, 3),
      Paint()..color = const Color(0xFFE2B94C),
    );
    final body = const Rect.fromLTWH(1, 5, 14, 9);
    canvas.drawRect(body, Paint()..color = const Color(0xFFF7DA7A));
    canvas.drawRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFC29A37),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(FolderIconPainter oldDelegate) => false;
}

/// A plain document page with a folded corner, on a 16×16 grid.
class DocumentIconPainter extends CustomPainter {
  const DocumentIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 16, size.height / 16);
    final page = Path()
      ..moveTo(3, 1)
      ..lineTo(10, 1)
      ..lineTo(13, 4)
      ..lineTo(13, 15)
      ..lineTo(3, 15)
      ..close();
    canvas.drawPath(page, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawPath(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF7F9DB9),
    );
    final rule = Paint()..color = const Color(0xFF9DB6E4);
    for (final y in [7.0, 9.0, 11.0]) {
      canvas.drawRect(Rect.fromLTWH(5, y, 6, 1), rule);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DocumentIconPainter oldDelegate) => false;
}

/// The 32×32 icon at the left of a message box.
class MessageIconPainter extends CustomPainter {
  const MessageIconPainter(this.kind);

  final XpMessageIconKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    switch (kind) {
      case XpMessageIconKind.information:
        _disc(canvas, const Color(0xFF2A6BD6), 'i');
      case XpMessageIconKind.warning:
        _triangle(canvas);
      case XpMessageIconKind.error:
        _errorDisc(canvas);
    }
    canvas.restore();
  }

  void _disc(Canvas canvas, Color color, String glyph) {
    canvas.drawCircle(const Offset(16, 16), 14, Paint()..color = color);
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: const TextStyle(
          fontFamily: 'Liberation Sans',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(16 - painter.width / 2, 16 - painter.height / 2),
    );
  }

  void _triangle(Canvas canvas) {
    final path = Path()
      ..moveTo(16, 2)
      ..lineTo(31, 29)
      ..lineTo(1, 29)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF2C12E));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF8A6A12),
    );
    canvas.drawRect(
      const Rect.fromLTWH(14.5, 10, 3, 11),
      Paint()..color = const Color(0xFF1B1B1B),
    );
    canvas.drawRect(
      const Rect.fromLTWH(14.5, 23, 3, 3),
      Paint()..color = const Color(0xFF1B1B1B),
    );
  }

  void _errorDisc(Canvas canvas) {
    canvas.drawCircle(
      const Offset(16, 16),
      14,
      Paint()..color = const Color(0xFFD62F2F),
    );
    final cross = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, 10), const Offset(22, 22), cross);
    canvas.drawLine(const Offset(22, 10), const Offset(10, 22), cross);
  }

  @override
  bool shouldRepaint(MessageIconPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// Edge decoration at the bottom right of a window with a status bar.
class SizeGripPainter extends CustomPainter {
  SizeGripPainter() : dark = XpColors.dark;

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = XpColors.ruleDark
      ..strokeWidth = 1;
    final light = Paint()
      ..color = XpColors.ruleLight
      ..strokeWidth = 1;
    for (final offset in [0.0, 4.0, 8.0]) {
      canvas.drawLine(Offset(12 - offset, 1), Offset(1, 12 - offset), dark);
      canvas.drawLine(Offset(13 - offset, 2), Offset(2, 13 - offset), light);
    }
  }

  @override
  bool shouldRepaint(SizeGripPainter oldDelegate) => oldDelegate.dark != dark;
}

/// A label as drawn in the menu bar or a dialog, measured so that layouts can reserve space.
double measureUiText(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: XpText.ui()),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}
