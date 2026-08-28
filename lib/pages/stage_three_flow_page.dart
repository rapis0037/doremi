import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../layout/lesson_scene.dart';
import '../painters/selection_painter.dart';
import '../widgets/scene_view.dart';
import '../widgets/stage_shell.dart';
import '../widgets/step_card.dart';
import 'stage_three_do_page.dart';

class StageThreeFlowPage extends StatefulWidget {
  const StageThreeFlowPage({
    super.key,
    required this.soundOn,
    required this.onSoundChanged,
    required this.sparklesOn,
    required this.onSparklesChanged,
    required this.onExit,
  });
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final bool sparklesOn;
  final ValueChanged<bool> onSparklesChanged;
  final VoidCallback onExit;

  @override
  State<StageThreeFlowPage> createState() => _StageThreeFlowPageState();
}

class _StageThreeFlowPageState extends State<StageThreeFlowPage> {
  int? _challengeNoteIndex;

  @override
  Widget build(BuildContext context) {
    final challengeNoteIndex = _challengeNoteIndex;
    if (challengeNoteIndex != null) {
      return StageThreeDoPage(
        noteIndex: challengeNoteIndex,
        soundOn: widget.soundOn,
        onSoundChanged: widget.onSoundChanged,
        sparklesOn: widget.sparklesOn,
        onSparklesChanged: widget.onSparklesChanged,
        onBack: () => setState(() => _challengeNoteIndex = null),
      );
    }
    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.width > screenSize.height;
    // 1단계와 동일한 화면 방향별 장면을 써서 건반 크기를 맞춘다.
    final scene = LessonScene.of(landscape: wide, selected: null);
    final keyboard = scene.keyboard;
    return StageShell(
      title: '음정 챌린지!',
      subtitle: '연습할 음을 눌러 시작해요',
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      sparklesOn: widget.sparklesOn,
      onSparklesChanged: widget.onSparklesChanged,
      onBack: widget.onExit,
      headerHeight: wide ? 68 : StepCard.height,
      headerContentScale: wide ? 1 : 1.3,
      headerContentOffsetY: wide ? 0 : 150,
      child: Center(
        child: SceneView(
          scene: scene.size,
          onTap: (point) {
            final index = keyboard.hitWhiteKey(point);
            if (index != null && index < notes.length) {
              setState(() => _challengeNoteIndex = index);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('음 도형을 눌러보세요')));
            }
          },
          painter: SelectionPainter(keyboard: keyboard, scene: scene.size),
        ),
      ),
    );
  }
}
