import 'package:flutter/material.dart';

class KeyboardLayout {
  const KeyboardLayout({
    required this.y,
    required this.height,
    required this.count,
    this.x = 12,
    this.width = referenceWidth,
  });
  final double y;
  final double height;
  final int count;
  final double x;
  final double width;

  /// 세로 장면(800폭)에서 쓰던 건반 폭. 모든 내부 여백의 기준이 된다.
  static const double referenceWidth = 776;

  /// [referenceWidth] 대비 확대 배율. 테두리 여백까지 같이 키워야 건반 하나의
  /// 가로세로 비율이 유지된다.
  double get _scale => width / referenceWidth;

  double get keyX => x + 8 * _scale;
  double get keyY => y + 24 * _scale;
  double get keyWidth => (width - 16 * _scale) / count;
  double get keyHeight => height - 24 * _scale;

  /// 검은 건반이 이웃한 흰 건반 좌우로 파고드는 폭.
  ///
  /// 건반이 넓어져도 검은 건반만 가늘게 남지 않도록 폭에 비례시킨다.
  /// [referenceWidth]에서는 기존과 같은 18이다.
  double get blackKeyOverhang => 18 * _scale;

  Rect whiteKeyRect(int index) =>
      Rect.fromLTWH(keyX + keyWidth * index, keyY, keyWidth, keyHeight);
  Offset iconCenter(int index) =>
      Offset(whiteKeyRect(index).center.dx, keyY + keyHeight * .57);
  List<int> get blackAfter =>
      count == 5 ? const [0, 1, 3] : const [0, 1, 3, 4, 5];
  Rect blackKeyRect(int after) => Rect.fromLTWH(
    whiteKeyRect(after).right - blackKeyOverhang,
    keyY,
    blackKeyOverhang * 2,
    keyHeight * .47,
  );

  /// 흰 건반 [index]에서 검은 건반에 가리지 않는 가로 구간.
  ///
  /// 검은 건반은 흰 건반 경계마다 좌우 [blackKeyOverhang]씩 덮으므로, 건반
  /// 위쪽에 도형을 놓을 때 실제로 쓸 수 있는 폭은 이만큼 좁아진다.
  Rect whiteKeyOpenRect(int index) {
    final rect = whiteKeyRect(index);
    final black = blackAfter;
    return Rect.fromLTRB(
      black.contains(index - 1) ? rect.left + blackKeyOverhang : rect.left,
      rect.top,
      black.contains(index) ? rect.right - blackKeyOverhang : rect.right,
      rect.bottom,
    );
  }

  /// 건반 위쪽 절반 — 도형 자리.
  Rect shapeSlot(int index) {
    final open = whiteKeyOpenRect(index);
    return Rect.fromLTRB(
      open.left,
      open.top,
      open.right,
      open.top + keyHeight / 2,
    );
  }

  /// 건반 아래쪽 절반 — 계이름 자리.
  Rect labelSlot(int index) {
    final rect = whiteKeyRect(index);
    return Rect.fromLTRB(
      rect.left,
      rect.top + keyHeight / 2,
      rect.right,
      rect.bottom,
    );
  }

  int? hitWhiteKey(Offset point) {
    if (blackAfter.any((index) => blackKeyRect(index).contains(point))) return null;
    for (var i = 0; i < count; i++) {
      if (whiteKeyRect(i).contains(point)) return i;
    }
    return null;
  }
}
