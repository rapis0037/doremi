import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio/tone_player.dart';
import '../core/constants.dart';
import 'android_hand_tracker.dart';
import 'hand_tracker_adapter.dart';
import 'key_hit_detector.dart';

enum SpaceStatus { initializing, permissionDenied, noCamera, ready, error }

/// 카메라와 손 추적기와 판정기를 잇는다.
///
/// 판정은 [KeyHitDetector]가 하고 여기서는 프레임 흐름만 관리한다. 프레임이
/// 밀리면 지연이 쌓이므로 앞 프레임이 도는 중이면 새 프레임을 버린다.
class SpaceController extends ChangeNotifier {
  SpaceController({HandTrackerAdapter? tracker, TonePlayer? tonePlayer})
    : _tracker = tracker ?? AndroidHandTracker(),
      _tone = tonePlayer ?? TonePlayer(),
      _ownsTone = tonePlayer == null;

  final HandTrackerAdapter _tracker;
  final TonePlayer _tone;
  final bool _ownsTone;

  final detector = KeyHitDetector();

  SpaceStatus status = SpaceStatus.initializing;
  String? errorMessage;
  CameraController? camera;

  Offset? cursor;
  int? activeKey;
  int? flashKey;
  bool suppressed = false;

  /// 회전은 기기 방향에서 계산한다. 상수로 박으면 기기마다 다르고, 태블릿을
  /// 거치대에서 뒤집으면 또 틀어진다. 자동이 틀릴 때만 디버그에서 고정한다.
  bool autoRotation = true;
  int _manualRotation = 0;
  bool mirror = true;
  bool showCamera = true;
  bool showSkeleton = true;

  List<Offset> landmarks = const [];
  double span = 0;
  double confidence = 0;

  /// 마지막으로 처리한 카메라 프레임 크기. 회전 전 기준이다.
  int frameWidth = 0;
  int frameHeight = 0;
  int detectMs = 0;
  int fps = 0;
  int gestureHits = 0;
  int dwellHits = 0;

  int _framesInSecond = 0;
  int _secondStartedAt = 0;
  bool _busy = false;
  int _lastSentAt = 0;
  bool _closed = false;

  /// 약 16fps. 프레임이 Dart를 거치는 왕복 비용을 감안한 값이다.
  static const _minIntervalMs = 60;

  Future<void> start() async {
    final granted = await Permission.camera.request();
    if (!granted.isGranted) {
      _fail(SpaceStatus.permissionDenied, '카메라 권한이 필요해요');
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.cast<CameraDescription?>().firstWhere(
        (item) => item?.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.isEmpty ? null : cameras.first,
      );
      if (front == null) {
        _fail(SpaceStatus.noCamera, '카메라를 찾지 못했어요');
        return;
      }

      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (_closed) {
        await controller.dispose();
        return;
      }
      camera = controller;
      // 기기를 돌리면 deviceOrientation이 바뀌고 계산된 회전도 따라 바뀐다.
      controller.addListener(_notify);

      await _tracker.initialize();
      await _tone.preload();

      await controller.startImageStream(_onFrame);
      status = SpaceStatus.ready;
      _notify();
    } catch (e) {
      _fail(SpaceStatus.error, '$e');
    }
  }

  void _fail(SpaceStatus next, String message) {
    status = next;
    errorMessage = message;
    _notify();
  }

