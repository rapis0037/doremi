import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../drawing/canvas_utils.dart';
import '../drawing/effect_drawing.dart';
import '../drawing/keyboard_drawing.dart';
import '../drawing/shape_drawing.dart';
import '../drawing/staff_drawing.dart';
import '../layout/keyboard_layout.dart';

class ChallengePainter extends CustomPainter {
  const ChallengePainter({
    required this.keyboard,
    required this.heart,
    required this.chosen,
    required this.fixed,
    required this.guideProgress,
    required this.confettiProgress,
    required this.showScore,
    required this.activeNote,
    required this.performanceDone,
    required this.showPopup,
    required this.popupProgress,
  });
  final KeyboardLayout keyboard;
  final Offset heart;
  final bool chosen;
  final bool fixed;
  final double guideProgress;
  final double confettiProgress;
  final bool showScore;
  final int activeNote;
  final bool performanceDone;
  final bool showPopup;
  final double popupProgress;

  @override
  void paint(Canvas canvas, Size size) {
    scaleScene(canvas, size);
    final glow = math.sin(guideProgress * math.pi).clamp(0.0, 1.0).toDouble();
    drawKeyboard(
      canvas,
      keyboard,
      noteList: notes.take(5).toList(),
      labelsOnlyIndex: 0,
      glowIndex: glow > 0 ? 0 : null,
      glow: glow,
    );
    if (showScore) drawChallengeScore(canvas, activeNote, performanceDone);
    if (chosen && !fixed) {
      canvas.drawCircle(
        heart,
        68,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = notes.first.color.withValues(alpha: .34),
      );
    }
    drawShape(canvas, NoteShape.heart, heart, fixed ? 54 : 88, notes.first.color);
    if (confettiProgress > 0 && confettiProgress < 1) {
      drawConfetti(canvas, confettiProgress);
    }
    if (showPopup) drawNotePopup(canvas, notes.first, popupProgress);
  }

  @override
  bool shouldRepaint(covariant ChallengePainter oldDelegate) => true;
}
