import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../space/space_controller.dart';

/// 톡톡 Space 1단계 — 손 추적과 칸 조준을 실기기에서 확인하는 화면.
///
/// 미리보기와 오버레이는 반드시 같은 좌표 공간에 올린다. 랜드마크는 네이티브가
/// 회전·반전을 적용한 뒤의 이미지 기준 정규화 좌표라, 미리보기도 같은 회전·반전을
/// 거쳐야 뼈대가 실제 손에 겹친다. 그래서 CameraPreview 대신 원본 미리보기를
/// 직접 감싼다 — CameraPreview는 자체 회전을 한 겹 더 넣어서 두 공간이 어긋난다.
///
/// 회전값 자체는 기기마다 달라 코드로 미리 정할 수 없다. 디버그 패널에서 돌려
/// 화면이 똑바로 서는 값을 찾은 뒤 SpaceController의 기본값에 적어 넣는다.
/// 미리보기와 오버레이가 같이 돌아가므로 어느 값에서도 둘은 어긋나지 않는다.
class SpacePage extends StatefulWidget {
  const SpacePage({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<SpacePage> {
  late final SpaceController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller = SpaceController()..addListener(_onChanged);
    _controller.start();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _stage(),
          if (_controller.status != SpaceStatus.ready) _statusLayer(),
          _debugPanel(),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: widget.onExit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 회전이 적용된 이미지 공간 하나에 미리보기와 오버레이를 함께 올린다.
  Widget _stage() {
    final oriented = _controller.orientedSize;
    return ClipRect(
      child: FittedBox(
        // cover로 채우면 세로 공간이 가로 화면에 눌려 이미지의 3분의 1만 남는다.
        // 손이 프레임 어디에 잡히는지 봐야 하므로 잘라내지 않는다.
        fit: BoxFit.contain,
        child: SizedBox(
          width: oriented.width,
          height: oriented.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller.showCamera) _orientedPreview(),
              CustomPaint(painter: _SpaceOverlayPainter(_controller)),
            ],
          ),
        ),
      ),
    );
  }

  /// 네이티브가 비트맵에 적용한 것과 똑같은 순서로 반전 → 회전을 건다.
  Widget _orientedPreview() {
    final camera = _controller.camera;
    if (camera == null || !camera.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final width = _controller.frameWidth;
    final height = _controller.frameHeight;
    if (width == 0 || height == 0) return const ColoredBox(color: Colors.black);

    Widget preview = SizedBox(
      width: width.toDouble(),
      height: height.toDouble(),
      child: camera.buildPreview(),
    );
    if (_controller.mirror) {
      preview = Transform.scale(scaleX: -1, child: preview);
    }
    return RotatedBox(
      quarterTurns: (_controller.rotationDegrees ~/ 90) % 4,
      child: preview,
    );
  }

  Widget _statusLayer() => ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Text(
        switch (_controller.status) {
          SpaceStatus.initializing => '카메라를 준비하고 있어요',
          SpaceStatus.permissionDenied => '카메라 권한이 필요해요',
          SpaceStatus.noCamera => '카메라를 찾지 못했어요',
          SpaceStatus.error => '문제가 생겼어요\n${_controller.errorMessage ?? ''}',
          SpaceStatus.ready => '',
        },
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    ),
  );

  Widget _debugPanel() {
    final c = _controller;
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'fps ${c.fps}  ${c.detectMs}ms  ${c.frameWidth}x${c.frameHeight}\n'
                'span ${c.span.toStringAsFixed(3)}  '
                'conf ${c.confidence.toStringAsFixed(2)}  '
                '제스처 ${c.gestureHits}  체류 ${c.dwellHits}'
                '${c.suppressed ? '  (연속 제한)' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _chip(
                    c.autoRotation
                        ? '회전 자동 ${c.rotationDegrees}°'
                        : '회전 고정 ${c.rotationDegrees}°',
                    c.cycleRotation,
                  ),
                  _chip(c.mirror ? '반전 켬' : '반전 끔', c.toggleMirror),
                  _chip(c.showCamera ? '영상 켬' : '영상 끔', c.toggleCamera),
                  _chip(c.showSkeleton ? '뼈대 켬' : '뼈대 끔', c.toggleSkeleton),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    ),
  );
}

/// 칸은 좌우 위치로만 고르므로 세로 띠로 그린다. 로직과 화면이 같은 모양이다.
///
/// 이 painter는 화면이 아니라 회전된 이미지 공간에 그린다. 박스 크기가 프레임
/// 해상도(예: 240x320)라서 선 굵기와 글자 크기를 상수로 두면 안 된다 —
/// 바깥 FittedBox가 통째로 확대하므로 전부 박스 크기 대비 비율로 잡는다.
class _SpaceOverlayPainter extends CustomPainter {
  _SpaceOverlayPainter(this.controller);

  final SpaceController controller;

  static const _connections = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (9, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (13, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (0, 17),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    _paintKeys(canvas, size, unit);
    if (controller.showSkeleton) _paintSkeleton(canvas, size, unit);
    _paintCursor(canvas, size, unit);
  }

  void _paintKeys(Canvas canvas, Size size, double unit) {
    final detector = controller.detector;
    for (var i = 0; i < detector.config.keyCount; i++) {
      final (start, end) = detector.bounds(i);
      final rect = Rect.fromLTRB(
        start * size.width,
        0,
        end * size.width,
        size.height,
      );
      final note = notes[i];
      final active = controller.activeKey == i;
      final flash = controller.flashKey == i;

      canvas.drawRect(
        rect.deflate(unit * .006),
        Paint()
          ..color = note.color.withValues(
            alpha: flash ? .55 : (active ? .30 : .12),
          ),
      );
      canvas.drawRect(
        rect.deflate(unit * .006),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * (active ? .012 : .006)
          ..color = note.color.withValues(alpha: active ? .95 : .45),
      );

      final label = TextPainter(
        text: TextSpan(
          text: note.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: active ? 1 : .7),
            fontSize: unit * (active ? .15 : .11),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          size.height - label.height - unit * .06,
        ),
      );
    }
  }

  void _paintSkeleton(Canvas canvas, Size size, double unit) {
    final points = controller.landmarks;
    if (points.length < 21) return;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = unit * .008;
    for (final (a, b) in _connections) {
      canvas.drawLine(
        Offset(points[a].dx * size.width, points[a].dy * size.height),
        Offset(points[b].dx * size.width, points[b].dy * size.height),
        line,
      );
    }
    final dot = Paint()..color = Colors.white;
    for (final point in points) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        unit * .012,
        dot,
      );
    }
  }

  void _paintCursor(Canvas canvas, Size size, double unit) {
    final cursor = controller.cursor;
    if (cursor == null) return;
    final center = Offset(cursor.dx * size.width, cursor.dy * size.height);
    final key = controller.activeKey;
    final color = key == null ? Colors.white : notes[key].color;
    final radius = unit * .09;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: .35),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .012
        ..color = Colors.white,
    );
    canvas.drawCircle(center, unit * .022, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SpaceOverlayPainter oldDelegate) => true;
}
