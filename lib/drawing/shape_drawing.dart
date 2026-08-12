import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';

/// [drawShape]가 실제로 차지하는 가로 폭 / size 비율.
///
/// 하트만 유독 옆으로 넓어서, 자리에 맞춰 크기를 정할 때 이 값을 나눠 줘야
/// 검은 건반 밑으로 삐져나가지 않는다.
double shapeWidthFactor(NoteShape shape) {
  switch (shape) {
    case NoteShape.heart:
      return 1.16;
    case NoteShape.circle:
      return 0.86;
    case NoteShape.star:
      return 0.96;
    case NoteShape.triangle:
      return 0.92;
    case NoteShape.apple:
      return 0.92;
    case NoteShape.flower:
      return 1.0;
    case NoteShape.cloud:
      return 0.98;
  }
}

void drawShape(Canvas canvas, NoteShape shape, Offset center, double size, Color color) {
  final paint = Paint()..color = color;
  switch (shape) {
    case NoteShape.heart:
      final s = size / 100;
      final path = Path()
        ..moveTo(center.dx, center.dy + 40 * s)
        ..cubicTo(center.dx - 58 * s, center.dy + 4 * s, center.dx - 50 * s, center.dy - 38 * s, center.dx - 21 * s, center.dy - 40 * s)
        ..cubicTo(center.dx - 7 * s, center.dy - 42 * s, center.dx, center.dy - 31 * s, center.dx, center.dy - 22 * s)
        ..cubicTo(center.dx, center.dy - 31 * s, center.dx + 7 * s, center.dy - 42 * s, center.dx + 21 * s, center.dy - 40 * s)
        ..cubicTo(center.dx + 50 * s, center.dy - 38 * s, center.dx + 58 * s, center.dy + 4 * s, center.dx, center.dy + 40 * s)
        ..close();
      canvas.drawPath(path, paint);
      break;
    case NoteShape.circle:
      canvas.drawCircle(center, size * .43, paint);
      break;
    case NoteShape.star:
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final radius = i.isEven ? size * .48 : size * .21;
        final angle = -math.pi / 2 + i * math.pi / 5;
        final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
      break;
    case NoteShape.triangle:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - size * .48)
          ..lineTo(center.dx - size * .46, center.dy + size * .40)
          ..lineTo(center.dx + size * .46, center.dy + size * .40)
          ..close(),
        paint,
      );
      break;
    case NoteShape.apple:
      canvas.drawCircle(center + Offset(-size * .15, size * .04), size * .31, paint);
      canvas.drawCircle(center + Offset(size * .15, size * .04), size * .31, paint);
      canvas.drawOval(
        Rect.fromCenter(center: center + Offset(size * .18, -size * .38), width: size * .28, height: size * .16),
        Paint()..color = const Color(0xff5c9948),
      );
      canvas.drawLine(
        center + Offset(0, -size * .22),
        center + Offset(size * .05, -size * .46),
        Paint()
          ..strokeWidth = size * .07
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff5f7847),
      );
      break;
    case NoteShape.flower:
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * size * .27, size * .23, paint);
      }
      canvas.drawCircle(center, size * .19, Paint()..color = const Color(0xffffd95b));
      break;
    case NoteShape.cloud:
      canvas.drawOval(
        Rect.fromCenter(center: center + Offset(0, size * .13), width: size * .86, height: size * .42),
        paint,
      );
      canvas.drawCircle(center + Offset(-size * .22, 0), size * .25, paint);
      canvas.drawCircle(center + Offset(size * .02, -size * .12), size * .32, paint);
      canvas.drawCircle(center + Offset(size * .27, size * .02), size * .22, paint);
      break;
  }
}
