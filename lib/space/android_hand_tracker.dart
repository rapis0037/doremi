import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'hand_tracker_adapter.dart';

/// MediaPipe Hand Landmarker를 감싼 구현. 채널 너머는 MainActivity가 받는다.
class AndroidHandTracker implements HandTrackerAdapter {
  static const _channel = MethodChannel('doremi/hand_tracking');

  @override
  Future<void> initialize() => _channel.invokeMethod<bool>('initialize');

  @override
  Future<HandSample?> detect({
    required Uint8List nv21,
    required int width,
    required int height,
    required int rotationDegrees,
    required bool mirror,
    required int timestampMs,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('detect', {
      'bytes': nv21,
      'width': width,
      'height': height,
      'rotation': rotationDegrees,
      'mirror': mirror,
      'timestampMs': timestampMs,
    });
    if (raw == null) return null;

    final flat = (raw['landmarks'] as Float32List?) ?? Float32List(0);
    if (flat.length < 42) return null;

    return HandSample(
      landmarks: [
        for (var i = 0; i < 21; i++) Offset(flat[i * 2], flat[i * 2 + 1]),
      ],
      span: (raw['span'] as num?)?.toDouble() ?? 0,
      confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');
}
