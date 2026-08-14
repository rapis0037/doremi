import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import 'canvas_utils.dart';
import 'shape_drawing.dart';

void drawMusicNote(
  Canvas canvas,
  Offset center,
  Color color,
  double scale, {
  bool stemDown = false,
  bool showLedgerLine = false,
}) {
  const noteColor = Color(0xff30353a);
  canvas.drawOval(
    Rect.fromCenter(center: center, width: 30 * scale, height: 22 * scale),
    Paint()..color = noteColor,
  );
  final stemX = center.dx + (stemDown ? -13 : 13) * scale;
  canvas.drawLine(
    Offset(stemX, center.dy),
    Offset(stemX, center.dy + (stemDown ? 57 : -57) * scale),
    Paint()
      ..color = noteColor
      ..strokeWidth = 6 * scale
      ..strokeCap = StrokeCap.round,
  );
  if (showLedgerLine) {
    canvas.drawLine(
      Offset(center.dx - 25 * scale, center.dy),
      Offset(center.dx + 25 * scale, center.dy),
      Paint()
        ..color = const Color(0xff454b50)
        ..strokeWidth = 3,
    );
  }
}

/// 네 갈래로 뻗는 반짝임 별.
void _drawSparkleStar(Canvas canvas, Offset center, double size, Paint paint) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final radius = i.isEven ? size : size * .3;
    final angle = -math.pi / 2 + i * math.pi / 4;
    final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path..close(), paint);
}

/// 도형이 악보로 날아갈 때의 반짝임.
///
/// [pathAt]으로 지나온 경로를 되짚어 꼬리를 남기고, 머리 쪽에는 도형 둘레를
/// 도는 별을 둘러 준다. 경로를 다시 계산할 수 있어야 꼬리가 그려지므로 현재
/// 위치 한 점이 아니라 함수를 받는다.
void drawFlightSparkles(
  Canvas canvas,
  Offset Function(double t) pathAt,
  double t,
  Color color,
) {
  const trailSteps = 18;
  const palette = [Color(0xffffd84b), Colors.white, Color(0xff8fe3ff)];
  final head = pathAt(t);

  // 도형 뒤로 은은하게 번지는 빛.
  canvas.drawCircle(
    head,
    76,
    Paint()
      ..color = color.withValues(alpha: .38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );

  // 꼬리 — 뒤로 갈수록 작아지고 옅어진다.
  final rng = math.Random(31);
  for (var i = 1; i <= trailSteps; i++) {
    final back = t - i * .026;
    final fade = 1 - i / trailSteps;
    // 난수 순서를 유지해야 파티클이 프레임마다 튀지 않는다.
    final angle = rng.nextDouble() * math.pi * 2;
    final spread = 12 + rng.nextDouble() * 30;
    final grain = rng.nextDouble();
    if (back <= 0) continue;
    final base = pathAt(back);
    for (var j = 0; j < 2; j++) {
      final spin = angle + j * math.pi;
      final p = base + Offset(math.cos(spin), math.sin(spin)) * spread * (1.1 - fade * .6);
      final paint = Paint()
        ..color = (j == 0 ? color : palette[i % palette.length])
            .withValues(alpha: .9 * fade);
      final size = (2.4 + grain * 5) * (.35 + fade * .65);
      if ((i + j) % 3 == 0) {
        _drawSparkleStar(canvas, p, size * 2.4, paint);
      } else {
        canvas.drawCircle(p, size, paint);
      }
    }
  }

  // 머리 — 도형 둘레를 돌며 깜빡이는 별.
  for (var i = 0; i < 10; i++) {
    final spin = t * math.pi * 6 + i * math.pi / 5;
    final radius = 46 + math.sin(t * math.pi * 4 + i) * 16;
    final p = head + Offset(math.cos(spin), math.sin(spin)) * radius;
    final twinkle = .5 + .5 * math.sin(t * math.pi * 12 + i * 1.7);
    _drawSparkleStar(
      canvas,
      p,
      7 + 6 * twinkle,
      Paint()
        ..color = (i.isEven ? const Color(0xffffd84b) : Colors.white)
            .withValues(alpha: .5 + .45 * twinkle),
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

/// 계이름 팝업의 기준 반지름. 안쪽 도형·글자 크기가 모두 여기에 비례한다.
const double basePopupRadius = 145;

void drawNotePopup(
  Canvas canvas,
  NoteSpec note,
  double progress, {
  Size scene = sceneSize,
  Offset center = const Offset(400, 460),
  double radius = basePopupRadius,
}) {
  final scale = Curves.elasticOut.transform(progress.clamp(0.0, 1.0).toDouble());
  final k = radius / basePopupRadius;
  canvas.drawRect(
    Offset.zero & scene,
    Paint()..color = Colors.black.withValues(alpha: .22 * progress),
  );
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.drawCircle(Offset.zero, radius, Paint()..color = Colors.white.withValues(alpha: .96));
  drawShape(canvas, note.shape, Offset.zero, 220 * k, note.color);
  drawCenteredText(
    canvas,
    note.label,
    Offset.zero,
    fontSize: (note.index == 7 ? 52 : 68) * k,
    color: Colors.white,
    weight: FontWeight.w900,
  );
  canvas.restore();
}
