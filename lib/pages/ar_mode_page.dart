import 'package:flutter/material.dart';

import '../widgets/mode_button.dart';
import '../widgets/stage_shell.dart';
import '../widgets/step_card.dart';

class ArModePage extends StatelessWidget {
  const ArModePage({
    super.key,
    required this.soundOn,
    required this.onSoundChanged,
    required this.onBack,
    required this.onLite,
  });
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onBack;
  final VoidCallback onLite;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.width > screenSize.height;
    return StageShell(
      title: 'AR 톡톡! 한 음 만나기',
      // 톡톡 Space 를 감추어 고를 것이 하나뿐이므로 '골라보세요'를 쓰지 않는다.
      subtitle: '카메라를 켜고 한 음을 만나 보세요',
      soundOn: soundOn,
      onSoundChanged: onSoundChanged,
      onBack: onBack,
      headerHeight: wide ? 68 : StepCard.height,
      headerContentScale: wide ? 1 : 1.3,
      headerContentOffsetY: wide ? 0 : 150,
      headerContentWidthScale: 1.21,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            // 톡톡 Space('피아노 건반이 바닥이 되는 공간 AR')는 아직 구현되지
            // 않았다. 눌러도 '준비 중' 안내만 뜨는 항목은 App Store 심사 지침
            // 2.1(App Completeness)에서 지적하는 대상이라 출시 전까지 감춘다.
            // 구현이 끝나면 이 자리에 ModeButton 을 다시 넣으면 된다.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModeButton(
                  title: '톡톡 Lite',
                  subtitle: '카메라 화면 위에서 한 음 만나기',
                  color: const Color(0xffffdbe8),
                  icon: Icons.camera_alt_outlined,
                  onTap: onLite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
