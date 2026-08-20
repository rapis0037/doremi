import 'package:doremi/subscription/trial_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startedAt = DateTime.utc(2026, 8, 1, 12);
  final trial = TrialPeriod(startedAt: startedAt);

  test('계정 생성 후 정확히 14일 동안 무료 이용할 수 있다', () {
    expect(trial.isActiveAt(DateTime.utc(2026, 8, 15, 11, 59, 59)), isTrue);
    expect(trial.isActiveAt(DateTime.utc(2026, 8, 15, 12)), isFalse);
  });

  test('남은 기간은 사용자에게 일 단위로 올림해 표시한다', () {
    expect(trial.remainingDaysAt(startedAt), 14);
    expect(trial.remainingDaysAt(DateTime.utc(2026, 8, 14, 12, 1)), 1);
    expect(trial.remainingDaysAt(DateTime.utc(2026, 8, 15, 12)), 0);
  });

  group('체험 시작일', () {
    final deviceFirstSeen = DateTime.utc(2026, 8, 1);

    test('탈퇴 후 다시 가입해도 기기 첫 실행일부터 센다', () {
      final reJoined = DateTime.utc(2026, 8, 20);
      final start = earliestTrialStart(deviceFirstSeen, reJoined);
      expect(start, deviceFirstSeen);
      expect(TrialPeriod(startedAt: start).isActiveAt(reJoined), isFalse);
    });

    test('기기를 바꾼 기존 사용자는 계정 생성일을 그대로 쓴다', () {
      final joinedLongAgo = DateTime.utc(2026, 1, 1);
      expect(earliestTrialStart(deviceFirstSeen, joinedLongAgo), joinedLongAgo);
    });

    test('계정 생성일을 못 읽으면 기기 첫 실행일로 센다', () {
      expect(earliestTrialStart(deviceFirstSeen, null), deviceFirstSeen);
    });
  });
}
