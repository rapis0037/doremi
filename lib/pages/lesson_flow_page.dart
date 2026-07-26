import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio/tone_player.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../layout/keyboard_layout.dart';
import '../painters/lesson_painter.dart';
import '../widgets/scene_view.dart';
import '../widgets/stage_shell.dart';

/// 카메라 배경의 준비 상태. 실패 종류마다 사용자가 취할 수 있는 행동이 다르다.
enum _CameraStage {
  /// 권한 요청 중이거나 초기화 중.
  preparing,

  /// 프리뷰 사용 가능.
  ready,

  /// 거부됐지만 다시 물어볼 수 있다 (주로 Android).
  denied,

  /// 다시 물어볼 수 없다 — 설정에서 직접 켜야 한다 (주로 iOS).
  blocked,

  /// 카메라가 없거나 알 수 없는 이유로 열 수 없다.
  unavailable,
}

class LessonFlowPage extends StatefulWidget {
  const LessonFlowPage({
    super.key,
    required this.cameraMode,
    required this.soundOn,
    required this.onSoundChanged,
    required this.onExit,
  });
  final bool cameraMode;
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onExit;

  @override
  State<LessonFlowPage> createState() => _LessonFlowPageState();
}

class _LessonFlowPageState extends State<LessonFlowPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TonePlayer tone = TonePlayer();
  late final AnimationController flight;
  late final AnimationController burst;
  late final AnimationController popup;
  CameraController? camera;
  _CameraStage cameraStage = _CameraStage.preparing;
  bool cameraBusy = false;
  bool practiceWithoutCamera = false;
  NoteSpec? selected;
  Timer? popupTimer;
  bool landed = false;
  bool showPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    flight = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => landed = true);
          burst.forward(from: 0);
          popupTimer?.cancel();
          popupTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted || !landed) return;
            setState(() => showPopup = true);
            popup.forward(from: 0);
          });
        }
      });
    burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
    popup = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    if (widget.cameraMode) _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameraBusy) return;
    cameraBusy = true;
    if (mounted && cameraStage != _CameraStage.preparing) {
      setState(() => cameraStage = _CameraStage.preparing);
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => cameraStage = _CameraStage.unavailable);
        return;
      }
      final back = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        camera = controller;
        cameraStage = _CameraStage.ready;
      });
    } on CameraException catch (error) {
      final stage = await _stageForError(error);
      if (!mounted) return;
      setState(() => cameraStage = stage);
    } catch (_) {
      if (mounted) setState(() => cameraStage = _CameraStage.unavailable);
    } finally {
      cameraBusy = false;
    }
  }

  /// 오류 코드만으로는 '다시 물어볼 수 있는 거부'와 '설정에서만 켤 수 있는 거부'를 가릴 수 없다.
  /// Android 플러그인은 두 경우 모두 CameraAccessDenied 를 주고, iOS 는 첫 거부에만 그
  /// 코드를 준다(그 뒤로 iOS 는 다시 묻지 않는다). 그래서 실제 권한 상태를 확인한다.
  Future<_CameraStage> _stageForError(CameraException error) async {
    switch (error.code) {
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return _CameraStage.blocked;
      case 'CameraAccessDenied':
        try {
          // 요청이 한 번은 끝난 뒤에만 확인한다. Android 의 permanentlyDenied 판정은
          // shouldShowRequestPermissionRationale 기반이어서 '아직 안 물어본 상태'와
          // 구분되지 않으므로, 미리 조회하면 오판한다.
          final status = await Permission.camera.status;
          return status.isPermanentlyDenied ? _CameraStage.blocked : _CameraStage.denied;
        } catch (_) {
          // 상태를 못 읽으면 재요청이 가능한 쪽으로 둔다. 최악의 경우 한 번 더 눌러야 한다.
          return _CameraStage.denied;
        }
      default:
        return _CameraStage.unavailable;
    }
  }

  /// 프리뷰를 놓아준다. 다른 앱이 카메라를 쓸 수 있도록 백그라운드 진입 시 호출한다.
  void _releaseCamera() {
    final controller = camera;
    if (controller == null) return;
    // 폐기된 컨트롤러가 화면에 남지 않도록 먼저 트리에서 떼어낸 뒤 폐기한다.
    setState(() {
      camera = null;
      cameraStage = _CameraStage.preparing;
    });
    controller.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.cameraMode || practiceWithoutCamera) return;
    switch (state) {
      // 설정에서 권한을 켜고 돌아온 경우도 여기서 함께 회복된다.
      case AppLifecycleState.resumed:
        if (camera == null) _initializeCamera();
      // inactive는 알림 배너처럼 스쳐가는 상황에도 오므로 프리뷰를 유지한다.
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _releaseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    popupTimer?.cancel();
    flight.dispose();
    burst.dispose();
    popup.dispose();
    camera?.dispose();
    tone.dispose();
    super.dispose();
  }

  void _clearMotion() {
    popupTimer?.cancel();
    flight.reset();
    burst.reset();
    popup.reset();
    landed = false;
    showPopup = false;
  }

  void _choose(NoteSpec note) {
    _clearMotion();
    setState(() => selected = note);
  }

  void _goBack() {
    if (selected != null) {
      _clearMotion();
      setState(() => selected = null);
    } else {
      widget.onExit();
    }
  }

  void _reset() {
    _clearMotion();
    setState(() {});
  }

  /// 카메라 배경 위에 그리는 중인지. 카메라를 못 쓰는 기기에서 '카메라 없이 연습하기'를
  /// 고르면 톡톡 Lite에 들어와 있어도 1단계와 같은 배경으로 그린다.
  bool get _cameraMode => widget.cameraMode && !practiceWithoutCamera;

  KeyboardLayout get _keyboard => KeyboardLayout(
        y: selected == null ? 320 : (_cameraMode ? 650 : 625),
        height: selected == null ? 280 : (_cameraMode ? 252 : 280),
        count: selected != null && selected!.index < 5 ? 5 : 8,
      );

  Offset _keyCenter(int index) => _keyboard.iconCenter(index);

  Offset _noteTarget(NoteSpec note) {
    const staffY = 92.0;
    const gap = 28.0;
    return Offset(420, staffY + gap * 5 - note.pitchStep * gap / 2);
  }

  Offset _flightPoint(double t) {
    final start = _keyCenter(selected!.index);
    final end = _noteTarget(selected!);
    return Offset(
      start.dx + (end.dx - start.dx) * t + 170 * math.sin(t * math.pi * 4),
      start.dy + (end.dy - start.dy) * t + 125 * math.sin(t * math.pi * 2),
    );
  }

  void _onSceneTap(Offset point) {
    if (showPopup) {
      if ((point - const Offset(400, 460)).distance < 130) _reset();
      return;
    }
    if (selected == null) {
      final index = _keyboard.hitWhiteKey(point);
      if (index != null) _choose(notes[index]);
      return;
    }
    if (flight.isAnimating || landed) return;
    if ((point - _keyCenter(selected!.index)).distance < 62) {
      if (widget.soundOn) tone.playNote(selected!.frequency, durationSeconds: 2);
      flight.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noSelection = selected == null;
    // 모드 이름은 widget.cameraMode(화면 정체성)로, 'AR' 표기는 _cameraMode(실제 상태)로
    // 정한다. 카메라 없이 연습하는 중에는 톡톡 Lite에 머물지만 AR은 아니다.
    final title = noSelection
        ? (widget.cameraMode ? '톡톡 Lite' : '톡톡! 한 음 익히기')
        : '${selected!.label} ${_cameraMode ? 'AR ' : ''}음정 연습';
    final subtitle = noSelection ? '건반에서 연습할 음을 골라보세요' : '도형을 눌러 악보까지 따라가 보세요';
    final kb = _keyboard;
    return StageShell(
      title: title,
      subtitle: subtitle,
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      onBack: _goBack,
      // 프리뷰가 준비되기 전에는 건반을 눌러도 배경이 없으므로 안내 화면만 보여준다.
      child: _cameraMode && cameraStage != _CameraStage.ready
          ? _buildCameraNotice()
          : _buildScene(kb),
    );
  }

  Widget _buildScene(KeyboardLayout kb) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([flight, burst, popup]),
        builder: (context, _) => SceneView(
          onTap: _onSceneTap,
          background: _cameraMode ? _buildCamera() : null,
          painter: LessonPainter(
            selected: selected,
            cameraMode: _cameraMode,
            keyboard: kb,
            flightProgress: flight.value,
            isFlying: flight.isAnimating,
            landed: landed,
            burstProgress: burst.value,
            showPopup: showPopup,
            popupProgress: popup.value,
            flightPoint: selected == null ? null : _flightPoint(flight.value),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    if (camera != null && camera!.value.isInitialized) {
      final size = camera!.value.previewSize!;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: size.height, height: size.width, child: CameraPreview(camera!)),
          ),
        ),
      );
    }
    return Container(color: const Color(0xff30343a));
  }

  /// 프리뷰를 띄울 수 없을 때의 안내. 어떤 상태에서도 다음 행동이 하나는 남아 있어야 한다.
  Widget _buildCameraNotice() {
    final (message, guide) = switch (cameraStage) {
      _CameraStage.preparing => ('카메라를 준비하고 있어요', null),
      _CameraStage.denied => ('카메라를 사용해야 AR 톡톡을 만날 수 있어요', '카메라 켜기를 눌러 허용해 주세요'),
      _CameraStage.blocked => (
          '카메라 사용이 꺼져 있어요',
          '설정에서 카메라를 허용하면 바로 시작할 수 있어요',
        ),
      _CameraStage.unavailable => ('이 기기에서는 카메라를 쓸 수 없어요', '카메라 없이도 같은 연습을 할 수 있어요'),
      _CameraStage.ready => ('', null),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cameraStage == _CameraStage.preparing
                    ? Icons.camera_alt_outlined
                    : Icons.no_photography_outlined,
                size: 54,
                color: Colors.black38,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (guide != null) ...[
                const SizedBox(height: 6),
                Text(
                  guide,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 20),
              if (cameraStage == _CameraStage.preparing)
                const CircularProgressIndicator()
              else ...[
                if (cameraStage == _CameraStage.denied)
                  FilledButton.icon(
                    onPressed: _initializeCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('카메라 켜기'),
                  ),
                if (cameraStage == _CameraStage.blocked)
                  FilledButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('설정 열기'),
                  ),
                if (cameraStage == _CameraStage.unavailable)
                  FilledButton.icon(
                    onPressed: _initializeCamera,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('다시 시도'),
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => practiceWithoutCamera = true),
                  child: const Text('카메라 없이 연습하기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
