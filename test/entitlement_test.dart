import 'package:doremi/subscription/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('활성 상태여도 만료 시각이 지났으면 접근을 허용하지 않는다', () {
    final entitlement = Entitlement(
      status: EntitlementStatus.active,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(entitlement.grantsAccess, isFalse);
  });

  test('유예 상태이고 만료 시각이 남았으면 접근을 허용한다', () {
    final entitlement = Entitlement(
      status: EntitlementStatus.grace,
      expiresAt: DateTime.now().add(const Duration(minutes: 1)),
    );

    expect(entitlement.grantsAccess, isTrue);
  });
}
