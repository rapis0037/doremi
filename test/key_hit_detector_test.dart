import 'package:doremi/space/key_hit_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// 판정 규칙 회귀 테스트. 파라미터를 고칠 때 이 벡터도 함께 갱신한다.
/// 표만 고치고 벡터를 두면 여기서 실패해야 한다.
void main() {
  const config = HitConfig();

  /// 칸 [index]의 가운데 x. 칸은 좌우 위치로만 고른다.
  double centerOf(int index) {
    final width = (config.rangeEnd - config.rangeStart) / 4;
    return config.rangeStart + width * index + width / 2;
  }

  /// 한 프레임 먹인다. span은 손 크기 기준 판정을 위해 고정값을 쓴다.
  HitResult feed(
    KeyHitDetector detector, {
    required double x,
    required double y,
    required int t,
    double span = 0.20,
    double confidence = 0.9,
  }) => detector.update(
    fingertip: Offset(x, y),
    span: span,
    confidence: confidence,
    timeMs: t,
  );

  /// 평활이 3프레임 이동평균이라 같은 지점을 몇 번 먹여 안정시킨다.
  void settle(KeyHitDetector detector, double x, double y, int from) {
    for (var i = 0; i < 4; i++) {
      feed(detector, x: x, y: y, t: from + i * 40);
    }
  }

  /// 손가락을 내리는 동작. 실제로는 여러 프레임에 걸쳐 일어난다 —
  /// 한 프레임만 먹이면 평활이 삼켜 버려서 실기기와 다른 결과가 나온다.
  HitResult descend(KeyHitDetector detector, double x, double fromY, int at) {
    var last = const HitResult();
    for (var i = 1; i <= 3; i++) {
      last = feed(detector, x: x, y: fromY + 0.05 * i, t: at + i * 40);
      if (last.down != null) return last;
    }
    return last;
  }

  group('칸 선택', () {
    test('좌우 위치로 네 칸을 고르고, 상하는 선택에 쓰지 않는다', () {
      final detector = KeyHitDetector();
      for (var key = 0; key < 4; key++) {
        detector.reset();
        // 세로 위치를 크게 바꿔도 고르는 칸은 같아야 한다.
        settle(detector, centerOf(key), 0.2, 0);
        expect(detector.update(
          fingertip: Offset(centerOf(key), 0.8),
          span: 0.2,
          confidence: 0.9,
          timeMs: 200,
        ).activeKey, key);
      }
    });

    test('가동 범위 밖이면 어느 칸도 아니다', () {
      final detector = KeyHitDetector();
      final result = feed(detector, x: 0.01, y: 0.5, t: 0);
      expect(result.activeKey, isNull);
    });

    test('신뢰도가 하한 미만이면 판정하지 않는다', () {
      final detector = KeyHitDetector();
      final result = feed(detector, x: centerOf(1), y: 0.5, t: 0, confidence: 0.2);
      expect(result.down, isNull);
      expect(result.activeKey, isNull);
    });
  });

  group('누름', () {
    test('칸 위에서 손가락을 내리면 제스처로 한 번 울린다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(2), 0.30, 0);
      final result = descend(detector, centerOf(2), 0.30, 160);
      expect(result.down?.keyIndex, 2);
      expect(result.down?.trigger, HitTrigger.gesture);
    });

    test('칸 위에 머물면 체류로 울린다', () {
      final detector = KeyHitDetector();
      var last = HitResult();
      for (var t = 0; t <= config.dwellMs + 120; t += 60) {
        last = feed(detector, x: centerOf(0), y: 0.5, t: t);
        if (last.down != null) break;
      }
      expect(last.down?.keyIndex, 0);
      expect(last.down?.trigger, HitTrigger.dwell);
    });

    test('누른 채로는 다시 울리지 않는다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(1), 0.30, 0);
      final first = descend(detector, centerOf(1), 0.30, 160);
      expect(first.down, isNotNull);

      for (var t = 400; t <= 1200; t += 40) {
        expect(feed(detector, x: centerOf(1), y: 0.45, t: t).down, isNull);
      }
    });

    test('손가락을 올렸다 다시 내리면 다시 울린다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(1), 0.30, 0);
      expect(descend(detector, centerOf(1), 0.30, 160).down, isNotNull);

      // 올린다 — 해제
      settle(detector, centerOf(1), 0.28, 400);
      // 다시 내린다 — 쿨다운을 넘긴 시점
      expect(descend(detector, centerOf(1), 0.28, 700).down, isNotNull);
    });
  });

  group('오발음 방지', () {
    test('칸 사이를 가로로 지나가도 중간 칸이 울리지 않는다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(0), 0.5, 0);
      // 체류 시간보다 빠르게, 세로 움직임 없이 훑는다.
      var fired = 0;
      for (var step = 0; step <= 20; step++) {
        final x = centerOf(0) + (centerOf(3) - centerOf(0)) * step / 20;
        final result = feed(detector, x: x, y: 0.5, t: 120 + step * 40);
        if (result.down != null) fired++;
      }
      expect(fired, 0);
    });

    test('손 전체가 앞으로 밀려도 하강으로 오인하지 않는다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(2), 0.50, 0);
      // 손이 멀어지면 span이 줄고 손끝은 위로 간다 — 하강이 아니다.
      var fired = 0;
      for (var step = 1; step <= 5; step++) {
        final result = feed(
          detector,
          x: centerOf(2),
          y: 0.50 - step * 0.02,
          t: 120 + step * 40,
          span: 0.20 - step * 0.01,
        );
        if (result.down?.trigger == HitTrigger.gesture) fired++;
      }
      expect(fired, 0);
    });

    test('짧은 시간에 너무 많이 울리면 참는다', () {
      final detector = KeyHitDetector(const HitConfig(burstLimit: 3));
      var downs = 0;
      var suppressed = 0;
      var t = 0;
      for (var round = 0; round < 8; round++) {
        final key = round % 4;
        settle(detector, centerOf(key), 0.30, t);
        t += 160;
        final result = feed(detector, x: centerOf(key), y: 0.42, t: t);
        if (result.down != null) downs++;
        if (result.suppressed) suppressed++;
        t += 60;
      }
      expect(downs, lessThanOrEqualTo(3));
      expect(suppressed, greaterThan(0));
    });
  });

  group('추적 손실', () {
    test('연속으로 못 찾으면 눌린 칸을 놓는다', () {
      final detector = KeyHitDetector();
      settle(detector, centerOf(3), 0.30, 0);
      expect(descend(detector, centerOf(3), 0.30, 160).down, isNotNull);

      HitResult? release;
      for (var i = 0; i < config.lostFrames; i++) {
        final result = detector.miss(400 + i * 40);
        if (result.up != null) release = result;
      }
      expect(release?.up?.keyIndex, 3);
    });
  });
}
