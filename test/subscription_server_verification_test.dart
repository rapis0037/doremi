import 'package:doremi/subscription/entitlement.dart';
import 'package:doremi/subscription/subscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'support/fake_in_app_purchase.dart';

void main() {
  const settle = Duration(milliseconds: 20);
  final trialOver = DateTime.now().subtract(const Duration(days: 30));

  ({SubscriptionController controller, FakeSubscriptionBackend backend})
  buildWith(FakeStore store, {Entitlement verdict = Entitlement.none}) {
    final backend = FakeSubscriptionBackend(verifyResult: verdict);
    addTearDown(backend.dispose);
    final controller = SubscriptionController(
      accountCreatedAt: trialOver,
      store: store,
      backend: backend,
      accountToken: accountTokenFor('uid-1'),
      entitlementKey: 'uid-1',
      restoreSettleDelay: settle,
    );
    addTearDown(controller.dispose);
    return (controller: controller, backend: backend);
  }

  const active = Entitlement(status: EntitlementStatus.active);

  test('구매하면 영수증을 서버로 넘겨 확인받는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store, verdict: active);
    await built.controller.initialize();

    store.emit([fakePurchase(PurchaseStatus.purchased, receipt: 'token-abc')]);
    await Future<void>.delayed(settle);

    expect(built.backend.verifiedReceipts, ['android:token-abc']);
    expect(built.controller.isSubscribed, isTrue);
  });

  test('iOS 영수증은 app_store 로 넘어간다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store, verdict: active);
    await built.controller.initialize();

    store.emit([
      fakePurchase(
        PurchaseStatus.restored,
        receipt: 'jws-xyz',
        source: 'app_store',
      ),
    ]);
    await Future<void>.delayed(settle);

    expect(built.backend.verifiedReceipts, ['ios:jws-xyz']);
  });

  test('서버가 인정하지 않으면 스토어가 구매를 줘도 열리지 않는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store, verdict: Entitlement.none);
    await built.controller.initialize();

    store.emit([fakePurchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(settle);

    expect(built.backend.verifiedReceipts, isNotEmpty);
    expect(built.controller.isSubscribed, isFalse, reason: '판정 권한은 서버에만 있다');
    expect(built.controller.hasPremiumAccess, isFalse);
  });

  test('복원해도 앱이 스스로 권한을 켜지 않는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store, verdict: Entitlement.none);
    await built.controller.initialize();

    await built.controller.restore();
    expect(built.controller.isSubscribed, isFalse);
  });

  test('결제 유예 상태에서도 학습은 계속할 수 있다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store);
    await built.controller.initialize();

    built.backend.emit(const Entitlement(status: EntitlementStatus.grace));
    await Future<void>.delayed(settle);
    expect(built.controller.isSubscribed, isTrue);
  });

  test('서버에서 해지·환불이 오면 곧바로 잠긴다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store);
    await built.controller.initialize();

    built.backend.emit(active);
    await Future<void>.delayed(settle);
    expect(built.controller.isSubscribed, isTrue);

    built.backend.emit(const Entitlement(status: EntitlementStatus.expired));
    await Future<void>.delayed(settle);
    expect(built.controller.isSubscribed, isFalse);
  });

  test('검증 호출이 실패해도 가진 권한을 뺏지 않는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final built = buildWith(store);
    await built.controller.initialize();

    built.backend.emit(active);
    await Future<void>.delayed(settle);

    built.backend.failVerification = true;
    store.emit([fakePurchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(settle);

    expect(built.controller.isSubscribed, isTrue);
    expect(built.controller.errorMessage, isNotNull);
  });

  group('계정 식별자', () {
    test('같은 uid 는 항상 같은 UUID 가 된다', () {
      final token = accountTokenFor('uid-1');
      expect(accountTokenFor('uid-1'), token);
      expect(accountTokenFor('uid-2'), isNot(token));
      expect(
        token,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('서버(Node)와 같은 값을 만든다', () {
      // functions/src/entitlement.ts 의 accountTokenFor('uid-1') 결과.
      expect(accountTokenFor('uid-1'), _nodeAccountTokenForUid1);
    });
  });
}

/// Node 구현으로 미리 계산해 둔 값. 두 구현이 어긋나면 이 테스트가 깨진다.
const _nodeAccountTokenForUid1 = '12aabe86-3c14-5b94-8ee2-0eeb9bcba6db';
