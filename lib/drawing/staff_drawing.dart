import 'package:flutter/material.dart';

import 'canvas_utils.dart';
import 'effect_drawing.dart';

/// 오선 한 칸 간격의 기준값. 세로 크기가 모두 여기에 비례한다.
const double baseStaffGap = 28;

void drawStaff(
  Canvas canvas, {
  required double y,
  double x = 62,
  double width = 676,
  double scale = 1,
  bool translucentCard = false,
}) {
  final gap = baseStaffGap * scale;
  if (translucentCard) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - 28 * scale,
          0,
          width + 52 * scale,
          y + gap * 4 + 42 * scale,
        ),
        Radius.circular(8 * scale),
      ),
      Paint()..color = Colors.white.withValues(alpha: .88),
    );
  }
  for (var i = 0; i < 5; i++) {
    canvas.drawLine(
      Offset(x, y + i * gap),
      Offset(x + width, y + i * gap),
      Paint()
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff454b50),
    );
  }
  drawCenteredText(
    canvas,
    '𝄞',
    Offset(x + 64 * scale, y + gap * 2),
    fontSize: 104 * scale,
    color: const Color(0xff353a3e),
    weight: FontWeight.w400,
  );
  canvas.drawLine(
    Offset(x + width, y),
    Offset(x + width, y + gap * 4),
    Paint()
      ..strokeWidth = 4 * scale
      ..color = const Color(0xff454b50),
  );
}

void drawChallengeScore(Canvas canvas, int active, bool done) {
  const y = 706.0;
  const gap = 28.0;
  drawStaff(canvas, y: y);
  const quarterX = [250.0, 340.0, 430.0, 520.0];
  final cY = y + gap * 5;
  for (var i = 0; i < quarterX.length; i++) {
    const color = Color(0xff30353a);
    drawMusicNote(canvas, Offset(quarterX[i], cY), color, .9);
  }
  canvas.drawLine(
    const Offset(600, y),
    const Offset(600, y + gap * 4),
    Paint()
      ..strokeWidth = 3
      ..color = const Color(0xff454b50),
  );
  const wholeColor = Color(0xff30353a);
  canvas.save();
  canvas.translate(684, cY);
  canvas.rotate(-.24);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 30, height: 20),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = wholeColor,
  );
  canvas.restore();
  for (final x in [...quarterX, 684.0]) {
    canvas.drawLine(
      Offset(x - 22, cY),
      Offset(x + 22, cY),
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0xff454b50),
    );
  }
}
