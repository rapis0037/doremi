import 'package:flutter/material.dart';

enum RootPage { home, stageOne, arModes, arLite, arSpace, stageThree }

enum NoteShape { heart, circle, star, triangle, apple, flower, cloud }

enum RestKind { half, three, whole }

class NoteSpec {
  const NoteSpec(
    this.label,
    this.frequency,
    this.color,
    this.pitchStep,
    this.shape,
    this.index, {
    required this.noteAsset,
    required this.voiceAsset,
  });
  final String label;
  final double frequency;
  final Color color;
  final int pitchStep;
  final NoteShape shape;
  final int index;

  /// 건반을 누르면 울리는 피아노 음원. `assets/` 아래 상대 경로.
  final String noteAsset;

  /// 음표가 오선지에 안착한 뒤 들려주는 계이름 음성.
  final String voiceAsset;
}
