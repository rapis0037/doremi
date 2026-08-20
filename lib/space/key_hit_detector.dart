import 'dart:ui';

/// 무엇이 keyDown을 만들었는지. 어느 방식을 남길지 정하려고 세어 둔다.
enum HitTrigger { gesture, dwell }

class KeyDownEvent {
  const KeyDownEvent(this.keyIndex, this.trigger);
  final int keyIndex;
  final HitTrigger trigger;
}

class KeyUpEvent {
  const KeyUpEvent(this.keyIndex);
  final int keyIndex;
}

/// 판정 파라미터. 전부 미검증 초기값이며 실기기에서 튜닝한 뒤 되써넣는다.
class HitConfig {
  const HitConfig({
    this.keyCount = 4,
    this.rangeStart = 0.08,
    this.rangeEnd = 0.92,
    this.boundarySlack = 0.10,
    this.dwellMs = 300,
    this.dwellMaxSpeed = 0.15,
    this.descentWindowMs = 200,
    this.descentSpanRatio = 0.20,
    this.descentSpeed = 0.25,
    this.releaseSpanRatio = 0.12,
    this.cooldownMs = 150,
    this.minConfidence = 0.5,
    this.smoothing = 3,
    this.lostFrames = 5,
    this.burstLimit = 8,
    this.burstWindowMs = 3000,
  });

  /// 건반 칸 수와 좌우 가동 범위. 캘리브레이션이 rangeStart/End를 덮어쓴다.
  final int keyCount;
  final double rangeStart;
  final double rangeEnd;

  /// 칸 경계 히스테리시스. 칸 폭에 대한 비율.
  final double boundarySlack;

  /// 체류 경로 — 같은 칸에 이만큼 머물면 발음.
  final int dwellMs;

  /// 「머무름」은 가만히 있는 것이지 지나가는 것이 아니다. 좌우 속도가
  /// 초당 이 비율을 넘으면 체류 시간을 다시 센다. 이게 없으면 칸을 훑고
  /// 지나가는 동작이 중간 칸을 울린다.
  final double dwellMaxSpeed;

  /// 하강 제스처 — 이 시간 안에 손 크기의 [descentSpanRatio]만큼 내려가고,
  /// 초당 [descentSpeed](프레임 높이 비율) 이상이어야 누름으로 본다.
  /// 창은 평활 지연(3프레임 ≈ 180ms)보다 넉넉해야 한다.
  final int descentWindowMs;
  final double descentSpanRatio;
  final double descentSpeed;

  /// 누른 뒤 손가락이 이만큼 올라오면 해제로 보고 재입력을 허용한다.
  final double releaseSpanRatio;

  final int cooldownMs;
  final double minConfidence;
  final int smoothing;
  final int lostFrames;

  /// 짧은 시간에 이 횟수를 넘기면 잠시 발음을 멈춘다.
  /// 반복 동작이 소리를 연달아 내고 그 소리가 다시 자극이 되는 것을 막는다.
  final int burstLimit;
  final int burstWindowMs;

  HitConfig copyWith({
    double? rangeStart,
    double? rangeEnd,
    int? dwellMs,
    double? descentSpanRatio,
    double? descentSpeed,
  }) => HitConfig(
    keyCount: keyCount,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
    boundarySlack: boundarySlack,
    dwellMs: dwellMs ?? this.dwellMs,
    dwellMaxSpeed: dwellMaxSpeed,
    descentWindowMs: descentWindowMs,
    descentSpanRatio: descentSpanRatio ?? this.descentSpanRatio,
    descentSpeed: descentSpeed ?? this.descentSpeed,
    releaseSpanRatio: releaseSpanRatio,
    cooldownMs: cooldownMs,
    minConfidence: minConfidence,
    smoothing: smoothing,
    lostFrames: lostFrames,
    burstLimit: burstLimit,
    burstWindowMs: burstWindowMs,
  );
}

