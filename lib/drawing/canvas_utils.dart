import 'package:flutter/material.dart';

import '../core/constants.dart';

void scaleScene(Canvas canvas, Size size) {
  canvas.scale(size.width / sceneSize.width, size.height / sceneSize.height);
}

void drawCenteredText(
  Canvas canvas,
  String text,
  Offset center, {
  required double fontSize,
  required Color color,
  required FontWeight weight,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}
