import 'package:flutter/material.dart';

enum RootPage { home, stageOne, arModes, arLite, stageThree }

enum NoteShape { heart, circle, star, triangle, apple, flower, cloud }

enum RestKind { half, three, whole }

class NoteSpec {
  const NoteSpec(this.label, this.frequency, this.color, this.pitchStep, this.shape, this.index);
  final String label;
  final double frequency;
  final Color color;
  final int pitchStep;
  final NoteShape shape;
  final int index;
}
