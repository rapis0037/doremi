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
      subtitle: '만나고 싶은 AR 방식을 골라보세요',
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
                const SizedBox(height: StepCard.gap),
                ModeButton(
                  title: '톡톡 Space',
                  subtitle: '피아노 건반이 바닥이 되는 공간 AR',
                  color: const Color(0xffdff3ff),
                  icon: Icons.view_in_ar_outlined,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('톡톡 Space는 준비 중입니다')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
