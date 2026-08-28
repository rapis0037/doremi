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
                    contentOffsetY: wide ? 0 : 60,
                  ),
                  if (subscription != null && !subscription!.isSubscribed) ...[
                    // 홈 헤더 내용은 시각적 중심을 맞추려고 아래로 이동되어
                    // SizedBox 경계를 넘어온다. 배너가 바로 이어지면 부제목을
                    // 덮으므로 실제 콘텐츠가 끝나는 만큼 자리를 확보한다.
                    const SizedBox(height: 44),
                    _SubscriptionStatusBanner(subscription: subscription!),
                  ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          // 무료 이용 배너나 안전 영역 때문에 본문 높이가 줄어들어도 고양이와
          // 세 단계 카드를 한 묶음으로 축소해, 스크롤 없이 전부 보여 준다.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.maxWidth.clamp(0, kCardMaxWidth).toDouble(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: constraints.maxWidth
                        .clamp(0, kCardMaxWidth)
                        .toDouble(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _stepCards(),
                    ),
                  ),
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
