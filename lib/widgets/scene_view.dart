import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';

class SceneView extends StatelessWidget {
  const SceneView({
    super.key,
    required this.painter,
    required this.onTap,
    this.background,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });
  final CustomPainter painter;
  final Widget? background;
  final ValueChanged<Offset> onTap;
  final ValueChanged<Offset>? onPanStart;
  final ValueChanged<Offset>? onPanUpdate;
  final VoidCallback? onPanEnd;

  Offset _logical(Offset point, Size size) => Offset(
        point.dx * sceneSize.width / size.width,
        point.dy * sceneSize.height / size.height,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * sceneSize.width / sceneSize.height,
        );
        final height = width * sceneSize.height / sceneSize.width;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ?background,
                  CustomPaint(painter: painter),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
