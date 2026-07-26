import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import '../widgets/cat_face.dart';
import '../widgets/dialogs/main_settings_dialog.dart';
import '../widgets/responsive_viewport.dart';
import '../widgets/step_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onStageOne,
    required this.onStageTwo,
    required this.onStageThree,
  });
  final VoidCallback onStageOne;
  final VoidCallback onStageTwo;
  final VoidCallback onStageThree;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ResponsiveViewport(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  AppHeader(
                    title: '너두! 도레미!',
                    subtitle: '고양이와 함께 시작하는 음악 탐험',
                    leading: Icons.arrow_back_rounded,
                    onLeading: () => SystemNavigator.pop(),
                    trailing: Icons.settings_outlined,
                    onTrailing: () => showMainSettings(context),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 150, child: Center(child: CatFace())),
                  const SizedBox(height: 12),
                  StepCard(number: '1단계', title: '톡톡! 한 음 익히기', kind: RestKind.half, color: const Color(0xffffdce8), onTap: onStageOne),
                  const SizedBox(height: 12),
                  StepCard(number: '2단계', title: 'AR 톡톡! 한 음 만나기', kind: RestKind.three, color: const Color(0xfffff1c6), onTap: onStageTwo),
                  const SizedBox(height: 12),
                  StepCard(number: '3단계', title: '음정 챌린지!', kind: RestKind.whole, color: const Color(0xffdff3ff), onTap: onStageThree),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
