import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/models.dart';
import '../layout/keyboard_layout.dart';
import 'canvas_utils.dart';
import 'shape_drawing.dart';

/// 도형·계이름이 건반 안에서 숨 쉴 여백.
const double _slotInset = 4;

/// 건반 하나를 위아래 절반으로 나눠, 도형이 들어갈 공통 크기를 구한다.
///
/// 건반마다 검은 건반에 가려지는 폭이 달라서, 그리는 건반들 중 가장 좁은
/// 자리에 맞춰 하나의 크기로 통일한다. 그래야 건반마다 도형 크기가 들쭉날쭉
/// 하지 않는다.
double _sharedShapeSize(KeyboardLayout k, List<NoteSpec> noteList, NoteSpec? selectedOnly) {
  var size = double.infinity;
  for (var i = 0; i < k.count; i++) {
    if (selectedOnly != null && selectedOnly.index != i) continue;
    final slot = k.shapeSlot(i).deflate(_slotInset);
    final widthFactor = shapeWidthFactor(noteList[i].shape);
    size = math.min(size, math.min(slot.width / widthFactor, slot.height));
  }
  return size.isFinite ? size : 0;
}

void drawKeyboard(
  Canvas canvas,
  KeyboardLayout k, {
  required List<NoteSpec> noteList,
  NoteSpec? selectedOnly,
  bool hideSelectedShape = false,
  int? labelsOnlyIndex,
  int? glowIndex,
  double glow = 0,
  bool splitLayout = false,
}) {
  final sharedShapeSize = splitLayout ? _sharedShapeSize(k, noteList, selectedOnly) : 0.0;
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
    final drawShapeNow = show && !hideSelectedShape && labelsOnlyIndex == null;
    final drawLabelNow = (labelsOnlyIndex == null && show) || labelsOnlyIndex == i;

    if (splitLayout) {
      // 위쪽 절반은 도형, 아래쪽 절반은 계이름.
      if (drawShapeNow) {
        drawShape(canvas, note.shape, k.shapeSlot(i).center, sharedShapeSize, note.color);
      }
      if (drawLabelNow) {
        final slot = k.labelSlot(i).deflate(_slotInset);
        drawFittedText(
          canvas,
          // '높은 도'처럼 긴 계이름은 줄을 나눠야 글자를 키울 수 있다.
          note.label.replaceAll(' ', '\n'),
          slot,
          maxFontSize: math.min(slot.height * .85, k.keyWidth * .7),
          color: const Color(0xff34383c),
          weight: FontWeight.w900,
        );
      }
      continue;
    }

    if (drawShapeNow) {
      drawShape(canvas, note.shape, k.iconCenter(i), 52, note.color);
    }
    if (drawLabelNow) {
      drawCenteredText(
        canvas,
        note.label,
        Offset(rect.center.dx, rect.bottom - 55),
        fontSize: note.index == 7 ? 21 : 70,
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
