import 'dart:typed_data';
import 'dart:ui';

/// 한 프레임에서 얻은 손. 좌표는 회전·반전이 적용된 뒤의 정규화 좌표(0~1)다.
class HandSample {
  const HandSample({
    required this.landmarks,
    required this.span,
    required this.confidence,
  });

  /// 21개 랜드마크. MediaPipe 인덱스를 그대로 따른다 (8 = 검지 끝).
  final List<Offset> landmarks;

  /// 손목(0)과 중지 밑동(9) 사이 거리를 프레임 긴 변으로 나눈 값.
  /// 아이가 앞뒤로 움직인 것을 감지해 배율을 보정하는 데 쓴다.
  final double span;

  final double confidence;

  /// 검지 끝. 판정은 이 점 하나만 쓴다 — 손 전체를 쓰면 손바닥이
  /// 여러 칸에 걸쳐 오발음이 급증한다.
  Offset get fingertip => landmarks[8];
}

/// 카메라 프레임을 받아 손 랜드마크를 돌려주는 것만 하는 계층.
///
/// 어느 건반인지, 눌렀는지는 여기서 판단하지 않는다. 그 규칙은
/// [KeyHitDetector] 한 곳에 있어야 Android와 iOS가 갈라지지 않는다.
abstract interface class HandTrackerAdapter {
  Future<void> initialize();

  /// 손을 못 찾으면 null. 앞 프레임이 아직 도는 중이어도 null이다.
  Future<HandSample?> detect({
    required Uint8List nv21,
    required int width,
    required int height,
    required int rotationDegrees,
    required bool mirror,
    required int timestampMs,
  });

  Future<void> dispose();
}
