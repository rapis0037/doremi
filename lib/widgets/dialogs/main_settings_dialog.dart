import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_models.dart';
import '../settings_row.dart';

Future<void> showMainSettings(
  BuildContext context, {
  AuthAccount? account,
  GuardianProfile? profile,
  required bool voiceOn,
  required bool sparklesOn,
  required ValueChanged<bool> onVoiceChanged,
  required ValueChanged<bool> onSparklesChanged,
  Future<void> Function()? onSignOut,
}) async {
  var currentVoice = voiceOn;
  var currentSparkles = sparklesOn;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 50),
                    const Expanded(
                      child: Text(
                        '설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('완료'),
                    ),
                  ],
                ),
                const Divider(),
                if (account != null) ...[
                  _SectionLabel('계정'),
                  SettingsRow(
                    label: '로그인 정보',
                    onTap: () => _showAccountDialog(
                      dialogContext,
                      account: account,
                      profile: profile,
                      onSignOut: onSignOut,
                    ),
                  ),
                  SettingsRow(
                    label: '구독 관리',
                    onTap: () => _showSubscriptionManagement(dialogContext),
                  ),
                ],
                _SectionLabel('학습 설정'),
                SettingsRow(
                  label: '보호자 설정',
                  onTap: () async {
                    await _showGuardianSettings(
                      dialogContext,
                      voiceOn: currentVoice,
                      sparklesOn: currentSparkles,
                      onVoiceChanged: (value) {
                        currentVoice = value;
                        onVoiceChanged(value);
                      },
                      onSparklesChanged: (value) {
                        currentSparkles = value;
                        onSparklesChanged(value);
                      },
                    );
                    setLocal(() {});
                  },
                ),
                const Divider(),
                SettingsRow(
                  label: '개인정보 처리 안내',
                  onTap: () => _showInfoDialog(
                    dialogContext,
                    title: '개인정보 처리 안내',
                    body:
                        '너두! 도레미는 서비스 이용을 위해\n'
                        '로그인 계정의 식별 정보와 이메일을 저장합니다.\n\n'
                        '아이의 나이, 닉네임, 학습 설정은\n'
                        '맞춤형 학습 환경을 제공하는 데 사용됩니다.\n\n'
                        '이 정보는 Firebase에 안전하게 저장되며,\n'
                        '앱에서 비밀번호를 직접 수집하지 않습니다.',
                  ),
                ),
                SettingsRow(
                  label: '회사 안내',
                  onTap: () => _showInfoDialog(
                    dialogContext,
                    title: '회사 안내',
                    body:
                        '회사명\n'
                        'CT.ENT\n\n'
                        '한글명\n'
                        '치즈태비 엔터테인먼트\n\n'
                        '영문명\n'
                        'CT.ENT / Cheese Tabby Entertainment\n\n'
                        '개발자\n'
                        '윤요한\n\n'
                        '기획자\n'
                        '전한나\n\n'
                        '대표 이메일 및 고객지원 문의\n'
                        'cheesetabby.ent@gmail.com\n\n'
                        '고객지원 이메일\n'
                        'cheesetabby.ent@gmail.com\n\n'
                        '고객지원 문의\n'
                        'http://pf.kakao.com/_bxorxnX/chat\n\n'
                        '인스타그램 - 치즈태비\n'
                        '@cheesetabby_ent',
                  ),
                ),
                SettingsRow(
                  label: '앱 정보',
                  onTap: () => _showInfoDialog(
                    dialogContext,
                    title: '너두! 도레미!',
                    body: '고양이와 함께 시작하는 음악 탐험\n앱 버전 1.0.0',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showSubscriptionManagement(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (subscriptionContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 50),
                  const Expanded(
                    child: Text(
                      '구독 관리',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(subscriptionContext),
                    child: const Text('완료'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xfffff7fa),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffffdce8)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 플랜',
                      style: TextStyle(
                        color: Color(0xff596775),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '무료 플랜',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '프리미엄 구독 플랜을 준비하고 있어요.',
                        maxLines: 1,
                        style: TextStyle(color: Color(0xff596775), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SubscriptionNotice(
                icon: Icons.event_available_outlined,
                title: '해지 후에도 이용 기간 보장',
                body: '구독을 해지해도\n이미 결제한 이용 기간이 끝날 때까지\n프리미엄 기능을 사용할 수 있어요.',
              ),
              const _SubscriptionNotice(
                icon: Icons.storefront_outlined,
                title: '스토어에서 직접 관리',
                body:
                    '플랜과 결제 수단 변경, 구독 해지는\nApple 또는 Google 스토어에서\n직접 관리할 수 있어요.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _openStoreSubscriptionManagement(subscriptionContext),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Platform.isIOS
                          ? 'App Store에서 구독 관리'
                          : 'Google Play에서 구독 관리',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('구독 상품 연결이 완료되면 구매 복원을 사용할 수 있어요.'),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('구매 복원'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SubscriptionNotice extends StatelessWidget {
  const _SubscriptionNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 23),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(color: Color(0xff596775), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _openStoreSubscriptionManagement(BuildContext context) async {
  final uri = Platform.isIOS
      ? Uri.parse('https://apps.apple.com/account/subscriptions')
      : Uri.parse(
          'https://play.google.com/store/account/subscriptions'
          '?package=com.cheesetabby.doremi',
        );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('스토어 구독 관리 화면을 열지 못했어요.')));
  }
}

Future<void> _showGuardianSettings(
  BuildContext context, {
  required bool voiceOn,
  required bool sparklesOn,
  required ValueChanged<bool> onVoiceChanged,
  required ValueChanged<bool> onSparklesChanged,
}) async {
  var currentVoice = voiceOn;
  var currentSparkles = sparklesOn;

  await showDialog<void>(
    context: context,
    builder: (guardianContext) => StatefulBuilder(
      builder: (context, setLocal) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 50),
                    const Expanded(
                      child: Text(
                        '보호자 설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(guardianContext),
                      child: const Text('완료'),
                    ),
                  ],
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Text(
                    '아이에게 편안한 학습 환경을\n보호자가 직접 설정할 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xff596775), height: 1.4),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  title: const Text(
                    '계이름 목소리',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('음을 누를 때 계이름을 들려줘요.'),
                  value: currentVoice,
                  onChanged: (value) {
                    currentVoice = value;
                    onVoiceChanged(value);
                    setLocal(() {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  title: const Text(
                    '스파클 효과',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('학습할 때 반짝이는 효과를 보여줘요.'),
                  value: currentSparkles,
                  onChanged: (value) {
                    currentSparkles = value;
                    onSparklesChanged(value);
                    setLocal(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

Future<void> _showAccountDialog(
  BuildContext context, {
  required AuthAccount account,
  GuardianProfile? profile,
  Future<void> Function()? onSignOut,
}) async {
  final provider = account.provider == SignInProvider.google
      ? 'Google'
      : 'Apple';
  final nickname = profile?.childNickname?.trim();
  final age = profile?.currentAge();
  await showDialog<void>(
    context: context,
    builder: (accountContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 50),
                  const Expanded(
                    child: Text(
                      '로그인 정보',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(accountContext),
                    child: const Text('완료'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xffffdce8),
                child: Text(
                  nickname?.isNotEmpty == true ? nickname![0] : '♪',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xffb72f5b),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                nickname?.isNotEmpty == true ? nickname! : '닉네임 미설정',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (age != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$age세',
                  style: const TextStyle(
                    color: Color(0xff596775),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _AccountInfoCard(
                rows: [
                  ('로그인 방식', provider),
                  ('이메일', account.email ?? '제공되지 않음'),
                  ('아이 닉네임', nickname?.isNotEmpty == true ? nickname! : '미설정'),
                  ('아이 나이', age == null ? '미설정' : '$age세'),
                ],
              ),
              if (onSignOut != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await _confirmSignOut(accountContext);
                      if (confirmed != true || !accountContext.mounted) return;
                      Navigator.pop(accountContext);
                      Navigator.pop(context);
                      await onSignOut();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xfffff7fa),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffffdce8)),
    ),
    child: Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    rows[index].$1,
                    style: const TextStyle(
                      color: Color(0xff596775),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      rows[index].$2,
                      maxLines: 1,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index != rows.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

Future<bool?> _confirmSignOut(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('로그아웃할까요?'),
    content: const Text(
      '로그아웃하면 이 기기에 저장된\n학습 설정도 함께 초기화됩니다.',
      style: TextStyle(height: 1.5),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('로그아웃'),
      ),
    ],
  ),
);

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String body,
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 36),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 18),
            Text(
              body,
              textAlign: TextAlign.left,
              style: const TextStyle(height: 1.65, color: Color(0xff44515d)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
