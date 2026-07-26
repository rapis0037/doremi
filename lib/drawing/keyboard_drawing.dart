import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../layout/keyboard_layout.dart';
import 'canvas_utils.dart';
import 'shape_drawing.dart';

void drawKeyboard(
  Canvas canvas,
  KeyboardLayout k, {
  required List<NoteSpec> noteList,
  NoteSpec? selectedOnly,
  bool hideSelectedShape = false,
  int? labelsOnlyIndex,
  int? glowIndex,
  double glow = 0,
}) {
  final outer = RRect.fromRectAndRadius(
    Rect.fromLTWH(k.x, k.y, k.width, k.height),
    const Radius.circular(7),
  );
  canvas.drawRRect(outer, Paint()..color = const Color(0xffe5e7e9));
  canvas.drawRRect(
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xff555b61),
  );
  for (var i = 0; i < k.count; i++) {
    final rect = k.whiteKeyRect(i);
    if (glowIndex == i) {
      canvas.drawRect(
        rect.inflate(9),
        Paint()
          ..color = notes.first.color.withValues(alpha: .25 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xff6a7075),
    );
    final note = noteList[i];
    final show = selectedOnly == null || selectedOnly.index == i;
    if (show && !hideSelectedShape && labelsOnlyIndex == null) {
      drawShape(canvas, note.shape, k.iconCenter(i), 52, note.color);
    }
    if ((labelsOnlyIndex == null && show) || labelsOnlyIndex == i) {
      drawCenteredText(
        canvas,
        note.label,
        Offset(rect.center.dx, rect.bottom - 35),
        fontSize: note.index == 7 ? 21 : 25,
        color: const Color(0xff34383c),
        weight: FontWeight.w900,
      );
    }
  }
  for (final index in k.blackAfter) {
    final rect = k.blackKeyRect(index);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = const Color(0xff3e4348),
    );
  }
}
