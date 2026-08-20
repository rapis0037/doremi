import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 서버가 스토어에 확인해 내려 준 구독 상태.
enum EntitlementStatus {
  active,
  grace,
  onHold,
  paused,
  expired;

  static EntitlementStatus parse(String? value) => switch (value) {
    'active' => EntitlementStatus.active,
    'grace' => EntitlementStatus.grace,
    'onHold' => EntitlementStatus.onHold,
    'paused' => EntitlementStatus.paused,
    _ => EntitlementStatus.expired,
  };
}

class Entitlement {
  const Entitlement({required this.status, this.expiresAt});

  /// 아직 서버 기록이 없거나 만료된 상태.
  static const none = Entitlement(status: EntitlementStatus.expired);

  final EntitlementStatus status;
  final DateTime? expiresAt;

  /// 결제 유예 기간에도 학습은 계속할 수 있어야 한다.
  bool get grantsAccess =>
      status == EntitlementStatus.active || status == EntitlementStatus.grace;

  factory Entitlement.fromMap(Map<String, dynamic>? data) {
    if (data == null) return none;
    final expiresAt = data['expiresAt'];
    return Entitlement(
      status: EntitlementStatus.parse(data['status'] as String?),
      expiresAt: expiresAt is int
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt)
          : null,
    );
  }
}

/// uid 로부터 항상 같은 UUID 를 만든다. 결제할 때 스토어에 심어 두면
/// (Android obfuscatedAccountId / iOS appAccountToken) 서버가 같은 계산을
/// 다시 해 영수증의 주인을 확인할 수 있다.
///
/// functions/src/entitlement.ts 의 accountTokenFor 와 계산이 같아야 한다.
String accountTokenFor(String uid) {
  final digest = sha256.convert(utf8.encode('doremi:$uid')).bytes;
  final bytes = List<int>.from(digest.sublist(0, 16));
  // RFC 4122 버전 5(이름 기반), variant 10xx.
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
