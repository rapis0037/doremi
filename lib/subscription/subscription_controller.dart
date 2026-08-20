import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement.dart';
import 'subscription_backend.dart';
import 'trial_period.dart';

const premiumMonthlySubscriptionId = 'doremi_premium_monthly';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    required DateTime accountCreatedAt,
    InAppPurchase? store,
    this.backend,
    this.accountToken,
    this.preferences,
    String? entitlementKey,
    this.restoreSettleDelay = const Duration(seconds: 3),
    this.offlineGrace = const Duration(days: 7),
  }) : trial = TrialPeriod(startedAt: accountCreatedAt),
       _store = store ?? InAppPurchase.instance,
       _entitlementKey = entitlementKey ?? 'device' {
    _loadCachedEntitlement();
  }

  final TrialPeriod trial;
  final InAppPurchase _store;

  /// 구독 권한을 판정하는 서버. null 이면 스토어 응답만 보고 판단한다.
  final SubscriptionBackend? backend;

  /// 결제할 때 스토어에 심어 두는 구매자 식별자. 서버가 영수증의 주인을
  /// 확인하는 데 쓴다.
  final String? accountToken;

  /// 확인한 구독 권한을 남겨 두는 곳. 없으면 매번 스토어에만 의존한다.
  final SharedPreferences? preferences;

  /// restorePurchases() 는 복원 결과를 purchaseStream 으로만 알려 준다.
  /// 호출한 뒤 이만큼 스트림을 지켜본 다음 복원 성공 여부를 판정한다.
  final Duration restoreSettleDelay;

  /// 스토어에 연결하지 못하는 동안(비행기 모드·서버 장애) 마지막으로 확인한
  /// 구독 권한을 그대로 인정해 주는 기간. 이 기간이 지나면 다시 스토어 확인을
  /// 요구해, 결제한 사용자가 잠기지도 해지한 사용자가 계속 쓰지도 않게 한다.
  final Duration offlineGrace;

  final String _entitlementKey;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<Entitlement>? _entitlementSubscription;

  ProductDetails? _product;
  bool _isSubscribed = false;
  bool _storeAvailable = false;
  bool _loading = true;
  bool _purchasePending = false;
  String? _errorMessage;
  String? _statusMessage;

  /// 복원 판정 중에는 스트림으로 들어오는 결과가 구독 여부를 결정하므로,
  /// 그동안 도착한 결과를 여기에 모아 둔다.
  bool _restoreSweepActive = false;
  bool _restoreSweepFoundSubscription = false;

  bool get isSubscribed => _isSubscribed;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  bool get purchasePending => _purchasePending;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  DateTime get trialStartedAt => trial.startedAt;
  DateTime get trialEndsAt => trial.endsAt;
  int get remainingTrialDays => trial.remainingDaysAt(DateTime.now());
  bool get trialActive => trial.isActiveAt(DateTime.now());
  bool get hasPremiumAccess => _isSubscribed || trialActive;

  /// 스토어가 알려 준 현지 통화 가격. 아직 받지 못했으면 null 이다. 앱에
  /// 적어 둔 값을 대신 보여주면 통화·인상된 가격이 어긋난다.
  String? get priceLabel => _product?.price;

  /// 가격까지 확인된 상태에서만 결제를 시작할 수 있다.
  bool get canPurchase =>
      _product != null && _storeAvailable && !_purchasePending;

  String get _subscribedPrefKey => 'premium_subscribed_$_entitlementKey';
  String get _verifiedAtPrefKey => 'premium_verified_at_$_entitlementKey';

  Future<void> initialize() async {
    // 서버 기록이 있으면 그것이 진짜다. 갱신·해지·환불이 여기로 흘러온다.
    _entitlementSubscription = backend?.watchEntitlement().listen(
      _applyEntitlement,
      onError: (_) {
        // 서버를 못 읽는 동안에는 캐시된 권한(오프라인 유예)을 유지한다.
      },
    );

    _purchaseSubscription = _store.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        _purchasePending = false;
        _errorMessage = '구독 정보를 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
        notifyListeners();
      },
    );

    try {
      _storeAvailable = await _store.isAvailable();
      if (!_storeAvailable) {
        _errorMessage = '현재 기기에서 스토어 결제를 사용할 수 없어요.';
        return;
      }
      final response = await _store.queryProductDetails({
        premiumMonthlySubscriptionId,
      });
      if (response.error != null) {
        _errorMessage = '구독 상품 정보를 불러오지 못했어요.';
      } else if (response.productDetails.isEmpty) {
        _errorMessage = '스토어에서 월간 구독 상품을 찾지 못했어요.';
      } else {
        _product = response.productDetails.first;
      }
      // 스토어가 응답했을 때만 권한을 다시 판정한다. 실패하면 catch 로 빠져
      // 캐시된 권한(오프라인 유예)이 그대로 유지된다.
      await _sweepRestoredPurchases();
    } catch (_) {
      _errorMessage = '구독 정보를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> purchase() async {
    final product = _product;
    if (product == null || !_storeAvailable || _purchasePending) {
      _errorMessage ??= '구독 상품을 아직 구매할 수 없어요.';
      notifyListeners();
      return;
    }
    _purchasePending = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
    try {
      await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          // 서버가 영수증의 주인을 확인할 수 있도록 계정 식별자를 심는다.
          applicationUserName: accountToken,
        ),
      );
    } catch (_) {
      _purchasePending = false;
      _errorMessage = '구매를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (_purchasePending) return;
    if (!_storeAvailable) {
      // 버튼만 눌리고 아무 반응이 없으면 사용자는 고장으로 받아들인다.
      _errorMessage = '현재 기기에서 스토어 결제를 사용할 수 없어요.';
      _statusMessage = null;
      notifyListeners();
      return;
    }
    _purchasePending = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
    try {
      final found = await _sweepRestoredPurchases();
      _statusMessage = found
          ? '구독을 복원했어요. 이제 모든 학습 콘텐츠를 이용할 수 있어요.'
          : '복원할 구매 내역이 없어요. 구독할 때 사용한 스토어 계정인지 확인해 주세요.';
    } catch (_) {
      _errorMessage = '구매 내역을 복원하지 못했어요. 인터넷 연결을 확인해 주세요.';
    } finally {
      _purchasePending = false;
      notifyListeners();
    }
  }

  /// 복원을 요청하고 [restoreSettleDelay] 동안 들어온 결과로 구독 권한을
  /// 다시 판정한다. 스토어가 아무 것도 돌려주지 않으면 해지·만료로 보고
  /// 캐시된 권한까지 함께 지운다.
  ///
  /// 서버를 쓰는 경우에는 여기서 권한을 정하지 않는다. 복원된 영수증을 서버로
  /// 넘기기만 하고, 판정 결과는 [watchEntitlement] 로 돌아온다.
  Future<bool> _sweepRestoredPurchases() async {
    _restoreSweepFoundSubscription = false;
    _restoreSweepActive = true;
    try {
      await _store.restorePurchases();
      await Future<void>.delayed(restoreSettleDelay);
    } finally {
      _restoreSweepActive = false;
    }
    final found = _restoreSweepFoundSubscription;
    if (backend == null) _setEntitlement(found);
    return found;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var foundSubscription = false;
    var sawOurProduct = false;
    var sawPending = false;
    PurchaseDetails? toVerify;
    for (final purchase in purchases) {
      if (purchase.productID != premiumMonthlySubscriptionId) continue;
      sawOurProduct = true;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          foundSubscription = true;
          toVerify = purchase;
        case PurchaseStatus.pending:
          sawPending = true;
        case PurchaseStatus.error:
          _errorMessage = purchase.error?.message ?? '결제를 완료하지 못했어요.';
        case PurchaseStatus.canceled:
          _errorMessage = null;
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
    if (foundSubscription) {
      _restoreSweepFoundSubscription = true;
      // 서버가 있으면 앱이 스스로 권한을 켜지 않는다. 영수증을 넘겨 확인받고,
      // 결과는 서버 기록을 지켜보는 쪽에서 반영된다.
      if (backend == null) {
        _setEntitlement(true);
      } else if (toVerify != null) {
        await _verifyWithBackend(toVerify);
      }
    }
    // 보류 결제(계좌이체·보호자 승인)는 결과가 올 때까지 진행 중으로 두어야
    // 구독 버튼이 다시 눌려 중복 결제가 시도되지 않는다.
    if (!_restoreSweepActive && sawOurProduct) {
      _purchasePending = sawPending && !foundSubscription;
    }
    notifyListeners();
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    final backend = this.backend;
    if (backend == null) return;
    final platform = switch (purchase.verificationData.source) {
      'google_play' => 'android',
      'app_store' => 'ios',
      _ => null,
    };
    if (platform == null) return;
    try {
      final entitlement = await backend.verifyPurchase(
        platform: platform,
        productId: premiumMonthlySubscriptionId,
        receipt: purchase.verificationData.serverVerificationData,
      );
      _applyEntitlement(entitlement);
    } catch (_) {
      // 검증에 실패해도 이미 가진 권한을 뺏지는 않는다. 서버 기록을 지켜보는
      // 쪽에서 다음 결과가 오면 그때 맞춰진다.
      _errorMessage = '결제 확인이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  void _applyEntitlement(Entitlement entitlement) {
    _setEntitlement(entitlement.grantsAccess);
    notifyListeners();
  }

  void _setEntitlement(bool value) {
    _isSubscribed = value;
    final preferences = this.preferences;
    if (preferences == null) return;
    preferences.setBool(_subscribedPrefKey, value);
    preferences.setInt(
      _verifiedAtPrefKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _loadCachedEntitlement() {
    final preferences = this.preferences;
    if (preferences == null) return;
    if (!(preferences.getBool(_subscribedPrefKey) ?? false)) return;
    final verifiedAt = preferences.getInt(_verifiedAtPrefKey);
    if (verifiedAt == null) return;
    final since = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(verifiedAt),
    );
    if (since >= Duration.zero && since <= offlineGrace) _isSubscribed = true;
  }

  @override
  void dispose() {
    _entitlementSubscription?.cancel();
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
