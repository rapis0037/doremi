import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../drawing/canvas_utils.dart';
import '../drawing/effect_drawing.dart';
import '../drawing/keyboard_drawing.dart';
import '../drawing/shape_drawing.dart';
import '../drawing/staff_drawing.dart';
import '../layout/lesson_scene.dart';

class LessonPainter extends CustomPainter {
  const LessonPainter({
    required this.selected,
    required this.cameraMode,
    required this.sparklesOn,
    required this.scene,
    required this.flightProgress,
    required this.isFlying,
    required this.landed,
    required this.burstProgress,
    required this.showPopup,
    required this.popupProgress,
  });
  final NoteSpec? selected;
  final bool cameraMode;
  final bool sparklesOn;
  final LessonScene scene;
  final double flightProgress;
  final bool isFlying;
  final bool landed;
  final double burstProgress;
  final bool showPopup;
  final double popupProgress;

  @override
  void paint(Canvas canvas, Size size) {
    scaleScene(canvas, size, scene.size);
    // 카메라 모드의 어둡게 처리는 화면 전체를 덮는 카메라 레이어에서 담당한다.
    // 두 학습 화면 모두 이미지처럼 오선지를 먼저 보여주고 그 아래에 건반을 둔다.
    if (selected != null) {
      drawStaff(
        canvas,
        x: scene.staffX,
        y: scene.staffY,
        width: scene.staffWidth,
        scale: scene.staffScale,
        translucentCard: cameraMode,
      );
    }

    final keyboard = scene.keyboard;
    if (selected == null) {
      drawKeyboard(canvas, keyboard, noteList: notes, splitLayout: true);
      return;
    }
    drawKeyboard(
      canvas,
      keyboard,
      noteList: notes.take(keyboard.count).toList(),
      selectedOnly: selected,
      hideSelectedShape: isFlying || landed,
      splitLayout: true,
    );
    final target = scene.noteTarget(selected!);
    if (isFlying) {
      final path = scene.flightPathFor(selected!);
      if (sparklesOn) {
        drawFlightSparkles(canvas, path.at, flightProgress, selected!.color);
      }
      drawShape(
        canvas,
        selected!.shape,
        path.at(flightProgress),
        92,
        selected!.color,
      );
    }
    if (landed) {
      // 오선이 커진 만큼 음표도 같이 키워야 줄 사이에서 작아 보이지 않는다.
      drawMusicNote(
        canvas,
        target,
        selected!.color,
        1.45 * scene.staffScale,
        stemDown: selected!.index == 6,
        showLedgerLine: selected!.index == 0,
      );
      if (burstProgress > 0 && burstProgress < 1) {
        drawBurst(canvas, target, burstProgress, selected!.color);
      }
    }
    if (showPopup) {
      drawNotePopup(
        canvas,
        selected!,
        popupProgress,
        scene: scene.size,
        center: scene.popupCenter,
        radius: scene.popupRadius,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LessonPainter oldDelegate) => true;
}
