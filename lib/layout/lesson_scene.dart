import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../drawing/effect_drawing.dart';
import '../drawing/staff_drawing.dart';
import 'keyboard_layout.dart';

/// 1단계·톡톡 Lite 화면이 그려지는 장면 좌표계.
///
/// 세로에서는 악보가 위, 건반이 아래로 멀찍이 떨어진 세로형 캔버스(800×920)를
/// 쓴다. 가로로 돌리면 화면이 낮고 넓어지는데, 같은 캔버스를 그대로 쓰면
/// 비율을 맞추느라 높이에 눌려 건반이 화면 폭의 1/3도 못 쓴다. 그래서 가로
/// 에서는 폭을 넓게 잡은 캔버스로 갈아끼워 건반이 가로를 채우게 한다.
class LessonScene {
  const LessonScene._({
    required this.size,
    required this.staffX,
    required this.staffY,
    required this.staffWidth,
    required this.staffScale,
    required this.keyboard,
    required this.popupCenter,
    required this.popupRadius,
  });

  /// 장면 좌표계 크기. [SceneView]가 이 비율을 유지한 채 화면에 맞춘다.
  final Size size;
  final double staffX;
  final double staffY;
  final double staffWidth;

  /// 오선의 세로 확대 배율. 줄 간격·음자리표·음표가 함께 커진다.
  final double staffScale;
  final KeyboardLayout keyboard;

  /// 오선 한 칸 간격.
  double get staffGap => baseStaffGap * staffScale;

  /// 반투명 카드까지 포함한 오선 전체 영역.
  Rect get staffBox => Rect.fromLTWH(
    staffX - 26 * staffScale,
    0,
    staffWidth + 52 * staffScale,
    staffY + staffGap * 4 + 42 * staffScale,
  );

  /// 건반 전체 영역.
  Rect get keyboardBox =>
      Rect.fromLTWH(keyboard.x, keyboard.y, keyboard.width, keyboard.height);

  /// 계이름 팝업 중심 — 팝업을 눌러 초기화하는 판정에도 쓴다.
  final Offset popupCenter;

  /// 계이름 팝업 반지름. 탭 판정도 이 값을 쓴다.
  final double popupRadius;

  /// 팝업을 기준 크기의 몇 배로 띄울지.
  static const double popupZoom = 2;

  /// 캔버스를 넘지 않는 선에서 [popupZoom]배까지 키운 팝업 반지름.
  ///
  /// 가로 캔버스는 높이가 480뿐이라 2배(290)를 그대로 쓰면 위아래로 잘린다.
  static double _popupRadiusFor(Size canvas) => math.min(
    basePopupRadius * popupZoom,
    math.min(canvas.width, canvas.height) / 2 - 20,
  );

  static const double portraitStaffWidth = 676;

  /// 오선을 기준 대비 몇 배로 키울지. 세로 화면은 악보와 건반 사이가 넉넉해
  /// 그대로 적용되고, 가로에서는 악보를 건반 옆으로 옮겨 자리를 만든다.
  static const double staffZoom = 1.8;

  /// 음표가 놓이는 지점 — 오선 폭에 대한 비율.
  static const double _noteOffsetRatio = 358 / portraitStaffWidth;

  static const double landscapeWidth = 1400;
  static const double landscapeHeight = 480;
  static const Size portraitSize = Size(800, 920);
  static const Size portraitPracticeSize = Size(800, 1224);
  static const Size landscapeSize = Size(landscapeWidth, landscapeHeight);

  /// 카메라 모드(톡톡 Lite)도 1단계와 같은 좌표계를 쓴다. 예전에는 카메라
  /// 위에서만 건반을 낮고 짧게(y 650, height 252) 뒀는데, 그러면 같은 학습
  /// 흐름인데도 도형·계이름 크기가 화면마다 달라진다.
  static LessonScene of({
    required bool landscape,
    required NoteSpec? selected,
    bool cameraMode = false,
  }) => landscape
      ? LessonScene._landscape(selected: selected)
      : LessonScene._portrait(selected: selected);

  static int _keyCount(NoteSpec? selected) =>
      selected != null && selected.index < 5 ? 5 : 8;

  static LessonScene _portrait({
    required NoteSpec? selected,
  }) {
    final picking = selected == null;
    final canvas = picking ? portraitSize : portraitPracticeSize;
    return LessonScene._(
      size: canvas,
      staffX: 62,
      // 음정 연습 오선지는 상단 여백을 확보해 음자리표 윗부분이 잘리지 않게 한다.
      staffY: 92,
      staffWidth: portraitStaffWidth,
      staffScale: staffZoom,
      keyboard: KeyboardLayout(
        // Lite 초기 화면도 악보 아래에 건반을 배치한다.
        // 선택 화면은 기존 크기를 유지하고, 연습 화면은 세로로 키워 장면 하단에 붙인다.
        // 일반 연습과 톡톡 Lite 연습은 같은 건반 크기와 위치를 사용한다.
        y: picking ? 320 : 920,
        height: picking ? 350 : 300,
        count: _keyCount(selected),
      ),
      popupCenter: Offset(canvas.width / 2, canvas.height / 2),
      popupRadius: _popupRadiusFor(canvas),
    );
  }