  void _onFrame(CameraImage image) {
    if (_closed || _busy) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSentAt < _minIntervalMs) return;
    _lastSentAt = now;
    _busy = true;
    _process(image, now);
  }

  Future<void> _process(CameraImage image, int now) async {
    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      frameWidth = image.width;
      frameHeight = image.height;
      final nv21 = _toNv21(image);
      final sample = await _tracker.detect(
        nv21: nv21,
        width: image.width,
        height: image.height,
        rotationDegrees: rotationDegrees,
        mirror: mirror,
        timestampMs: now,
      );
      if (_closed) return;

      detectMs = DateTime.now().millisecondsSinceEpoch - started;
      _countFrame(now);

      final result = sample == null
          ? detector.miss(now)
          : detector.update(
              fingertip: sample.fingertip,
              span: sample.span,
              confidence: sample.confidence,
              timeMs: now,
            );

      landmarks = sample?.landmarks ?? const [];
      span = sample?.span ?? 0;
      confidence = sample?.confidence ?? 0;
      cursor = result.cursor;
      activeKey = result.activeKey;
      suppressed = result.suppressed;

      final down = result.down;
      if (down != null) {
        if (down.trigger == HitTrigger.gesture) {
          gestureHits++;
        } else {
          dwellHits++;
        }
        flashKey = down.keyIndex;
        unawaited(_tone.playNote(notes[down.keyIndex]));
      } else if (result.up != null) {
        flashKey = null;
      }
      _notify();
    } catch (_) {
      // 한 프레임 실패는 넘긴다. 다음 프레임에서 회복된다.
    } finally {
      _busy = false;
    }
  }

  void _countFrame(int now) {
    _framesInSecond++;
    if (now - _secondStartedAt >= 1000) {
      fps = _framesInSecond;
      _framesInSecond = 0;
      _secondStartedAt = now;
    }
  }

  /// CameraImage(YUV420_888) → NV21. Y 평면 뒤에 V,U를 번갈아 붙인다.
  Uint8List _toNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final out = Uint8List(ySize + ySize ~/ 2);

    final yPlane = image.planes[0];
    var index = 0;
    for (var row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      out.setRange(index, index + width, yPlane.bytes, start);
      index += width;
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final rowStride = uPlane.bytesPerRow;
    final pixelStride = uPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final offset = row * rowStride + col * pixelStride;
        if (offset >= vPlane.bytes.length || offset >= uPlane.bytes.length) {
          continue;
        }
        out[index++] = vPlane.bytes[offset];
        out[index++] = uPlane.bytes[offset];
      }
    }
    return out;
  }

  /// 회전이 적용된 뒤의 이미지 크기. 랜드마크 정규화 좌표의 기준 공간이며
  /// 미리보기도 같은 공간에 올려야 뼈대가 손에 겹친다.
  Size get orientedSize {
    if (frameWidth == 0 || frameHeight == 0) return const Size(3, 4);
    final quarter = (rotationDegrees ~/ 90) % 2 == 1;
    return quarter
        ? Size(frameHeight.toDouble(), frameWidth.toDouble())
        : Size(frameWidth.toDouble(), frameHeight.toDouble());
  }

  /// 센서가 기기에 붙은 각도. 전면 카메라는 여기에 기기 방향을 더하고,
  /// 후면은 뺀다 — CameraX가 쓰는 것과 같은 식이다.
  int get rotationDegrees {
    if (!autoRotation) return _manualRotation;
    final controller = camera;
    if (controller == null) return 0;
    final sensor = controller.description.sensorOrientation;
    final device = _deviceDegrees(controller.value.deviceOrientation);
    return controller.description.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
  }

  int get sensorOrientation => camera?.description.sensorOrientation ?? 0;

  static int _deviceDegrees(DeviceOrientation orientation) =>
      switch (orientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeRight => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeLeft => 270,
      };

  /// 자동 → 0 → 90 → 180 → 270 → 자동 순으로 돈다.
  void cycleRotation() {
    if (autoRotation) {
      autoRotation = false;
      _manualRotation = 0;
    } else if (_manualRotation >= 270) {
      autoRotation = true;
    } else {
      _manualRotation += 90;
    }
    detector.reset();
    _notify();
  }

  void toggleMirror() {
    mirror = !mirror;
    detector.reset();
    _notify();
  }

  void toggleCamera() {
    showCamera = !showCamera;
    _notify();
  }

  void toggleSkeleton() {
    showSkeleton = !showSkeleton;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    final controller = camera;
    camera = null;
    try {
      if (controller != null) {
        controller.removeListener(_notify);
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await controller.dispose();
      }
    } catch (_) {}
    try {
      await _tracker.dispose();
    } catch (_) {}
    if (_ownsTone) {
      try {
        await _tone.dispose();
      } catch (_) {}
    }
    super.dispose();
  }
}
