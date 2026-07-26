import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import 'canvas_utils.dart';
import 'shape_drawing.dart';

void drawMusicNote(Canvas canvas, Offset center, Color color, double scale) {
  canvas.drawOval(
    Rect.fromCenter(center: center, width: 30 * scale, height: 22 * scale),
    Paint()..color = color,
  );
  canvas.drawLine(
    Offset(center.dx + 13 * scale, center.dy),
    Offset(center.dx + 13 * scale, center.dy - 57 * scale),
    Paint()
      ..color = color
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(center.dx - 25 * scale, center.dy),
    Offset(center.dx + 25 * scale, center.dy),
    Paint()
      ..color = const Color(0xff454b50)
      ..strokeWidth = 3,
  );
}

void drawFlightSparkles(Canvas canvas, Offset center, double t, Color color) {
  final rng = math.Random(31);
  for (var i = 0; i < 24; i++) {
    final angle = rng.nextDouble() * math.pi * 2;
    final radius = 38 + rng.nextDouble() * 72;
    final lag = (t * 18 - i) / 18;
    if (lag < 0) continue;
    final p = center - Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    canvas.drawCircle(
      p,
      2.5 + rng.nextDouble() * 5,
      Paint()..color = (i.isEven ? color : const Color(0xffffd84b)).withValues(alpha: .72),
    );
  }
}

void drawBurst(Canvas canvas, Offset center, double t, Color color) {
  final eased = Curves.easeOutCubic.transform(t);
  for (var i = 0; i < 26; i++) {
    final angle = i / 26 * math.pi * 2;
    final distance = 26 + eased * (74 + (i % 5) * 9);
    final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
    final particleColor = [color, const Color(0xffffd74a), const Color(0xff6fd7ec), Colors.white][i % 4];
    canvas.drawCircle(
      p,
      7 * (1 - t).clamp(.1, 1.0).toDouble(),
      Paint()..color = particleColor.withValues(alpha: 1 - t),
    );
  }
}

void drawConfetti(Canvas canvas, double t) {
  const colors = [
    Color(0xffff4f7d),
    Color(0xffffcc3d),
    Color(0xff4fa5ed),
    Color(0xff83ce5b),
    Color(0xffa980e8),
    Color(0xffff8b4d),
  ];
  final rng = math.Random(77);
  for (var i = 0; i < 90; i++) {
    final startX = rng.nextDouble() * 800;
    final delay = rng.nextDouble() * .32;
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
    if (local <= 0) continue;
    final x = startX + math.sin(local * math.pi * 3 + i) * (18 + i % 25);
    final y = -18 + local * (360 + rng.nextDouble() * 320);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(local * 8 + i);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 7),
      Paint()..color = colors[i % colors.length].withValues(alpha: 1 - local * .55),
    );
    canvas.restore();
  }
}

void drawNotePopup(Canvas canvas, NoteSpec note, double progress) {
  final scale = Curves.elasticOut.transform(progress.clamp(0.0, 1.0).toDouble());
  canvas.drawRect(
    Offset.zero & sceneSize,
    Paint()..color = Colors.black.withValues(alpha: .22 * progress),
  );
  canvas.save();
  canvas.translate(400, 460);
  canvas.scale(scale);
  canvas.drawCircle(Offset.zero, 145, Paint()..color = Colors.white.withValues(alpha: .96));
  drawShape(canvas, note.shape, Offset.zero, 220, note.color);
  drawCenteredText(
    canvas,
    note.label,
    const Offset(0, 10),
    fontSize: note.label.length > 2 ? 34 : 54,
    color: Colors.white,
    weight: FontWeight.w900,
  );
  canvas.restore();
}
