import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../drawing/canvas_utils.dart';
import '../drawing/keyboard_drawing.dart';
import '../layout/keyboard_layout.dart';

class SelectionPainter extends CustomPainter {
  const SelectionPainter({required this.keyboard});
  final KeyboardLayout keyboard;

  @override
  void paint(Canvas canvas, Size size) {
    scaleScene(canvas, size);
    drawKeyboard(
      canvas,
      keyboard,
      noteList: notes.take(keyboard.count).toList(),
      splitLayout: true,
    );
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) => false;
}