class HitResult {
  const HitResult({
    this.cursor,
    this.activeKey,
    this.down,
    this.up,
    this.suppressed = false,
  });

  /// 평활을 거친 커서 위치. 손을 못 찾으면 null.
  final Offset? cursor;

  /// 커서가 올라가 있는 칸. 범위 밖이면 null.
  final int? activeKey;

  final KeyDownEvent? down;
  final KeyUpEvent? up;

  /// 연속 발음 상한에 걸려 소리를 참은 프레임.
  final bool suppressed;
}

class _Sample {
  const _Sample(this.y, this.timeMs);
  final double y;
  final int timeMs;
}

/// 좌우 위치로 칸을 고르고, 하강 제스처 또는 체류로 누름을 판정한다.
///
/// 카메라가 손을 거의 수평으로 보므로 손을 앞으로 미는 것과 손가락을 드는 것이
/// 화면상 둘 다 「위로」가 되어 구분되지 않는다. 그래서 축의 역할을 나눈다 —
/// 좌우는 어느 칸인지만, 상하는 눌렀는지만 본다.
///
/// 카메라도 Flutter도 모르는 순수 로직이다. 단위 테스트는 여기에 건다.
class KeyHitDetector {
  KeyHitDetector([this._config = const HitConfig()]);

  HitConfig _config;
  HitConfig get config => _config;
  set config(HitConfig value) {
    _config = value;
    reset();
  }

  final _recent = <Offset>[];
  final _vertical = <_Sample>[];
  final _downTimes = <int>[];
  final _lastDownAt = <int, int>{};

  int? _activeKey;
  int? _enteredAt;
  bool _pressed = false;
  double _pressY = 0;
  int _missCount = 0;
  Offset? _lastPoint;
  int _lastPointAt = 0;

  void reset() {
    _recent.clear();
    _vertical.clear();
    _downTimes.clear();
    _lastDownAt.clear();
    _activeKey = null;
    _enteredAt = null;
    _pressed = false;
    _missCount = 0;
    _lastPoint = null;
  }

  /// 손을 못 찾은 프레임. 연속 [HitConfig.lostFrames]를 넘으면 눌린 칸을 놓는다.
  HitResult miss(int timeMs) {
    _missCount++;
    if (_missCount < _config.lostFrames) {
      return HitResult(cursor: _smoothed, activeKey: _activeKey);
    }
    final released = _pressed ? _activeKey : null;
    _recent.clear();
    _vertical.clear();
    _activeKey = null;
    _enteredAt = null;
    _pressed = false;
    return HitResult(up: released == null ? null : KeyUpEvent(released));
  }

  HitResult update({
    required Offset fingertip,
    required double span,
    required double confidence,
    required int timeMs,
  }) {
    if (confidence < _config.minConfidence) return miss(timeMs);
    _missCount = 0;

    _recent.add(fingertip);
    while (_recent.length > _config.smoothing) {
      _recent.removeAt(0);
    }
    final point = _smoothed!;

    _vertical.add(_Sample(point.dy, timeMs));
    while (_vertical.isNotEmpty &&
        timeMs - _vertical.first.timeMs > _config.descentWindowMs * 3) {
      _vertical.removeAt(0);
    }

    // 「머무름」은 가만히 있는 것이다. 훑고 지나가는 중이면 체류를 다시 센다.
    final previous = _lastPoint;
    final movedFast =
        previous != null &&
        timeMs > _lastPointAt &&
        (point.dx - previous.dx).abs() / ((timeMs - _lastPointAt) / 1000) >
            _config.dwellMaxSpeed;
    _lastPoint = point;
    _lastPointAt = timeMs;

    final key = _keyAt(point.dx);
    KeyUpEvent? up;

    if (key != _activeKey) {
      if (_pressed && _activeKey != null) up = KeyUpEvent(_activeKey!);
      _activeKey = key;
      _enteredAt = key == null ? null : timeMs;
      _pressed = false;
    }

    if (key == null) {
      return HitResult(cursor: point, activeKey: null, up: up);
    }
    if (movedFast) _enteredAt = timeMs;

    // 누른 상태에서 손가락이 올라오면 해제하고 재입력을 허용한다.
    if (_pressed) {
      if (_pressY - point.dy >= span * _config.releaseSpanRatio) {
        _pressed = false;
        _enteredAt = timeMs;
        up ??= KeyUpEvent(key);
      }
      return HitResult(cursor: point, activeKey: key, up: up);
    }

    final trigger = _triggerAt(point, span, timeMs);
    if (trigger == null) {
      return HitResult(cursor: point, activeKey: key, up: up);
    }

    final last = _lastDownAt[key];
    if (last != null && timeMs - last < _config.cooldownMs) {
      return HitResult(cursor: point, activeKey: key, up: up);
    }

    _downTimes.removeWhere((t) => timeMs - t > _config.burstWindowMs);
    if (_downTimes.length >= _config.burstLimit) {
      return HitResult(cursor: point, activeKey: key, up: up, suppressed: true);
    }

    _pressed = true;
    _pressY = point.dy;
    _lastDownAt[key] = timeMs;
    _downTimes.add(timeMs);
    return HitResult(
      cursor: point,
      activeKey: key,
      up: up,
      down: KeyDownEvent(key, trigger),
    );
  }

