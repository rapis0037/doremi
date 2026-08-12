import 'package:flutter/material.dart';

import '../layout/keyboard_layout.dart';
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
    required this.onExit,
  });
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onExit;

  @override
  State<StageThreeFlowPage> createState() => _StageThreeFlowPageState();
}

class _StageThreeFlowPageState extends State<StageThreeFlowPage> {
  bool _challenge = false;

  @override
  Widget build(BuildContext context) {
    if (_challenge) {
      return StageThreeDoPage(
        soundOn: widget.soundOn,
        onSoundChanged: widget.onSoundChanged,
        onBack: () => setState(() => _challenge = false),
      );
    }
    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.width > screenSize.height;
    // 1·2단계의 음 선택 화면과 같은 건반 크기를 사용한다.
    final keyboard = KeyboardLayout(y: 320, height: 350, count: 8);
    return StageShell(
      title: '음정 챌린지!',
      subtitle: '핑크 하트 도를 눌러 시작해요',
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      onBack: widget.onExit,
      headerHeight: wide ? 68 : StepCard.height,
      headerContentScale: wide ? 1 : 1.3,
      headerContentOffsetY: wide ? 0 : 150,
      child: Center(
        child: SceneView(
          onTap: (point) {
            final index = keyboard.hitWhiteKey(point);
            if (index == 0) {
              setState(() => _challenge = true);
            } else if (index != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('도 핑크 하트를 눌러보세요')));
            }
          },
          painter: SelectionPainter(keyboard: keyboard),
        ),
      ),
    );
  }
}
