import 'package:doremi/layout/lesson_scene.dart';
import 'package:doremi/pages/stage_three_flow_page.dart';
import 'package:doremi/painters/selection_painter.dart';
import 'package:doremi/widgets/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final screen in [const Size(412, 915), const Size(914, 411)]) {
    testWidgets('$screen 3단계 메뉴 건반이 1단계와 같다', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = screen;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: StageThreeFlowPage(
            soundOn: true,
            onSoundChanged: (_) {},
            sparklesOn: true,
            onSparklesChanged: (_) {},
            onExit: () {},
          ),
        ),
      );
      await tester.pump();

      final expected = LessonScene.of(
        landscape: screen.width > screen.height,
        selected: null,
      );
      final sceneView = tester.widget<SceneView>(find.byType(SceneView));
      final painter = sceneView.painter as SelectionPainter;

      expect(sceneView.scene, expected.size);
      expect(painter.scene, expected.size);
      expect(painter.keyboard.x, expected.keyboard.x);
      expect(painter.keyboard.y, expected.keyboard.y);
      expect(painter.keyboard.width, expected.keyboard.width);
      expect(painter.keyboard.height, expected.keyboard.height);
    });
  }
}
