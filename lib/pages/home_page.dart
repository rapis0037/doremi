import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../auth/auth_models.dart';
import '../core/models.dart';
import '../subscription/subscription_controller.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import '../widgets/cat_face.dart';
import '../widgets/dialogs/main_settings_dialog.dart';
import '../widgets/step_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onStageOne,
    required this.onStageTwo,
    required this.onStageThree,
    required this.voiceOn,
    required this.sparklesOn,
    required this.onVoiceChanged,
    required this.onSparklesChanged,
    this.account,
    this.profile,
    this.subscription,
    this.onSignOut,
    this.onDeleteAccount,
  });
  final VoidCallback onStageOne;
  final VoidCallback onStageTwo;
  final VoidCallback onStageThree;
  final bool voiceOn;
  final bool sparklesOn;
  final ValueChanged<bool> onVoiceChanged;
  final ValueChanged<bool> onSparklesChanged;
  final AuthAccount? account;
  final GuardianProfile? profile;
  final SubscriptionController? subscription;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;

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
                    onTrailing: () => showMainSettings(
                      context,
                      account: account,
                      profile: profile,
                      subscription: subscription,
                      voiceOn: voiceOn,
                      sparklesOn: sparklesOn,
                      onVoiceChanged: onVoiceChanged,
                      onSparklesChanged: onSparklesChanged,
                      onSignOut: onSignOut,
                      onDeleteAccount: onDeleteAccount,
                    ),
                    // 세로에서는 헤더도 단계 카드 한 칸만큼 자리를 잡는다.
                    // 가로는 화면이 낮아 그대로 두면 본문이 눌린다.
                    height: wide ? AppHeader.defaultHeight : StepCard.height,
                    contentScale: wide ? 1 : 1.3,
                    contentOffsetY: 60,
                  ),
                  if (subscription != null)
                    _SubscriptionStatusBanner(subscription: subscription!),
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
          constraints: const BoxConstraints(maxWidth: kCardMaxWidth),
          child: Column(
            children: [
              // 작은 화면에서도 3단계 카드 하단이 잘리지 않도록 콘텐츠 묶음을
              // 기존 위치보다 위로 당긴다.
              const SizedBox(height: 68),
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
                constraints: const BoxConstraints(maxWidth: kCardMaxWidth),
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

class _SubscriptionStatusBanner extends StatelessWidget {
  const _SubscriptionStatusBanner({required this.subscription});

  final SubscriptionController subscription;

  @override
  Widget build(BuildContext context) {
    final subscribed = subscription.isSubscribed;
    final trialActive = subscription.trialActive;
    final text = subscribed
        ? '프리미엄 구독 이용 중'
        : trialActive
        ? '무료 이용 ${subscription.remainingTrialDays}일 남음 · 종료 후 자동 결제되지 않아요'
        : '무료 이용 종료 · 학습을 계속하려면 구독이 필요해요';
    final background = subscribed || trialActive
        ? const Color(0xfffff7fa)
        : const Color(0xffffecec);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
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
