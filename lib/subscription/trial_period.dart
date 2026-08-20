/// 체험 시작일은 기기에 처음 앱을 켠 날과 계정 생성일 중 더 이른 쪽으로
/// 잡는다. 탈퇴 뒤 다시 가입해 새 계정을 만들어도 같은 기기에서는 체험이
/// 다시 시작되지 않는다.
DateTime earliestTrialStart(
  DateTime deviceFirstSeenAt,
  DateTime? accountCreatedAt,
) {
  if (accountCreatedAt == null) return deviceFirstSeenAt;
  return accountCreatedAt.isBefore(deviceFirstSeenAt)
      ? accountCreatedAt
      : deviceFirstSeenAt;
}

class TrialPeriod {
  const TrialPeriod({
    required this.startedAt,
    this.duration = const Duration(days: 14),
  });

  final DateTime startedAt;
  final Duration duration;

  DateTime get endsAt => startedAt.add(duration);

  bool isActiveAt(DateTime now) => now.isBefore(endsAt);

  int remainingDaysAt(DateTime now) {
    if (!isActiveAt(now)) return 0;
    final remaining = endsAt.difference(now);
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }
}
