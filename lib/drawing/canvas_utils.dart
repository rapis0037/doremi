import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';

void scaleScene(Canvas canvas, Size size, [Size scene = sceneSize]) {
  canvas.scale(size.width / scene.width, size.height / scene.height);
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

/// [box] 안에 들어가는 최대 크기로 [text]를 가운데 그린다.
///
/// [maxFontSize]에서 시작해 박스를 넘치면 그만큼 줄인다. '높은 도'처럼 긴
/// 계이름이 건반 폭을 벗어나지 않게 하는 용도.
void drawFittedText(
  Canvas canvas,
  String text,
  Rect box, {
  required double maxFontSize,
  required Color color,
  required FontWeight weight,
}) {
  TextPainter layout(double fontSize) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

  var painter = layout(maxFontSize);
  final scale = math.min(box.width / painter.width, box.height / painter.height);
  if (scale < 1) painter = layout(maxFontSize * scale);
  painter.paint(canvas, box.center - Offset(painter.width / 2, painter.height / 2));
}
