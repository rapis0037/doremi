import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'entitlement.dart';

/// 구독 권한을 판정하는 주체. 앱은 결과만 받아 쓴다.
abstract class SubscriptionBackend {
  /// 서버에 기록된 권한을 계속 지켜본다. 갱신·해지가 그대로 흘러 들어온다.
  Stream<Entitlement> watchEntitlement();

  /// 스토어에서 받은 영수증을 서버에 넘겨 확인시킨다.
  Future<Entitlement> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  });
}

class FirebaseSubscriptionBackend implements SubscriptionBackend {
  FirebaseSubscriptionBackend({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: _region);

  /// 함수 배포 지역. functions/src/index.ts 의 REGION 과 같아야 한다.
  static const _region = 'asia-northeast3';

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<Entitlement> watchEntitlement() => _firestore
      .collection('subscriptions')
      .doc(uid)
      .snapshots()
      .map((snapshot) => Entitlement.fromMap(snapshot.data()));

  @override
  Future<Entitlement> verifyPurchase({
    required String platform,
    required String productId,
    required String receipt,
  }) async {
    final result = await _functions.httpsCallable('verifyPurchase').call({
      'platform': platform,
      'productId': productId,
      'receipt': receipt,
    });
    final data = result.data;
    return Entitlement.fromMap(
      data is Map ? Map<String, dynamic>.from(data) : null,
    );
  }
}
