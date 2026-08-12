import 'package:flutter/material.dart';

import '../core/models.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import '../widgets/cat_face.dart';
import '../widgets/dialogs/main_settings_dialog.dart';
import '../widgets/step_card.dart';

/// 세로 배치에서 카드가 지나치게 넓어지지 않도록 하는 상한.
const double _contentMaxWidth = 460;

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

  List<Widget> _stepCards() => [
    StepCard(
      number: '1단계',
      title: '톡톡! 한 음 익히기',
      kind: RestKind.half,
      color: const Color(0xffffdce8),
      onTap: onStageOne,
    ),
    const SizedBox(height: StepCard.gap),
    StepCard(
      number: '2단계',
      title: 'AR 톡톡! 한 음 만나기',
      kind: RestKind.three,
      color: const Color(0xfffff1c6),
      onTap: onStageTwo,
    ),
    const SizedBox(height: StepCard.gap),
    StepCard(
      number: '3단계',
      title: '음정 챌린지!',
      kind: RestKind.whole,
      color: const Color(0xffdff3ff),
      onTap: onStageThree,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 가로가 더 긴 화면(가로 태블릿/폰 가로)에서는 고양이와 단계
              // 카드를 좌우로 나눠 스크롤 없이 한 화면에 담는다.
              final wide = constraints.maxWidth > constraints.maxHeight;
              return Column(
                children: [
                  // 홈은 돌아갈 곳이 없어 나가기 버튼을 두지 않는다.
                  // 안드로이드 뒤로 가기로 그대로 종료된다.
                  AppHeader(
                    title: '너두! 도레미!',
                    subtitle: '고양이와 함께 시작하는 음악 탐험',
                    trailing: Icons.settings_outlined,
                    onTrailing: () => showMainSettings(context),
                    // 세로에서는 헤더도 단계 카드 한 칸만큼 자리를 잡는다.
                    // 가로는 화면이 낮아 그대로 두면 본문이 눌린다.
                    height: wide ? AppHeader.defaultHeight : StepCard.height,
                    contentScale: wide ? 1 : 1.3,
                    contentOffsetY: 60,
                  ),
                  Expanded(child: wide ? _buildWide() : _buildTall()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  //고양이 대가리 크기 조절 및 위치조절
  Widget _buildTall() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            children: [
              // 고양이와 단계 목록을 한 칸 아래에서 시작하게 한다.
              const SizedBox(height: StepCard.height + StepCard.gap),
              const SizedBox(
                height: 190,
                child: Center(child: CatFace(width: 198)),
              ),
              const SizedBox(height: StepCard.gap),
              ..._stepCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Transform.translate(
              offset: Offset(0, -15),
              child: Center(child: CatFace(width: 210)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 6,
            child: _VerticallyCenteredScroll(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _stepCards(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공간이 남으면 가운데 정렬하고, 모자라면 스크롤되는 컨테이너.
class _VerticallyCenteredScroll extends StatelessWidget {
  const _VerticallyCenteredScroll({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
