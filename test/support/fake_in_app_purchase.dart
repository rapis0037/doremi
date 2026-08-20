import 'dart:async';

import 'package:doremi/subscription/entitlement.dart';
import 'package:doremi/subscription/subscription_backend.dart';
import 'package:doremi/subscription/subscription_controller.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// 스토어 응답을 테스트가 직접 지어내기 위한 대역.
class FakeStore implements InAppPurchase {
  FakeStore({
    this.available = true,
    this.throwOnRestore = false,
    this.sellsProduct = true,
  });

  final bool available;
  final bool throwOnRestore;

  /// false 면 스토어에 상품이 등록되지 않은 상태를 흉내 낸다.
  final bool sellsProduct;

  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// restorePurchases() 호출에 맞춰 스토어가 되돌려 줄 구매 내역.
  List<PurchaseDetails> restoreResult = const [];
  int restoreCallCount = 0;
  final completed = <String>[];

  void emit(List<PurchaseDetails> purchases) => _purchases.add(purchases);

  Future<void> dispose() => _purchases.close();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      if (sellsProduct)
        ProductDetails(
          id: premiumMonthlySubscriptionId,
          title: '프리미엄 월간',
          description: '월간 구독',
          price: '₩5,900',
          rawPrice: 5900,
          currencyCode: 'KRW',
        ),
    ],
    notFoundIDs: sellsProduct ? const [] : const [premiumMonthlySubscriptionId],
  );

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCallCount++;
    if (throwOnRestore) throw StateError('network down');
    if (restoreResult.isNotEmpty) emit(restoreResult);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.productID);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async => true;

  @override
  Future<String> countryCode() async => 'KR';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      throw UnimplementedError();
}

PurchaseDetails fakePurchase(
  PurchaseStatus status, {
  String productId = premiumMonthlySubscriptionId,
  String receipt = 'receipt-1',
  String source = 'google_play',
}) => PurchaseDetails(
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: receipt,
    serverVerificationData: receipt,
    source: source,
  ),
  transactionDate: null,
  status: status,
);

/// 서버(Cloud Functions + Firestore) 대역.
class FakeSubscriptionBackend implements SubscriptionBackend {
  FakeSubscriptionBackend({this.verifyResult = Entitlement.none});

  final _entitlements = StreamController<Entitlement>.broadcast();

  /// verifyPurchase 가 돌려줄 판정 결과.
  Entitlement verifyResult;

  /// 검증 호출을 거부하고 싶을 때 세운다.
  bool failVerification = false;

  final verifiedReceipts = <String>[];

  /// 서버 기록이 바뀐 상황(갱신·해지·환불)을 흉내 낸다.
  void emit(Entitlement entitlement) => _entitlements.add(entitlement);

  Future<void> dispose() => _entitlements.close();

  @override
  Stream<Entitlement> watchEntitlement() => _entitlements.stream;

  @override
  Future<Entitlement> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    if (failVerification) throw StateError('verification failed');
    verifiedReceipts.add('$platform:$receipt');
    emit(verifyResult);
    return verifyResult;
  }
}
