import 'package:flutter/material.dart';

import 'models.dart';

const sceneSize = Size(800, 920);

/// 높은 도는 따로 녹음된 음성이 없어 '도' 음성을 그대로 쓴다.
const notes = <NoteSpec>[
  NoteSpec('도', 261.63, Color(0xffed4f7f), 0, NoteShape.heart, 0,
      noteAsset: 'notes/note_do.wav', voiceAsset: 'voice/high_tone_do.wav'),
  NoteSpec('레', 293.66, Color(0xffffc73d), 1, NoteShape.circle, 1,
      noteAsset: 'notes/note_re.wav', voiceAsset: 'voice/high_tone_re.wav'),
  NoteSpec('미', 329.63, Color(0xff4d9dea), 2, NoteShape.star, 2,
      noteAsset: 'notes/note_mi.wav', voiceAsset: 'voice/high_tone_mi.wav'),
  NoteSpec('파', 349.23, Color(0xffff8a4c), 3, NoteShape.triangle, 3,
      noteAsset: 'notes/note_fa.wav', voiceAsset: 'voice/high_tone_fa.wav'),
  NoteSpec('솔', 392.00, Color(0xff91c95c), 4, NoteShape.apple, 4,
      noteAsset: 'notes/note_sol.wav', voiceAsset: 'voice/high_tone_sol.wav'),
  NoteSpec('라', 440.00, Color(0xffad8be8), 5, NoteShape.flower, 5,
      noteAsset: 'notes/note_la.wav', voiceAsset: 'voice/high_tone_la.wav'),
  NoteSpec('시', 493.88, Color(0xff7ed2ef), 6, NoteShape.cloud, 6,
      noteAsset: 'notes/note_ti.wav', voiceAsset: 'voice/high_tone_ti.wav'),
  NoteSpec('높은 도', 523.25, Color(0xffe84d55), 7, NoteShape.heart, 7,
      noteAsset: 'notes/note_high_do.wav', voiceAsset: 'voice/high_tone_do.wav'),
];
