import 'package:doremi/subscription/subscription_controller.dart';
import 'package:doremi/widgets/dialogs/main_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_in_app_purchase.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    SubscriptionController subscription,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSubscriptionManagement(
                context,
                subscription: subscription,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('무료 기간 종료 후 콘텐츠 제한과 직접 구독 안내를 보여준다', (tester) async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final subscription = SubscriptionController(
      accountCreatedAt: DateTime.now().subtract(const Duration(days: 15)),
      store: store,
      restoreSettleDelay: const Duration(milliseconds: 20),
    );
    addTearDown(subscription.dispose);
    await tester.runAsync(subscription.initialize);

    await openDialog(tester, subscription);

    expect(find.text('무료 이용 종료'), findsOneWidget);
    expect(find.text('3개 학습 콘텐츠 이용이 제한됩니다.'), findsOneWidget);
    expect(find.text('무료 이용 후 자동 결제 없음'), findsOneWidget);
    expect(find.text('₩5,900/월 구독하기'), findsOneWidget);
    expect(find.text('구매 복원'), findsOneWidget);
  });

  testWidgets('가격을 못 받았으면 앱에 적힌 가격 대신 확인 중으로 두고 결제를 막는다', (tester) async {
    final store = FakeStore(sellsProduct: false);
    addTearDown(store.dispose);
    final subscription = SubscriptionController(
      accountCreatedAt: DateTime.now().subtract(const Duration(days: 15)),
      store: store,
      restoreSettleDelay: const Duration(milliseconds: 20),
    );
    addTearDown(subscription.dispose);
    await tester.runAsync(subscription.initialize);

    await openDialog(tester, subscription);

    expect(find.text('가격 확인 중'), findsOneWidget);
    expect(find.textContaining('₩5,900'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('가격 확인 중'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
