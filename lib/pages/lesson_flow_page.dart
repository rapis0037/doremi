import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../audio/tone_player.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../layout/keyboard_layout.dart';
import '../painters/lesson_painter.dart';
import '../widgets/scene_view.dart';
import '../widgets/stage_shell.dart';

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
  String? cameraError;
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
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', '카메라가 없습니다');
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
      setState(() => camera = controller);
    } on CameraException {
      if (mounted) setState(() => cameraError = '카메라 권한을 허용해 주세요');
    } catch (_) {
      if (mounted) setState(() => cameraError = '카메라를 시작할 수 없습니다');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
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

  KeyboardLayout get _keyboard => KeyboardLayout(
        y: selected == null ? 320 : (widget.cameraMode ? 650 : 625),
        height: selected == null ? 280 : (widget.cameraMode ? 252 : 280),
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
    final title = widget.cameraMode
        ? noSelection ? '톡톡 Lite' : '${selected!.label} AR 음정 연습'
        : noSelection ? '톡톡! 한 음 익히기' : '${selected!.label} 음정 연습';
    final subtitle = noSelection ? '건반에서 연습할 음을 골라보세요' : '도형을 눌러 악보까지 따라가 보세요';
    final kb = _keyboard;
    return StageShell(
      title: title,
      subtitle: subtitle,
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      onBack: _goBack,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([flight, burst, popup]),
          builder: (context, _) => SceneView(
            onTap: _onSceneTap,
            background: widget.cameraMode ? _buildCamera() : null,
            painter: LessonPainter(
              selected: selected,
              cameraMode: widget.cameraMode,
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
    return Container(
      color: const Color(0xff30343a),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 54),
          const SizedBox(height: 12),
          Text(
            cameraError ?? '카메라를 준비하고 있어요',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
