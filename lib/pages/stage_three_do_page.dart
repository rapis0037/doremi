import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/tone_player.dart';
import '../core/constants.dart';
import '../layout/keyboard_layout.dart';
import '../painters/challenge_painter.dart';
import '../widgets/scene_view.dart';
import '../widgets/stage_shell.dart';

class StageThreeDoPage extends StatefulWidget {
  const StageThreeDoPage({
    super.key,
    required this.soundOn,
    required this.onSoundChanged,
    required this.onBack,
  });
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onBack;

  @override
  State<StageThreeDoPage> createState() => _StageThreeDoPageState();
}

class _StageThreeDoPageState extends State<StageThreeDoPage> with TickerProviderStateMixin {
  static const _home = Offset(400, 590);
  final TonePlayer tone = TonePlayer();
  late final AnimationController _returnCtrl;
  late final AnimationController _guide;
  late final AnimationController _confetti;
  late final AnimationController _performance;
  late final AnimationController _popup;
  final _keyboard = const KeyboardLayout(y: 24, height: 420, count: 5);
  Offset _heart = _home;
  Offset _returnStart = _home;
  bool _dragging = false;
  bool _chosen = false;
  bool _fixed = false;
  bool _showScore = false;
  bool _showPopup = false;
  int _activeNote = -1;
  int _lastPlayed = -1;
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    tone.preload();
    _returnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
      ..addListener(() {
          setState(() {
            _heart = Offset.lerp(
              _returnStart,
              _home,
              Curves.easeOutCubic.transform(_returnCtrl.value),
            )!;
          });
        });
    _guide = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _performance = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))
      ..addListener(_updatePerformance)
      ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _activeNote = -1);
            _popupTimer = Timer(const Duration(milliseconds: 350), () {
              if (!mounted) return;
              setState(() => _showPopup = true);
              _popup.forward(from: 0);
            });
          }
        });
    _popup = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  }

  void _updatePerformance() {
    final elapsed = _performance.value * 4800;
    final index = elapsed < 2400 ? (elapsed ~/ 600).clamp(0, 3).toInt() : 4;
    if (index != _lastPlayed) {
      _lastPlayed = index;
      // 600ms마다 다시 울리며 앞 음을 끊으므로 앞 네 번은 짧게, 마지막 한 번만
      // 길게 남는다.
      tone.playNote(notes.first);
    }
    setState(() => _activeNote = index);
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _returnCtrl.dispose();
    _guide.dispose();
    _confetti.dispose();
    _performance.dispose();
    _popup.dispose();
    tone.dispose();
    super.dispose();
  }

  void _reset() {
    _popupTimer?.cancel();
    _returnCtrl.reset();
    _guide.reset();
    _confetti.reset();
    _performance.reset();
    _popup.reset();
    setState(() {
      _heart = _home;
      _dragging = false;
      _chosen = false;
      _fixed = false;
      _showScore = false;
      _showPopup = false;
      _activeNote = -1;
      _lastPlayed = -1;
    });
  }

  bool _nearHeart(Offset point) => (point - _heart).distance < 76;
  bool _inDoTarget(Offset point) => _keyboard.whiteKeyRect(0).inflate(24).contains(point);

  void _accept() {
    if (_fixed) return;
    setState(() {
      _fixed = true;
      _chosen = false;
      _dragging = false;
      _showScore = true;
      _heart = _keyboard.iconCenter(0);
      _activeNote = 0;
      _lastPlayed = -1;
    });
    _confetti.forward(from: 0);
    _performance.forward(from: 0);
  }

  void _reject() {
    if (_fixed) return;
    _returnStart = _heart;
    setState(() {
      _dragging = false;
      _chosen = false;
    });
    _returnCtrl.forward(from: 0);
    _guide.forward(from: 0);
  }

  void _onTap(Offset point) {
    if (_showPopup) {
      if ((point - const Offset(400, 460)).distance < 140) _reset();
      return;
    }
    if (_fixed) return;
    if (_nearHeart(point)) {
      setState(() => _chosen = true);
      return;
    }
    if (_chosen) {
      _heart = point;
      _inDoTarget(point) ? _accept() : _reject();
    }
  }

  void _onPanStart(Offset point) {
    if (!_fixed && _nearHeart(point)) {
      setState(() {
        _dragging = true;
        _chosen = true;
      });
    }
  }

  void _onPanUpdate(Offset point) {
    if (_dragging && !_fixed) setState(() => _heart = point);
  }

  void _onPanEnd() {
    if (!_dragging || _fixed) return;
    _inDoTarget(_heart) ? _accept() : _reject();
  }

  @override
  Widget build(BuildContext context) {
    return StageShell(
      title: '도 음정 끌어놓기',
      subtitle: '핑크 하트를 도 건반으로 옮겨보세요',
      soundOn: widget.soundOn,
      onSoundChanged: widget.onSoundChanged,
      onBack: widget.onBack,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_guide, _confetti, _performance, _popup]),
          builder: (context, _) => SceneView(
            onTap: _onTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            painter: ChallengePainter(
              keyboard: _keyboard,
              heart: _heart,
              chosen: _chosen,
              fixed: _fixed,
              guideProgress: _guide.value,
              confettiProgress: _confetti.value,
              showScore: _showScore,
              activeNote: _activeNote,
              performanceDone: _performance.status == AnimationStatus.completed,
              showPopup: _showPopup,
              popupProgress: _popup.value,
            ),
          ),
        ),
      ),
    );
  }
}
