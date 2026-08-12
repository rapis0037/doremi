import 'package:flutter/material.dart';

import '../core/models.dart';

class RestPainter extends CustomPainter {
  const RestPainter(this.kind);
  final RestKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 56, size.height / 56);
    final paint = Paint()..color = const Color(0xff41474c);
    switch (kind) {
      case RestKind.half:
        canvas.drawRect(Rect.fromLTWH(10, 26, 36, 9), paint);
        canvas.drawLine(
          const Offset(7, 36),
          const Offset(49, 36),
          Paint()
            ..color = const Color(0xff41474c)
            ..strokeWidth = 3,
        );
        break;
      case RestKind.three:
        final path = Path()
          ..moveTo(31, 7)
          ..cubicTo(17, 18, 40, 24, 22, 35)
          ..cubicTo(10, 44, 32, 48, 24, 53);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xff41474c)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        break;
      case RestKind.whole:
        canvas.drawLine(
          const Offset(7, 21),
          const Offset(49, 21),
          Paint()
            ..color = const Color(0xff41474c)
            ..strokeWidth = 3,
        );
        canvas.drawRect(Rect.fromLTWH(12, 21, 32, 11), paint);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RestPainter oldDelegate) => false;
}
