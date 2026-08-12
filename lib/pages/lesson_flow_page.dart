import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../audio/tone_player.dart';
import '../core/constants.dart';
import '../core/models.dart';
import '../layout/lesson_scene.dart';
import '../painters/lesson_painter.dart';
import '../widgets/scene_view.dart';
import '../widgets/stage_shell.dart';
import '../widgets/step_card.dart';

class LessonFlowPage extends StatefulWidget {
  const LessonFlowPage({
    super.key,
    required this.cameraMode,
    required this.soundOn,
    required this.onSoundChanged,
    required this.sparklesOn,
    required this.onSparklesChanged,
    required this.onExit,
  });
  final bool cameraMode;
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final bool sparklesOn;
  final ValueChanged<bool> onSparklesChanged;
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
    tone.preload();
    flight =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => landed = true);
              // 오선지에 안착한 순간 계이름을 불러 준다. 건반을 누를 때 울린
              // 피아노 음은 아직 남아 있고, 그 위로 음성이 얹힌다.
              final note = selected;
              if (widget.soundOn && note != null) tone.playVoice(note);
              burst.forward(from: 0);
              popupTimer?.cancel();
              popupTimer = Timer(const Duration(seconds: 2), () {
                if (!mounted || !landed) return;
                setState(() => showPopup = true);
                popup.forward(from: 0);
              });
            }
          });
    burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    popup = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
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
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
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

  /// 화면 방향에 맞는 장면 좌표계. 그리기와 탭 판정이 같은 값을 써야 한다.
  LessonScene get _scene => LessonScene.of(
    landscape: MediaQuery.of(context).orientation == Orientation.landscape,
    selected: selected,
    cameraMode: widget.cameraMode,
  );

  void _onSceneTap(Offset point) {
    final scene = _scene;
    if (showPopup) {
      // 팝업 원 안 아무 데나 누르면 초기화된다.
      if ((point - scene.popupCenter).distance < scene.popupRadius) _reset();
      return;
    }
    if (selected == null) {
      final index = scene.keyboard.hitWhiteKey(point);
      if (index != null) _choose(notes[index]);
      return;
    }
    if (flight.isAnimating || landed) return;
    // 도형만이 아니라 해당 음의 건반 전체가 탭 영역이다. 건반 선택 화면과
    // 같은 판정을 써서 검은 건반은 자연스럽게 제외된다.
    if (scene.keyboard.hitWhiteKey(point) == selected!.index) {
      tone.playNote(selected!);
      flight.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noSelection = selected == null;
    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.width > screenSize.height;
    const notePickingTitleOffsetY = 150.0;
    const pitchPracticeTitleOffsetY = 70.0;
    const liteMenuTitleOffsetY = 150.0;
    const litePracticeTitleOffsetY = pitchPracticeTitleOffsetY;
    final cameraPractice = widget.cameraMode && !noSelection;
    final headerContentOffsetY = wide
        ? 0.0
        : widget.cameraMode
        ? (noSelection ? liteMenuTitleOffsetY : litePracticeTitleOffsetY)
        : (noSelection ? notePickingTitleOffsetY : pitchPracticeTitleOffsetY);
    final title = widget.cameraMode
        ? noSelection
              ? '톡톡 Lite'
              : '${selected!.label} AR 음정 연습'
        : noSelection
        ? '톡톡! 한 음 익히기'
        : '${selected!.label} 음정 연습';
    final subtitle = noSelection ? '건반에서 연습할 음을 골라보세요' : '도형을 눌러 악보까지 따라가 보세요';
    final scene = _scene;
    return StageShell(
      title: title,
      subtitle: subtitle,
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      sparklesOn: widget.sparklesOn,
      onSparklesChanged: widget.onSparklesChanged,
      onBack: _goBack,
      headerHeight: wide ? 68 : StepCard.height,
      headerContentScale: wide ? 1 : 1.3,
      headerContentOffsetY: headerContentOffsetY,
      headerContentWidthScale: cameraPractice ? 1.22 : 1,
      headerTitleColor: widget.cameraMode
          ? const Color(0xffffe7a3)
          : const Color(0xff252a2e),
      headerSubtitleColor: widget.cameraMode
          ? const Color(0xffffe7a3)
          : const Color(0xff687582),
      headerIconColor: widget.cameraMode ? const Color(0xff73e76d) : null,
      headerSubtitleScale: widget.cameraMode && noSelection ? 1.25 : 1,
      // 카메라는 씬 박스가 아니라 화면 전체를 채우고, 건반·악보 오버레이가
      // 그 위에 올라간다.
      backdrop: widget.cameraMode ? _buildCamera() : null,
      child: Align(
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: Listenable.merge([flight, burst, popup]),
          builder: (context, _) => SceneView(
            onTap: _onSceneTap,
            scene: scene.size,
            painter: LessonPainter(
              selected: selected,
              cameraMode: widget.cameraMode,
              sparklesOn: widget.sparklesOn,
              scene: scene,
              flightProgress: flight.value,
              isFlying: flight.isAnimating,
              landed: landed,
              burstProgress: burst.value,
              showPopup: showPopup,
              popupProgress: popup.value,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _cameraLayer(),
        // 건반·악보가 잘 보이도록 카메라 전체를 아주 옅게 눌러 준다.
        ColoredBox(color: Colors.black.withValues(alpha: .12)),
      ],
    );
  }

  Widget _cameraLayer() {
    if (camera != null && camera!.value.isInitialized) {
      // previewSize는 센서 기준(가로)이라 화면 방향에 맞춰 축을 바꿔 준다.
      final preview = camera!.value.previewSize!;
      final portrait =
          MediaQuery.of(context).orientation == Orientation.portrait;
      return ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: portrait ? preview.height : preview.width,
              height: portrait ? preview.width : preview.height,
              child: CameraPreview(camera!),
            ),
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
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white70,
            size: 54,
          ),
          const SizedBox(height: 12),
          Text(
            cameraError ?? '카메라를 준비하고 있어요',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
