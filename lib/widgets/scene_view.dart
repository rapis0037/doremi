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
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * scene.width / scene.height,
        );
        final height = width * scene.height / scene.width;
        final size = Size(width, height);
        return SizedBox(
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
        );
      },
    );
  }
}
