import 'dart:math' as math;

import 'package:flutter/material.dart';

class CatFace extends StatelessWidget {
  const CatFace({super.key, this.width = _designWidth});

  /// CatPainter가 그리는 좌표계 크기.
  static const double _designWidth = 142;
  static const double _designHeight = 130;

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * _designHeight / _designWidth,
      child: const FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: CustomPaint(painter: CatPainter()),
        ),
      ),
    );
  }
}

class CatPainter extends CustomPainter {
  const CatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final face = Paint()..color = const Color(0xffffcf79);
    canvas.drawPath(
      Path()
        ..moveTo(26, 42)
        ..lineTo(23, 8)
        ..lineTo(56, 29)
        ..quadraticBezierTo(71, 22, 86, 29)
        ..lineTo(119, 8)
        ..lineTo(116, 44)
        ..quadraticBezierTo(130, 61, 123, 88)
        ..quadraticBezierTo(115, 119, 71, 122)
        ..quadraticBezierTo(27, 119, 19, 88)
        ..quadraticBezierTo(12, 60, 26, 42)
        ..close(),
      face,
    );
    canvas.drawCircle(const Offset(48, 69), 6, Paint()..color = const Color(0xff31363b));
    canvas.drawCircle(const Offset(94, 69), 6, Paint()..color = const Color(0xff31363b));
    canvas.drawPath(
      Path()
        ..moveTo(64, 84)
        ..lineTo(78, 84)
        ..lineTo(71, 91)
        ..close(),
      Paint()..color = const Color(0xffed6d84),
    );
    final mouthPaint = Paint()
      ..color = const Color(0xff45494d)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(const Rect.fromLTWH(56, 86, 15, 14), 0, math.pi, false, mouthPaint);
    canvas.drawArc(const Rect.fromLTWH(71, 86, 15, 14), 0, math.pi, false, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant CatPainter oldDelegate) => false;
}
