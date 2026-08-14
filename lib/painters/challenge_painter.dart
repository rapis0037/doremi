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
  static const double draggableHeartSize = 184;
  static const double selectionRingRadius = 122;
  static const double completionPopupRadius = basePopupRadius * 2;

  const ChallengePainter({
    required this.keyboard,
    required this.note,
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
  final NoteSpec note;
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
      noteList: notes,
      labelsOnlyIndex: note.index,
      glowIndex: glow > 0 ? 0 : null,
      glow: glow,
    );
    if (showScore) drawChallengeScore(canvas, activeNote, performanceDone);
    if (chosen && !fixed) {
      canvas.drawCircle(
        heart,
        selectionRingRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = note.color.withValues(alpha: .34),
      );
    }
    drawShape(
      canvas,
      note.shape,
      heart,
      fixed ? 104 : draggableHeartSize,
      note.color,
    );
    if (confettiProgress > 0 && confettiProgress < 1) {
      drawConfetti(canvas, confettiProgress);
    }
    if (showPopup) {
      drawNotePopup(canvas, note, popupProgress, radius: completionPopupRadius);
    }
  }

  @override
  bool shouldRepaint(covariant ChallengePainter oldDelegate) => true;
}
