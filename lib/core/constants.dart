import 'package:flutter/material.dart';

import 'models.dart';

const sceneSize = Size(800, 920);

const notes = <NoteSpec>[
  NoteSpec('도', 261.63, Color(0xffed4f7f), 0, NoteShape.heart, 0),
  NoteSpec('레', 293.66, Color(0xffffc73d), 1, NoteShape.circle, 1),
  NoteSpec('미', 329.63, Color(0xff4d9dea), 2, NoteShape.star, 2),
  NoteSpec('파', 349.23, Color(0xffff8a4c), 3, NoteShape.triangle, 3),
  NoteSpec('솔', 392.00, Color(0xff91c95c), 4, NoteShape.apple, 4),
  NoteSpec('라', 440.00, Color(0xffad8be8), 5, NoteShape.flower, 5),
  NoteSpec('시', 493.88, Color(0xff7ed2ef), 6, NoteShape.cloud, 6),
  NoteSpec('높은 도', 523.25, Color(0xffe84d55), 7, NoteShape.heart, 7),
];
