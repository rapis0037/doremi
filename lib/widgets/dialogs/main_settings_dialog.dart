import 'package:flutter/material.dart';

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
  Future<void> Function()? onDeleteAccount,
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
                      onDeleteAccount: onDeleteAccount,
                    ),
                  ),
                  // '구독 관리'는 실제 상품이 없는 상태였다. 준비 중인 플랜을
                  // 안내하고 구매 복원이 동작하지 않는 화면은 심사 지침
                  // 2.1·3.1.1 에서 걸리므로 상품을 붙일 때까지 감춘다.
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
  Future<void> Function()? onDeleteAccount,
}) async {
  final provider = account.provider == SignInProvider.google
      ? 'Google'
      : 'Apple';
  final nickname = profile?.childNickname?.trim();
  final age = profile?.currentAge();
  // 삭제는 되돌릴 수 없어서, 진행 중에는 다이얼로그를 열어 둔 채 상태를 보여주고
  // 실패하면 같은 자리에서 이유를 알려 준다.
  var deleting = false;
  String? deleteError;

  await showDialog<void>(
    context: context,
    barrierDismissible: !deleting,
    builder: (accountContext) => StatefulBuilder(
      builder: (builderContext, setLocal) => PopScope(
        canPop: !deleting,
        child: Dialog(
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
                          '로그인 정보',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: deleting
                            ? null
                            : () => Navigator.pop(accountContext),
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
                      (
                        '아이 닉네임',
                        nickname?.isNotEmpty == true ? nickname! : '미설정',
                      ),
                      ('아이 나이', age == null ? '미설정' : '$age세'),
                    ],
                  ),
                  if (onSignOut != null) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: deleting
                            ? null
                            : () async {
                                final confirmed = await _confirmSignOut(
                                  accountContext,
                                );
                                if (confirmed != true ||
                                    !accountContext.mounted) {
                                  return;
                                }
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
                  if (onDeleteAccount != null) ...[
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Text(
                      '계정을 삭제하면 저장된 아이 닉네임과 나이,\n학습 설정이 모두 지워지고 되돌릴 수 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff687582), height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    if (deleteError != null) ...[
                      Text(
                        deleteError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: deleting
                            ? null
                            : () async {
                                final confirmed = await _confirmDeleteAccount(
                                  accountContext,
                                );
                                if (confirmed != true ||
                                    !accountContext.mounted) {
                                  return;
                                }
                                setLocal(() {
                                  deleting = true;
                                  deleteError = null;
                                });
                                try {
                                  await onDeleteAccount();
                                  if (!accountContext.mounted) return;
                                  Navigator.pop(accountContext);
                                  if (context.mounted) Navigator.pop(context);
                                } on AuthFailure catch (failure) {
                                  if (!accountContext.mounted) return;
                                  setLocal(() {
                                    deleting = false;
                                    deleteError = failure.message;
                                  });
                                } catch (_) {
                                  if (!accountContext.mounted) return;
                                  setLocal(() {
                                    deleting = false;
                                    deleteError =
                                        '계정을 삭제하지 못했어요.\n'
                                        '인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
                                  });
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: deleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '계정 삭제',
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

Future<bool?> _confirmDeleteAccount(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('계정을 삭제할까요?'),
    content: const Text(
      '로그인 계정과 함께\n'
      '아이 닉네임·나이, 학습 설정이\n'
      '모두 삭제됩니다.\n\n'
      '삭제한 정보는 되돌릴 수 없어요.',
      style: TextStyle(height: 1.5),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
        child: const Text('삭제'),
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
