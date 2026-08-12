import 'package:flutter/material.dart';

class SensoryChoice {
  const SensoryChoice({required this.sparklesOn, required this.voiceOn});

  final bool sparklesOn;
  final bool voiceOn;
}

class SensorySetupPage extends StatelessWidget {
  const SensorySetupPage({super.key, required this.onSelected});

  final ValueChanged<SensoryChoice> onSelected;

  static const _choices = [
    _Choice('🌿 편안하게 시작할게요', '스파클 끄기 + 계이름 음성 끄기', false, false),
    _Choice('🔊 소리만 들려주세요', '스파클 끄기 + 계이름 음성 켜기', false, true),
    _Choice('✨ 화면 효과만 보여주세요', '스파클 켜기 + 계이름 음성 끄기', true, false),
    _Choice('🎵 모두 사용해볼게요', '스파클 켜기 + 계이름 음성 켜기', true, true),
    _Choice('🤔 아직 잘 모르겠어요', '끄고 시작할게요', false, false),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '너두! 도레미!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              '아이에게 편안한 학습 방식을 골라보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 28),
            const Text(
              '선택지',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Divider(),
            ..._choices.map(
              (choice) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                title: Text(
                  choice.label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    choice.description,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSelected(
                  SensoryChoice(
                    sparklesOn: choice.sparklesOn,
                    voiceOn: choice.voiceOn,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '학습 중에도 음표 버튼에서 언제든 바꿀 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff687582)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Choice {
  const _Choice(this.label, this.description, this.sparklesOn, this.voiceOn);

  final String label;
  final String description;
  final bool sparklesOn;
  final bool voiceOn;
}
