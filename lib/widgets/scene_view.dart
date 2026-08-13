import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';

class SceneView extends StatelessWidget {
  const SceneView({
    super.key,
    required this.painter,
    required this.onTap,
    this.scene = sceneSize,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });
  final CustomPainter painter;
  final ValueChanged<Offset> onTap;

  /// 그림이 그려지는 좌표계 크기. 화면은 이 비율을 유지한 채 채워진다.
  final Size scene;
  final ValueChanged<Offset>? onPanStart;
  final ValueChanged<Offset>? onPanUpdate;
  final VoidCallback? onPanEnd;

  Offset _logical(Offset point, Size size) => Offset(
        point.dx * scene.width / size.width,
        point.dy * scene.height / size.height,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 헤더 글자가 상자 밖으로 내려와 있으면 그 아래에서 시작해야 한다.
        // 다만 장면이 폭에 맞아 위쪽에 이미 여유가 생기는 화면(폰)에서는
        // 지금 자리를 그대로 둔다 — 모자랄 때만 자리를 만들고 줄인다.
        final inset = StageInsets.of(context);
        var box = constraints.biggest;
        var size = _fit(box);
        final slack = (box.height - size.height) / 2;
        var top = 0.0;
        if (slack < inset) {
          box = Size(box.width, box.height - inset);
          size = _fit(box);
          top = inset;
        }
        final width = size.width;
        final height = size.height;
        return Padding(
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            width: width,
            height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => onTap(_logical(details.localPosition, size)),
              onPanStart: onPanStart == null
                  ? null
                  : (details) => onPanStart!(_logical(details.localPosition, size)),
              onPanUpdate: onPanUpdate == null
                  ? null
                  : (details) => onPanUpdate!(_logical(details.localPosition, size)),
              onPanEnd: onPanEnd == null ? null : (_) => onPanEnd!(),
              child: CustomPaint(size: size, painter: painter),
              ),
            ),
          ),
        );
      },
    );
  }

  Size _fit(Size box) {
    final width = math.min(box.width, box.height * scene.width / scene.height);
    return Size(width, width * scene.height / scene.width);
  }
}

/// 헤더가 아래쪽 콘텐츠에 요구하는 최소 위 여백.
///
/// 페이지마다 인자로 넘기지 않도록 [StageShell]이 심고 [SceneView]가 읽는다.
class StageInsets extends InheritedWidget {
  const StageInsets({super.key, required this.top, required super.child});

  final double top;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StageInsets>()?.top ?? 0;

  @override
  bool updateShouldNotify(StageInsets oldWidget) => oldWidget.top != top;
}
