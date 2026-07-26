import 'package:flutter/material.dart';

class KeyboardLayout {
  const KeyboardLayout({required this.y, required this.height, required this.count});
  final double y;
  final double height;
  final int count;

  double get x => 12;
  double get width => 776;
  double get keyX => x + 8;
  double get keyY => y + 24;
  double get keyWidth => (width - 16) / count;
  double get keyHeight => height - 24;

  Rect whiteKeyRect(int index) => Rect.fromLTWH(keyX + keyWidth * index, keyY, keyWidth, keyHeight);
  Offset iconCenter(int index) => Offset(whiteKeyRect(index).center.dx, keyY + keyHeight * .57);
  List<int> get blackAfter => count == 5 ? const [0, 1, 3] : const [0, 1, 3, 4, 5];
  Rect blackKeyRect(int after) => Rect.fromLTWH(whiteKeyRect(after).right - 18, keyY, 36, keyHeight * .47);

  int? hitWhiteKey(Offset point) {
    if (blackAfter.any((index) => blackKeyRect(index).contains(point))) return null;
    for (var i = 0; i < count; i++) {
      if (whiteKeyRect(i).contains(point)) return i;
    }
    return null;
  }
}
