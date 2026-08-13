import 'package:doremi/widgets/app_header.dart';
import 'package:doremi/widgets/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1단계·톡톡 Lite 연습 장면 크기.
const _practiceScene = Size(800, 1224);

Future<Rect> _sceneRect(
  WidgetTester tester, {
  required Size box,
  required double inset,
}) async {
  // 기본 테스트 화면(800x600)은 폰 비율 상자보다 낮아 상자가 잘린다.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(1200, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: StageInsets(
            top: inset,
            // 실제 화면과 같이 가운데 정렬된 상태로 잰다.
            child: Center(
              child: SceneView(
                scene: _practiceScene,
                onTap: (_) {},
                painter: _NullPainter(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getRect(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is _NullPainter,
    ),
  );
}

void main() {
  test('헤더 글자가 내려오지 않으면 요구 여백도 없다', () {
    expect(AppHeader.contentOverflow(height: 116), 0);
  });

  test('1단계 헤더는 상자 아래로 글자가 내려온다', () {
    final overflow = AppHeader.contentOverflow(
      height: 116,
      contentScale: 1.3,
      contentOffsetY: 70,
    );
    expect(overflow, greaterThan(0));
  });

  testWidgets('위쪽에 여유가 있으면 장면을 건드리지 않는다', (tester) async {
    // 폰 비율: 장면이 폭에 맞춰져 위아래로 여유가 남는다.
    const box = Size(397, 733);

    final without = await _sceneRect(tester, box: box, inset: 0);
    final with50 = await _sceneRect(tester, box: box, inset: 50);

    expect(with50, without);
  });

  testWidgets('여유가 모자라면 그만큼 내리고 줄인다', (tester) async {
    // 태블릿 비율: 장면이 높이를 꽉 채워 위에 여유가 없다.
    const box = Size(496, 558);

    final without = await _sceneRect(tester, box: box, inset: 0);
    final with50 = await _sceneRect(tester, box: box, inset: 50);

    expect(without.top, 0);
    expect(with50.top, greaterThanOrEqualTo(50));
    expect(with50.height, lessThan(without.height));
    // 장면 비율은 그대로여야 한다.
    expect(
      with50.width / with50.height,
      closeTo(_practiceScene.width / _practiceScene.height, 0.001),
    );
  });
}

class _NullPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
