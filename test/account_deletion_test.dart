import 'package:doremi/auth/auth_models.dart';
import 'package:doremi/widgets/dialogs/main_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _account = AuthAccount(
  uid: 'guardian-1',
  provider: SignInProvider.apple,
  providerSubject: 'apple-subject',
  email: 'guardian@example.com',
);

const _profile = GuardianProfile(
  uid: 'guardian-1',
  step: OnboardingStep.completed,
  childAge: 6,
  ageReferenceYear: 2026,
  childNickname: '도레미',
);

Future<void> _openAccountDialog(
  WidgetTester tester, {
  required Future<void> Function() onDeleteAccount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showMainSettings(
                context,
                account: _account,
                profile: _profile,
                voiceOn: true,
                sparklesOn: true,
                onVoiceChanged: (_) {},
                onSparklesChanged: (_) {},
                onDeleteAccount: onDeleteAccount,
              ),
              child: const Text('설정 열기'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('설정 열기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('로그인 정보'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('계정 삭제는 확인을 받은 뒤 실행되고 설정 화면을 닫는다', (tester) async {
    var deleted = false;

    await _openAccountDialog(
      tester,
      onDeleteAccount: () async => deleted = true,
    );

    expect(find.text('계정 삭제'), findsOneWidget);
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();

    // 확인 없이 바로 지우지 않는다.
    expect(deleted, isFalse);
    expect(find.text('계정을 삭제할까요?'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    // 로그인 정보와 설정 다이얼로그가 모두 닫혀 가입 화면으로 돌아간다.
    expect(find.text('로그인 정보'), findsNothing);
    expect(find.text('설정'), findsNothing);
  });

  testWidgets('취소하면 계정을 지우지 않는다', (tester) async {
    var deleted = false;

    await _openAccountDialog(
      tester,
      onDeleteAccount: () async => deleted = true,
    );

    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
    // 계정 삭제 버튼은 로그인 정보 다이얼로그에만 있어 열림 여부를 그대로 나타낸다.
    expect(find.text('계정 삭제'), findsOneWidget);
  });

  testWidgets('삭제에 실패하면 이유를 보여주고 다이얼로그를 유지한다', (tester) async {
    await _openAccountDialog(
      tester,
      onDeleteAccount: () async => throw const AuthFailure(
        AuthFailureKind.network,
        '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
      ),
    );

    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('인터넷 연결을 확인한 뒤 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('계정 삭제'), findsOneWidget);
    // 다시 시도할 수 있어야 한다.
    expect(
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('계정 삭제'),
          matching: find.byType(FilledButton),
        ),
      ).onPressed,
      isNotNull,
    );
  });
}