  Offset? get _smoothed {
    if (_recent.isEmpty) return null;
    var x = 0.0;
    var y = 0.0;
    for (final p in _recent) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / _recent.length, y / _recent.length);
  }

  HitTrigger? _triggerAt(Offset point, double span, int timeMs) {
    if (span > 0 && _descended(point.dy, span, timeMs)) return HitTrigger.gesture;
    final entered = _enteredAt;
    if (entered != null && timeMs - entered >= _config.dwellMs) {
      return HitTrigger.dwell;
    }
    return null;
  }

  /// 창 안에서 가장 높았던 지점 대비 얼마나 내려왔는지 본다.
  /// 손 크기 기준이라 아이 손 크기와 카메라 거리에 자동으로 맞춰진다.
  bool _descended(double y, double span, int timeMs) {
    double? topY;
    int? topAt;
    for (final sample in _vertical) {
      if (timeMs - sample.timeMs > _config.descentWindowMs) continue;
      if (topY == null || sample.y < topY) {
        topY = sample.y;
        topAt = sample.timeMs;
      }
    }
    if (topY == null || topAt == null) return false;

    final drop = y - topY;
    if (drop < span * _config.descentSpanRatio) return false;

    final elapsed = timeMs - topAt;
    if (elapsed <= 0) return false;
    final speed = drop / (elapsed / 1000);
    return speed >= _config.descentSpeed;
  }

  /// 좌우 위치만으로 칸을 고른다. 상하는 쓰지 않는다.
  int? _keyAt(double x) {
    final width = _config.rangeEnd - _config.rangeStart;
    if (width <= 0) return null;
    final keyWidth = width / _config.keyCount;
    final slack = keyWidth * _config.boundarySlack;

    // 이미 들어가 있는 칸은 여유를 줘서 경계에서 깜빡이지 않게 한다.
    final current = _activeKey;
    if (current != null) {
      final start = _config.rangeStart + keyWidth * current - slack;
      final end = start + keyWidth + slack * 2;
      if (x >= start && x < end) return current;
    }

    if (x < _config.rangeStart || x >= _config.rangeEnd) return null;
    final index = ((x - _config.rangeStart) / keyWidth).floor();
    return index.clamp(0, _config.keyCount - 1);
  }

  /// 칸 [index]의 좌우 경계. 화면에 건반을 그릴 때 쓴다.
  (double, double) bounds(int index) {
    final keyWidth = (_config.rangeEnd - _config.rangeStart) / _config.keyCount;
    final start = _config.rangeStart + keyWidth * index;
    return (start, start + keyWidth);
  }
}
