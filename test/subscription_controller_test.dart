import 'package:doremi/subscription/subscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_in_app_purchase.dart';

void main() {
  const settle = Duration(milliseconds: 20);
  final joinedToday = DateTime.now();
  final trialOver = DateTime.now().subtract(const Duration(days: 30));

  SubscriptionController controllerFor(
    FakeStore store, {
    DateTime? accountCreatedAt,
    SharedPreferences? preferences,
  }) => SubscriptionController(
    accountCreatedAt: accountCreatedAt ?? trialOver,
    store: store,
    preferences: preferences,
    entitlementKey: 'uid-1',
    restoreSettleDelay: settle,
  );

  test('보류 결제 중에는 구독 버튼이 다시 열리지 않는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final controller = controllerFor(store);
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.purchase();
    expect(controller.purchasePending, isTrue);

    store.emit([fakePurchase(PurchaseStatus.pending)]);
    await Future<void>.delayed(settle);
    expect(
      controller.purchasePending,
      isTrue,
      reason: '보류 상태가 오면 진행 중으로 남아야 중복 결제가 막힌다',
    );

    store.emit([fakePurchase(PurchaseStatus.purchased)]);
    await Future<void>.delayed(settle);
    expect(controller.purchasePending, isFalse);
    expect(controller.isSubscribed, isTrue);
  });

  test('다른 상품 이벤트는 진행 중 상태를 건드리지 않는다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final controller = controllerFor(store);
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.purchase();

    store.emit([
      fakePurchase(PurchaseStatus.purchased, productId: 'other_item'),
    ]);
    await Future<void>.delayed(settle);
    expect(controller.purchasePending, isTrue);
    expect(controller.isSubscribed, isFalse);
  });

  group('오프라인 권한 캐시', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('스토어에 연결하지 못해도 최근 확인한 구독은 유지된다', () async {
      final preferences = await SharedPreferences.getInstance();
      final online = FakeStore()
        ..restoreResult = [fakePurchase(PurchaseStatus.restored)];
      addTearDown(online.dispose);
      final first = controllerFor(online, preferences: preferences);
      await first.initialize();
      expect(first.isSubscribed, isTrue);
      first.dispose();

      // 다음 실행에서 스토어가 죽어 있어도 학습을 막지 않는다.
      final offline = FakeStore(available: false);
      addTearDown(offline.dispose);
      final second = controllerFor(offline, preferences: preferences);
      addTearDown(second.dispose);
      expect(second.isSubscribed, isTrue);
      await second.initialize();
      expect(second.hasPremiumAccess, isTrue);
    });

    test('유예 기간이 지난 캐시는 인정하지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'premium_subscribed_uid-1': true,
        'premium_verified_at_uid-1': DateTime.now()
            .subtract(const Duration(days: 8))
            .millisecondsSinceEpoch,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = FakeStore(available: false);
      addTearDown(store.dispose);
      final controller = controllerFor(store, preferences: preferences);
      addTearDown(controller.dispose);

      expect(controller.isSubscribed, isFalse);
    });

    test('스토어가 구독을 돌려주지 않으면 캐시된 권한도 지운다', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = FakeStore()
        ..restoreResult = [fakePurchase(PurchaseStatus.restored)];
      addTearDown(store.dispose);
      final first = controllerFor(store, preferences: preferences);
      await first.initialize();
      expect(preferences.getBool('premium_subscribed_uid-1'), isTrue);
      first.dispose();

      // 해지 후: 스토어가 아무 것도 돌려주지 않는다.
      store.restoreResult = const [];
      final second = controllerFor(store, preferences: preferences);
      addTearDown(second.dispose);
      await second.initialize();
      expect(second.isSubscribed, isFalse);
      expect(preferences.getBool('premium_subscribed_uid-1'), isFalse);
    });

    test('복원이 실패하면 기존 권한을 그대로 둔다', () async {
      SharedPreferences.setMockInitialValues({
        'premium_subscribed_uid-1': true,
        'premium_verified_at_uid-1': DateTime.now().millisecondsSinceEpoch,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = FakeStore(throwOnRestore: true);
      addTearDown(store.dispose);
      final controller = controllerFor(store, preferences: preferences);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.isSubscribed, isTrue);
      expect(preferences.getBool('premium_subscribed_uid-1'), isTrue);
    });
  });

  group('구매 복원 결과 안내', () {
    test('복원할 내역이 없으면 그렇다고 알려 준다', () async {
      final store = FakeStore();
      addTearDown(store.dispose);
      final controller = controllerFor(store);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.restore();
      expect(controller.statusMessage, contains('복원할 구매 내역이 없어요'));
      expect(controller.errorMessage, isNull);
      expect(controller.purchasePending, isFalse);
    });

    test('복원에 성공하면 구독이 살아난다', () async {
      final store = FakeStore()
        ..restoreResult = [fakePurchase(PurchaseStatus.restored)];
      addTearDown(store.dispose);
      final controller = controllerFor(store);
      addTearDown(controller.dispose);
      await controller.initialize();

      await controller.restore();
      expect(controller.isSubscribed, isTrue);
      expect(controller.statusMessage, contains('복원했어요'));
    });

    test('스토어를 쓸 수 없으면 조용히 넘어가지 않는다', () async {
      final store = FakeStore(available: false);
      addTearDown(store.dispose);
      final controller = controllerFor(store);
      addTearDown(controller.dispose);
      await controller.initialize();

      final callsBefore = store.restoreCallCount;
      await controller.restore();
      expect(store.restoreCallCount, callsBefore);
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('가격 표시', () {
    test('스토어 가격을 받기 전에는 가격도 결제도 내놓지 않는다', () async {
      final store = FakeStore(sellsProduct: false);
      addTearDown(store.dispose);
      final controller = controllerFor(store);
      addTearDown(controller.dispose);

      expect(controller.priceLabel, isNull);
      expect(controller.canPurchase, isFalse);

      await controller.initialize();
      expect(controller.priceLabel, isNull);
      expect(controller.canPurchase, isFalse);

      // 결제를 눌러도 시작되지 않고 이유를 남긴다.
      await controller.purchase();
      expect(controller.errorMessage, isNotNull);
    });

    test('스토어가 알려 준 가격을 그대로 쓴다', () async {
      final store = FakeStore();
      addTearDown(store.dispose);
      final controller = controllerFor(store);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.priceLabel, '₩5,900');
      expect(controller.canPurchase, isTrue);
    });
  });

  test('무료 체험 중에는 구독 없이도 콘텐츠가 열린다', () async {
    final store = FakeStore();
    addTearDown(store.dispose);
    final controller = controllerFor(store, accountCreatedAt: joinedToday);
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(controller.isSubscribed, isFalse);
    expect(controller.hasPremiumAccess, isTrue);
  });
}
