import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../drawing/canvas_utils.dart';
import '../drawing/effect_drawing.dart';
import '../drawing/keyboard_drawing.dart';
import '../drawing/shape_drawing.dart';
import '../drawing/staff_drawing.dart';
import '../layout/keyboard_layout.dart';

class LessonPainter extends CustomPainter {
  const LessonPainter({
    required this.selected,
    required this.cameraMode,
    required this.keyboard,
    required this.flightProgress,
    required this.isFlying,
    required this.landed,
    required this.burstProgress,
    required this.showPopup,
    required this.popupProgress,
    required this.flightPoint,
  });
  final NoteSpec? selected;
  final bool cameraMode;
  final KeyboardLayout keyboard;
  final double flightProgress;
  final bool isFlying;
  final bool landed;
  final double burstProgress;
  final bool showPopup;
  final double popupProgress;
  final Offset? flightPoint;

  @override
  void paint(Canvas canvas, Size size) {
    scaleScene(canvas, size);
    if (cameraMode) {
      canvas.drawRect(Offset.zero & sceneSize, Paint()..color = Colors.black.withValues(alpha: .12));
    }
    if (selected == null) {
      drawKeyboard(canvas, keyboard, noteList: notes);
      return;
    }
    drawStaff(canvas, y: 92, translucentCard: cameraMode);
    drawKeyboard(
      canvas,
      keyboard,
      noteList: notes.take(keyboard.count).toList(),
      selectedOnly: selected,
      hideSelectedShape: isFlying || landed,
    );
    final target = _staffNoteTarget(selected!);
    if (isFlying && flightPoint != null) {
      drawFlightSparkles(canvas, flightPoint!, flightProgress, selected!.color);
      drawShape(canvas, selected!.shape, flightPoint!, 92, selected!.color);
    }
    if (landed) {
      drawMusicNote(canvas, target, selected!.color, 1.45);
      if (burstProgress > 0 && burstProgress < 1) {
        drawBurst(canvas, target, burstProgress, selected!.color);
      }
    }
    if (showPopup) drawNotePopup(canvas, selected!, popupProgress);
  }

  Offset _staffNoteTarget(NoteSpec note) {
    const y = 92.0;
    const gap = 28.0;
    return Offset(420, y + gap * 5 - note.pitchStep * gap / 2);
  }

  @override
  bool shouldRepaint(covariant LessonPainter oldDelegate) => true;
}
