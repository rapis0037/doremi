import 'package:flutter/material.dart';

import 'models.dart';

const sceneSize = Size(800, 920);

/// 콘텐츠가 큰 화면에서 지나치게 넓어지지 않도록 하는 상한.
///
/// [ResponsiveViewport]는 태블릿에서 남는 공간을 여백이 아니라 논리 dp로
/// 돌려준다. 그래서 상한을 두지 않으면 글줄과 버튼이 폰에서 보던 것보다 넓게
/// 늘어난다. 화면 성격별로 나눠 두되, 값은 여기서만 고친다.

/// 설정·구독 다이얼로그.
const double kDialogMaxWidth = 360;

/// 카메라 권한 안내처럼 문장이 중심인 카드.
const double kNoticeMaxWidth = 420;

/// 홈 단계 카드, AR 모드 버튼.
const double kCardMaxWidth = 460;

/// 회원가입 환영 화면.
const double kWelcomeMaxWidth = 520;

/// 회원가입 단계와 감각 설정처럼 항목이 늘어서는 화면.
const double kFormMaxWidth = 560;

/// 높은 도는 따로 녹음된 음성이 없어 '도' 음성을 그대로 쓴다.
const notes = <NoteSpec>[
  NoteSpec(
    '도',
    261.63,
    Color(0xffed4f7f),
    0,
    NoteShape.heart,
    0,
    noteAsset: 'notes/note_do.wav',
    voiceAsset: 'voice/high_tone_do.wav',
  ),
  NoteSpec(
    '레',
    293.66,
    Color(0xffffc73d),
    1,
    NoteShape.circle,
    1,
    noteAsset: 'notes/note_re.wav',
    voiceAsset: 'voice/high_tone_re.wav',
  ),
  NoteSpec(
    '미',
    329.63,
    Color(0xff4d9dea),
    2,
    NoteShape.star,
    2,
    noteAsset: 'notes/note_mi.wav',
    voiceAsset: 'voice/high_tone_mi.wav',
  ),
  NoteSpec(
    '파',
    349.23,
    Color(0xffff8a4c),
    3,
    NoteShape.triangle,
    3,
    noteAsset: 'notes/note_fa.wav',
    voiceAsset: 'voice/high_tone_fa.wav',
  ),
  NoteSpec(
    '솔',
    392.00,
    Color(0xff91c95c),
    4,
    NoteShape.apple,
    4,
    noteAsset: 'notes/note_sol.wav',
    voiceAsset: 'voice/high_tone_sol.wav',
  ),
  NoteSpec(
    '라',
    440.00,
    Color(0xffad8be8),
    5,
    NoteShape.flower,
    5,
    noteAsset: 'notes/note_la.wav',
    voiceAsset: 'voice/high_tone_la.wav',
  ),
  NoteSpec(
    '시',
    493.88,
    Color(0xff7ed2ef),
    6,
    NoteShape.cloud,
    6,
    noteAsset: 'notes/note_ti.wav',
    voiceAsset: 'voice/high_tone_ti.wav',
  ),
  NoteSpec(
    '높은 도',
    523.25,
    Color(0xffe84d55),
    7,
    NoteShape.heart,
    7,
    noteAsset: 'notes/note_high_do.wav',
    voiceAsset: 'voice/high_tone_do.wav',
  ),
];
