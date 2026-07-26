import 'package:flutter/material.dart';

import '../settings_row.dart';

Future<void> showMainSettings(BuildContext context) async {
  void message(String text) {
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text 화면은 개발자 정보 연결 후 표시됩니다')),
    );
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 50),
                  const Expanded(
                    child: Text('설정', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('완료')),
                ],
              ),
              const Divider(),
              SettingsRow(label: '로그인 정보', onTap: () => message('로그인 정보')),
              SettingsRow(label: '개인정보 처리방침', onTap: () => message('개인정보 처리방침')),
              SettingsRow(label: '회사 정보', onTap: () => message('회사 정보')),
            ],
          ),
        ),
      ),
    ),
  );
}
