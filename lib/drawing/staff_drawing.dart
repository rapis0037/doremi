import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'canvas_utils.dart';
import 'effect_drawing.dart';

void drawStaff(Canvas canvas, {required double y, bool translucentCard = false}) {
  const x = 62.0;
  const width = 676.0;
  const gap = 28.0;
  if (translucentCard) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(36, y - 42, 728, gap * 4 + 84),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: .88),
    );
  }
  for (var i = 0; i < 5; i++) {
    canvas.drawLine(
      Offset(x, y + i * gap),
      Offset(x + width, y + i * gap),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xff454b50),
    );
  }
  drawCenteredText(
    canvas,
    '𝄞',
    Offset(126, y + gap * 2),
    fontSize: 104,
    color: const Color(0xff353a3e),
    weight: FontWeight.w400,
  );
  canvas.drawLine(
    Offset(738, y),
    Offset(738, y + gap * 4),
    Paint()
      ..strokeWidth = 4
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
    final color = !done && active == i ? notes.first.color : const Color(0xff30353a);
    drawMusicNote(canvas, Offset(quarterX[i], cY), color, .9);
  }
  canvas.drawLine(
    const Offset(600, y),
    const Offset(600, y + gap * 4),
    Paint()
      ..strokeWidth = 3
      ..color = const Color(0xff454b50),
  );
  final wholeColor = !done && active == 4 ? notes.first.color : const Color(0xff30353a);
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