  /// 건반 하나의 가로세로 비율을 세로 화면과 똑같이 유지한 채, 주어진 상자를
  /// 채우는 건반을 만든다. 폭을 상자에 맞춰 늘리면 흰 건반이 납작해지므로
  /// 높이를 기준으로 폭을 역산한다.
  static KeyboardLayout _fittedKeyboard({
    required Rect box,
    required int count,
  }) {
    final width = math.min(
      KeyboardLayout.widthForHeight(box.height),
      box.width,
    );
    final height = KeyboardLayout.heightForWidth(width);
    return KeyboardLayout(
      x: box.left + (box.width - width) / 2,
      y: box.top + (box.height - height) / 2,
      width: width,
      height: height,
      count: count,
    );
  }

  static LessonScene _landscape({required NoteSpec? selected}) {
    final picking = selected == null;
    const margin = 16.0;
    const gap = 20.0;
    const staffWidth = 520.0;

    // 음을 고를 때는 악보가 없으니 건반이 캔버스를 다 쓴다. 연습 중에는 악보를
    // 위가 아니라 건반 왼쪽에 두어, 둘 다 캔버스 높이를 온전히 쓰게 한다.
    // 위아래로 쌓으면 오선을 키우는 만큼 건반이 그대로 줄어든다.
    const staffBoxWidth = staffWidth + 52 * staffZoom;
    final keyboardBox = picking
        ? const Rect.fromLTRB(
            margin,
            margin,
            landscapeWidth - margin,
            landscapeHeight - margin,
          )
        : const Rect.fromLTRB(
            margin + staffBoxWidth + gap,
            margin,
            landscapeWidth - margin,
            landscapeHeight - margin,
          );

    const staffBoxTop =
        (landscapeHeight - (baseStaffGap * 4 + 84) * staffZoom) / 2;
    return LessonScene._(
      size: landscapeSize,
      // 반투명 카드가 왼쪽으로 26*배율만큼 더 나가므로 그만큼 안쪽에서 시작한다.
      staffX: margin + 26 * staffZoom,
      staffY: staffBoxTop + 42 * staffZoom,
      staffWidth: staffWidth,
      staffScale: staffZoom,
      keyboard: _fittedKeyboard(box: keyboardBox, count: _keyCount(selected)),
      popupCenter: const Offset(landscapeWidth / 2, landscapeHeight / 2),
      popupRadius: _popupRadiusFor(landscapeSize),
    );
  }

  /// 선택한 음이 악보 위에서 앉을 자리.
  Offset noteTarget(NoteSpec note) => Offset(
    staffX + staffWidth * _noteOffsetRatio,
    staffY + staffGap * 5 - note.pitchStep * staffGap / 2,
  );

  /// 도형이 악보까지 날아갈 때 더해지는 흔들림. 캔버스 크기에 비례한다.
  Offset flightWiggle(double t) => Offset(
    size.width * .21 * math.sin(t * math.pi * 4),
    size.height * .136 * math.sin(t * math.pi * 2),
  );

  /// 도형이 건반에서 악보까지 날아가는 경로.
  ///
  /// 흔들림 폭을 미리 한 번만 맞춰 두므로, 꼬리를 그리느라 여러 시점을 되짚어도
  /// 매번 다시 계산하지 않는다.
  FlightPath flightPathFor(NoteSpec note) => FlightPath._(
    start: keyboard.shapeSlot(note.index).center,
    end: noteTarget(note),
    wiggle: flightWiggle,
    canvas: size,
  );

  /// 비행 진행도 [t](0~1)에서 도형이 있을 자리.
  Offset flightPoint(NoteSpec note, double t) => flightPathFor(note).at(t);
}

/// 도형이 악보로 날아가는 궤적.
///
/// 흔들림을 그대로 더하면 가장자리 건반(높은 도)에서 도형이 캔버스 밖으로
/// 튀어나가 잘린다. 만들 때 전체 궤적을 한 번 훑어, 넘치는 만큼만 흔들림
/// 폭을 줄여 둔다.
class FlightPath {
  FlightPath._({
    required Offset start,
    required Offset end,
    required Offset Function(double) wiggle,
    required Size canvas,
  }) : _start = start,
       _end = end,
       _wiggle = wiggle,
       _damping = _fit(start, end, wiggle, canvas);

  final Offset _start;
  final Offset _end;
  final Offset Function(double) _wiggle;
  final double _damping;

  /// 도형이 잘려 보이지 않도록 캔버스 가장자리에 남겨 두는 여유.
  static const double _margin = 48;

  Offset at(double t) {
    final w = _wiggle(t);
    return Offset(
      _start.dx + (_end.dx - _start.dx) * t + w.dx * _damping,
      _start.dy + (_end.dy - _start.dy) * t + w.dy * _damping,
    );
  }

  static double _fit(
    Offset start,
    Offset end,
    Offset Function(double) wiggle,
    Size canvas,
  ) {
    var damping = 1.0;
    for (var i = 0; i <= 48; i++) {
      final t = i / 48;
      final w = wiggle(t);
      damping = math.min(
        damping,
        _axisFit(start.dx + (end.dx - start.dx) * t, w.dx, canvas.width),
      );
      damping = math.min(
        damping,
        _axisFit(start.dy + (end.dy - start.dy) * t, w.dy, canvas.height),
      );
    }
    return damping;
  }

  /// [base]에 [wiggle]을 더해도 [0+여유, extent-여유] 안에 남는 최대 배율.
  static double _axisFit(double base, double wiggle, double extent) {
    if (wiggle == 0) return 1;
    final limit = wiggle > 0 ? extent - _margin - base : _margin - base;
    return (limit / wiggle).clamp(0.0, 1.0);
  }
}
