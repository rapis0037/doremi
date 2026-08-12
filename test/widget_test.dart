import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doremi/core/constants.dart';
import 'package:doremi/drawing/effect_drawing.dart';
import 'package:doremi/drawing/shape_drawing.dart';
import 'package:doremi/drawing/staff_drawing.dart';
import 'package:doremi/layout/keyboard_layout.dart';
import 'package:doremi/layout/lesson_scene.dart';
import 'package:doremi/main.dart';
import 'package:doremi/widgets/app_background.dart';
import 'package:doremi/widgets/app_header.dart';
import 'package:doremi/widgets/cat_face.dart';
import 'package:doremi/widgets/mode_button.dart';
import 'package:doremi/widgets/responsive_viewport.dart';
import 'package:doremi/widgets/scene_view.dart';
import 'package:doremi/widgets/step_card.dart';

/// 지정한 화면 크기(dp)로 앱을 띄운다.
Future<void> pumpAppAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MusicMvpApp());
  await tester.pump();
}

/// ResponsiveViewport가 자식에게 넘겨 준 논리 캔버스 크기.
Size logicalSizeOf(WidgetTester tester) =>
    MediaQuery.of(tester.element(find.byType(StepCard).first)).size;

void main() {
  group('responsiveScaleFor', () {
    test('기준 화면(412dp)에서는 배율이 1', () {
      expect(responsiveScaleFor(const Size(412, 915)), closeTo(1.0, 1e-9));
    });

    test('기준보다 좁은 화면은 폭에 정비례해 축소', () {
      expect(
        responsiveScaleFor(const Size(360, 640)),
        closeTo(360 / 412, 1e-9),
      );
    });

    test('태블릿은 확대되지만 화면 배율보다는 완만하게', () {
      const raw = 800 / kReferenceShortSide;
      final scale = responsiveScaleFor(const Size(800, 1280));
      expect(scale, greaterThan(1.4));
      expect(scale, lessThan(raw));
    });

    test('아주 큰 화면에서도 배율 상한을 넘지 않는다', () {
      expect(
        responsiveScaleFor(const Size(2000, 3000)),
        lessThanOrEqualTo(2.0),
      );
    });

    test('가로/세로에 관계없이 짧은 변 기준으로 같은 배율', () {
      expect(
        responsiveScaleFor(const Size(800, 1280)),
        closeTo(responsiveScaleFor(const Size(1280, 800)), 1e-9),
      );
    });
  });

  group('건반 절반 분할 배치', () {
    // 1단계 건반 선택 / 도 연습 / 톡톡 Lite 도 연습.
    const picker = KeyboardLayout(y: 320, height: 280, count: 8);
    const practice = KeyboardLayout(y: 625, height: 280, count: 5);
    const litePractice = KeyboardLayout(y: 650, height: 252, count: 5);

    test('도형 자리는 건반 위쪽 절반, 계이름 자리는 아래쪽 절반', () {
      for (final k in [picker, practice, litePractice]) {
        for (var i = 0; i < k.count; i++) {
          final key = k.whiteKeyRect(i);
          final shape = k.shapeSlot(i);
          final label = k.labelSlot(i);
          expect(shape.top, closeTo(key.top, 0.01));
          expect(shape.bottom, closeTo(key.center.dy, 0.01));
          expect(label.top, closeTo(key.center.dy, 0.01));
          expect(label.bottom, closeTo(key.bottom, 0.01));
        }
      }
    });

    test('도형 자리가 검은 건반을 피한다', () {
      for (final k in [picker, practice, litePractice]) {
        for (final after in k.blackAfter) {
          final black = k.blackKeyRect(after);
          for (final i in [after, after + 1]) {
            if (i < 0 || i >= k.count) continue;
            expect(
              k.shapeSlot(i).overlaps(black),
              isFalse,
              reason: 'count=${k.count} key$i 의 도형 자리가 검은 건반과 겹침',
            );
          }
        }
      }
    });

    test('도형이 자리를 넘지 않으면서 연습 화면에서 두 배 이상 커진다', () {
      double sizeFor(KeyboardLayout k, int? selected) {
        var size = double.infinity;
        for (var i = 0; i < k.count; i++) {
          if (selected != null && selected != i) continue;
          final slot = k.shapeSlot(i).deflate(4);
          final factor = shapeWidthFactor(notes[i].shape);
          size = math.min(size, math.min(slot.width / factor, slot.height));
        }
        return size;
      }

      // 도 연습 화면(사용자가 지정한 화면): 기존 52 대비 두 배 이상.
      expect(sizeFor(practice, 0), greaterThan(104));
      expect(sizeFor(litePractice, 0), greaterThan(104));

      // 어떤 화면에서도 도형 실제 폭이 자리를 벗어나지 않는다.
      for (final entry in {
        picker: null,
        practice: 0,
        litePractice: 0,
      }.entries) {
        final k = entry.key;
        final size = sizeFor(k, entry.value);
        for (var i = 0; i < k.count; i++) {
          if (entry.value != null && entry.value != i) continue;
          final drawnWidth = size * shapeWidthFactor(notes[i].shape);
          expect(
            drawnWidth,
            lessThanOrEqualTo(k.shapeSlot(i).width - 8 + 0.01),
          );
          expect(size, lessThanOrEqualTo(k.shapeSlot(i).height - 8 + 0.01));
        }
      }
    });

    test('탭 영역이 도형이 아니라 건반 전체다', () {
      // lesson_flow_page 는 hitWhiteKey 로 판정하므로, 해당 음 건반 어디를
      // 눌러도 반응해야 한다.
      for (final k in [practice, litePractice]) {
        final key = k.whiteKeyRect(0);
        for (final point in [
          k.shapeSlot(0).center, // 도형 자리
          k.labelSlot(0).center, // 계이름 자리
          key.center,
          Offset(key.left + 4, key.bottom - 4), // 왼쪽 아래 구석
          Offset(key.right - 4, key.bottom - 4), // 오른쪽 아래 구석
        ]) {
          expect(k.hitWhiteKey(point), 0, reason: '$point 에서 도 건반이 잡혀야 함');
        }

        // 옆 건반과 검은 건반은 그 음으로 잡히지 않는다.
        expect(k.hitWhiteKey(k.whiteKeyRect(1).center), isNot(0));
        expect(k.hitWhiteKey(k.blackKeyRect(0).center), isNull);
      }
    });
  });

  group('가로 화면 장면 전환', () {
    test('세로 장면은 기존 좌표계를 그대로 쓴다', () {
      final portrait = LessonScene.of(landscape: false, selected: null);
      expect(portrait.size, const Size(800, 920));
      expect(portrait.keyboard.y, 320);
      expect(portrait.keyboard.width, 776);
      expect(portrait.staffY, 92);
      expect(portrait.popupCenter, const Offset(400, 460));
      // 선택 후 건반 위치·개수도 예전 그대로.
      final selected = LessonScene.of(landscape: false, selected: notes[0]);
      expect(selected.size, LessonScene.portraitPracticeSize);
      expect(selected.keyboard.y, 920);
      expect(selected.keyboard.count, 5);
      expect(selected.noteTarget(notes[0]).dx, 420);
    });

    test('가로에서도 흰 건반 가로세로 비율이 세로와 같다', () {
      for (final selected in [null, notes[0], notes[7]]) {
        final portrait = LessonScene.of(landscape: false, selected: selected);
        final landscape = LessonScene.of(landscape: true, selected: selected);
        final p = portrait.keyboard;
        final l = landscape.keyboard;
        expect(
          l.keyWidth / l.keyHeight,
          closeTo(p.keyWidth / p.keyHeight, 0.005),
          reason: '가로 건반이 납작해지면 안 됨 (selected=$selected)',
        );
        // 검은 건반도 같은 비율로 따라 커진다.
        expect(
          l.blackKeyRect(0).width / l.keyWidth,
          closeTo(p.blackKeyRect(0).width / p.keyWidth, 0.005),
        );
      }
    });

    test('계이름 팝업이 커지되 캔버스를 넘지 않는다', () {
      for (final landscape in [false, true]) {
        final scene = LessonScene.of(landscape: landscape, selected: notes[0]);
        // 기존 크기(145)보다 확실히 커진다.
        expect(scene.popupRadius, greaterThan(basePopupRadius * 1.4));
        expect(
          scene.popupRadius,
          lessThanOrEqualTo(basePopupRadius * LessonScene.popupZoom),
        );
        // 원이 캔버스 안에 온전히 들어간다.
        final c = scene.popupCenter;
        final r = scene.popupRadius;
        expect(c.dx - r, greaterThanOrEqualTo(0));
        expect(c.dy - r, greaterThanOrEqualTo(0));
        expect(c.dx + r, lessThanOrEqualTo(scene.size.width));
        expect(c.dy + r, lessThanOrEqualTo(scene.size.height));
      }
      // 세로는 상한에 걸리지 않고 두 배를 다 쓴다.
      final portrait = LessonScene.of(landscape: false, selected: notes[0]);
      expect(portrait.popupRadius, closeTo(basePopupRadius * 2, 0.01));
    });

    test('가로 건반이 캔버스를 벗어나지 않는다', () {
      for (final selected in [null, notes[0]]) {
        final scene = LessonScene.of(landscape: true, selected: selected);
        final k = scene.keyboard;
        expect(k.x, greaterThanOrEqualTo(0));
        expect(k.y, greaterThanOrEqualTo(0));
        expect(k.x + k.width, lessThanOrEqualTo(scene.size.width));
        expect(k.y + k.height, lessThanOrEqualTo(scene.size.height));
      }
    });

    test('악보와 건반이 겹치지 않고 캔버스 안에 들어간다', () {
      for (final landscape in [false, true]) {
        final scene = LessonScene.of(landscape: landscape, selected: notes[0]);
        final canvas = Offset.zero & scene.size;
        expect(
          scene.staffBox.overlaps(scene.keyboardBox),
          isFalse,
          reason: '악보와 건반이 겹침 (landscape=$landscape)',
        );
        // 반투명 카드가 캔버스 밖으로 잘리지 않는다.
        for (final box in [scene.staffBox, scene.keyboardBox]) {
          expect(
            canvas.contains(box.topLeft),
            isTrue,
            reason: '$box 가 캔버스를 벗어남 (landscape=$landscape)',
          );
          expect(
            canvas.contains(box.bottomRight - const Offset(0.01, 0.01)),
            isTrue,
            reason: '$box 가 캔버스를 벗어남 (landscape=$landscape)',
          );
        }
        // 음표가 오선 영역 안에 앉는다.
        expect(scene.staffBox.contains(scene.noteTarget(notes[0])), isTrue);
        expect(scene.staffBox.contains(scene.noteTarget(notes[7])), isTrue);
      }
    });

    test('톡톡 Lite와 1단계가 완전히 같은 좌표계를 쓴다', () {
      for (final selected in [null, notes[0], notes[7]]) {
        final stageOne = LessonScene.of(
          landscape: false,
          selected: selected,
        );
        final lite = LessonScene.of(
          landscape: false,
          selected: selected,
          cameraMode: true,
        );
        expect(lite.size, stageOne.size);
        expect(lite.staffX, stageOne.staffX);
        expect(lite.staffY, stageOne.staffY);
        expect(lite.staffWidth, stageOne.staffWidth);
        expect(lite.staffScale, stageOne.staffScale);
        expect(lite.keyboardBox, stageOne.keyboardBox);
      }
    });

    test('비행 궤적이 건반에서 출발해 음자리로 끝난다', () {
      for (final landscape in [false, true]) {
        for (final note in [notes[0], notes[7]]) {
          final scene = LessonScene.of(landscape: landscape, selected: note);
          final start = scene.flightPoint(note, 0);
          final end = scene.flightPoint(note, 1);
          expect(start, scene.keyboard.shapeSlot(note.index).center);
          expect(end.dx, closeTo(scene.noteTarget(note).dx, 0.01));
          expect(end.dy, closeTo(scene.noteTarget(note).dy, 0.01));
        }
      }
    });

    test('비행 궤적이 캔버스를 벗어나지 않는다', () {
      // 가로는 건반이 오른쪽, 악보가 왼쪽이라 좌우로 크게 흔들린다.
      for (final landscape in [false, true]) {
        for (final note in notes) {
          final scene = LessonScene.of(landscape: landscape, selected: note);
          for (var i = 0; i <= 60; i++) {
            final p = scene.flightPoint(note, i / 60);
            expect(
              p.dx,
              inInclusiveRange(0, scene.size.width),
              reason:
                  '${note.label} t=${i / 60} 에서 좌우로 벗어남 (landscape=$landscape)',
            );
            expect(
              p.dy,
              inInclusiveRange(0, scene.size.height),
              reason:
                  '${note.label} t=${i / 60} 에서 위아래로 벗어남 (landscape=$landscape)',
            );
          }
        }
      }
    });

    test('오선이 기준보다 확실히 커진다', () {
      for (final landscape in [false, true]) {
        final scene = LessonScene.of(landscape: landscape, selected: notes[0]);
        expect(scene.staffScale, LessonScene.staffZoom);
        expect(
          scene.staffGap,
          closeTo(baseStaffGap * LessonScene.staffZoom, 0.01),
        );
      }
    });

    testWidgets('가로에서 건반이 화면 폭의 대부분을 차지한다', (tester) async {
      // 실기기(SM A908N) 가로와 같은 논리 크기.
      await pumpAppAt(tester, const Size(914, 411));
      await tester.tap(find.byType(StepCard).first);
      await tester.pumpAndSettle();

      final view = tester.getRect(find.byType(SceneView));
      final scene = LessonScene.of(landscape: true, selected: null);
      final renderScale = view.width / scene.size.width;
      final keyboardOnScreen = scene.keyboard.width * renderScale;

      // 이전(세로 캔버스 고정)에는 화면 폭의 30% 미만이었다.
      expect(
        keyboardOnScreen / 914,
        greaterThan(0.6),
        reason: '가로에서 건반이 화면 폭의 60% 이상을 써야 함',
      );
    });
  });

  group('홈 화면 헤더', () {
    testWidgets('세로에서 헤더가 단계 카드 한 칸 높이를 잡는다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));

      final header = tester.getRect(find.byType(AppHeader));
      final card = tester.getRect(find.byType(StepCard).first);
      expect(header.height, closeTo(StepCard.height, 0.5));
      expect(header.height, closeTo(card.height, 0.5));
    });

    testWidgets('1단계 세로 헤더가 홈과 같은 크기다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));
      final homeHeader = tester.getRect(find.byType(AppHeader));
      final homeTitle = tester.getRect(find.text('너두! 도레미!')).height;
      final homeIcon = tester
          .getRect(find.byIcon(Icons.settings_outlined))
          .width;

      await tester.tap(find.byType(StepCard).first);
      await tester.pumpAndSettle();
      final stageHeader = tester.getRect(find.byType(AppHeader));
      final stageTitle = tester.getRect(find.text('톡톡! 한 음 익히기')).height;
      final stageIcon = tester
          .getRect(find.byIcon(Icons.arrow_back_rounded))
          .width;

      expect(stageHeader.height, closeTo(homeHeader.height, 0.5));
      expect(stageTitle, lessThan(homeTitle));
      expect(stageIcon, closeTo(homeIcon, 0.5));
    });

    testWidgets('1단계와 2단계 메뉴 헤더 구성이 같다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));

      await tester.tap(find.byType(StepCard).first);
      await tester.pumpAndSettle();
      final stageOneTitle = tester.getRect(find.text('톡톡! 한 음 익히기'));
      final stageOneBack = tester.getRect(find.byIcon(Icons.arrow_back_rounded));
      final stageOneNote = tester.getRect(find.byIcon(Icons.music_note_rounded));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(StepCard).at(1));
      await tester.pumpAndSettle();
      final stageTwoTitle = tester.getRect(find.text('AR 톡톡! 한 음 만나기'));
      final stageTwoBack = tester.getRect(find.byIcon(Icons.arrow_back_rounded));
      final stageTwoNote = tester.getRect(find.byIcon(Icons.music_note_rounded));

      expect(stageTwoTitle.height, closeTo(stageOneTitle.height, 1));
      expect(stageTwoTitle.center.dx, closeTo(stageOneTitle.center.dx, 1));
      expect(stageTwoTitle.center.dy, closeTo(stageOneTitle.center.dy, 1));
      expect(stageTwoBack.center.dx, closeTo(stageOneBack.center.dx, 0.5));
      expect(stageTwoBack.center.dy, closeTo(stageOneBack.center.dy, 0.5));
      expect(stageTwoNote.center.dx, closeTo(stageOneNote.center.dx, 0.5));
      expect(stageTwoNote.center.dy, closeTo(stageOneNote.center.dy, 0.5));
    });

    testWidgets('홈에는 나가기 버튼이 없고 스테이지에는 있다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      // 설정 버튼은 남아 있어야 한다.
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      await tester.tap(find.byType(StepCard).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('나가기 버튼이 없어도 제목이 가운데 온다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));

      final header = tester.getRect(find.byType(AppHeader));
      final title = tester.getRect(find.text('너두! 도레미!'));
      expect(title.center.dx, closeTo(header.center.dx, 1));
    });

    testWidgets('가로에서는 헤더가 기본 높이를 유지한다', (tester) async {
      await pumpAppAt(tester, const Size(914, 411));

      final header = tester.getRect(find.byType(AppHeader));
      expect(header.height, closeTo(AppHeader.defaultHeight, 0.5));
    });

    testWidgets('세로에서 고양이와 단계 목록이 한 칸 아래로 내려간다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));

      final header = tester.getRect(find.byType(AppHeader));
      final cat = tester.getRect(find.byType(CatFace));
      // 헤더 바로 아래가 아니라, 카드 한 칸만큼 띄운 자리에서 시작한다.
      expect(cat.top - header.bottom, greaterThan(StepCard.height));
    });
  });

  testWidgets('홈 화면이 렌더링된다', (tester) async {
    await pumpAppAt(tester, const Size(412, 915));

    expect(find.text('너두! 도레미!'), findsOneWidget);
    expect(find.byType(StepCard), findsNWidgets(3));
  });

  testWidgets('2단계 방식 버튼이 메인 카드와 같은 크기다', (tester) async {
    await pumpAppAt(tester, const Size(412, 915));
    final mainCard = tester.getRect(find.byType(StepCard).first);
    final mainTitle = tester.widget<Text>(find.text('톡톡! 한 음 익히기'));
    final mainSecondary = tester.widget<Text>(find.text('1단계'));

    await tester.tap(find.byType(StepCard).at(1));
    await tester.pumpAndSettle();
    final modeButton = tester.getRect(find.byType(ModeButton).first);
    final modeTitle = tester.widget<Text>(find.text('톡톡 Lite'));
    final modeSecondary = tester.widget<Text>(
      find.text('카메라 화면 위에서 한 음 만나기'),
    );

    expect(modeButton.width, closeTo(mainCard.width, 0.5));
    expect(modeButton.height, closeTo(mainCard.height, 0.5));
    expect(modeTitle.style?.fontSize, mainTitle.style?.fontSize);
    expect(modeSecondary.style?.fontSize, mainSecondary.style?.fontSize);
  });

  testWidgets('학습 화면 음표 설정에는 목소리와 스파클 토글만 있다', (tester) async {
    await pumpAppAt(tester, const Size(412, 915));
    await tester.tap(find.byType(StepCard).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.music_note_rounded));
    await tester.pumpAndSettle();

    expect(find.text('목소리'), findsOneWidget);
    expect(find.text('스파클 효과'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(find.byType(RadioListTile<int>), findsNothing);
  });

  testWidgets('태블릿에서 레터박스 없이 화면 폭을 모두 채운다', (tester) async {
    const screen = Size(800, 1280);
    await pumpAppAt(tester, screen);

    // 논리 캔버스 × 배율 = 실제 화면 크기여야 남는 여백이 없다.
    final logical = logicalSizeOf(tester);
    final scale = responsiveScaleFor(screen);
    expect(logical.width * scale, closeTo(screen.width, 0.5));
    expect(logical.height * scale, closeTo(screen.height, 0.5));
  });

  testWidgets('태블릿의 남는 공간이 여백이 아니라 논리 폭으로 환원된다', (tester) async {
    await pumpAppAt(tester, const Size(412, 915));
    final phone = logicalSizeOf(tester);

    await pumpAppAt(tester, const Size(800, 1280));
    final tablet = logicalSizeOf(tester);

    expect(tablet.width, greaterThan(phone.width));
  });

  testWidgets('가로 화면에서는 고양이와 단계 카드가 좌우로 나뉜다', (tester) async {
    await pumpAppAt(tester, const Size(1280, 800));

    expect(find.byType(StepCard), findsNWidgets(3));
    // 좌우 배치이므로 카드가 화면 왼쪽 절반을 넘어선 지점에서 시작한다.
    final card = tester.getRect(find.byType(StepCard).first);
    expect(card.left, greaterThan(1280 * 0.3));
  });

  testWidgets('세로 화면에서는 단계 카드가 세로로 쌓인다', (tester) async {
    await pumpAppAt(tester, const Size(800, 1280));

    final rects = tester
        .widgetList<StepCard>(find.byType(StepCard))
        .map((card) => tester.getRect(find.byWidget(card)))
        .toList();
    expect(rects[0].left, closeTo(rects[1].left, 0.5));
    expect(rects[1].top, greaterThan(rects[0].top));
    expect(rects[2].top, greaterThan(rects[1].top));
  });

  group('톡톡 Lite 카메라', () {
    /// 2단계 → 톡톡 Lite 로 이동한다.
    Future<void> openLite(WidgetTester tester) async {
      await tester.tap(find.byType(StepCard).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('톡톡 Lite'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
    }

    for (final screen in [const Size(412, 915), const Size(1280, 800)]) {
      testWidgets(
        '$screen 에서 초기 건반이 1단계와 같은 크기와 위치다',
        (tester) async {
          await pumpAppAt(tester, screen);
          await tester.tap(find.byType(StepCard).first);
          await tester.pumpAndSettle();
          final stageOneScene = tester.getRect(find.byType(SceneView));

          await pumpAppAt(tester, screen);
          await openLite(tester);
          final liteScene = tester.getRect(find.byType(SceneView));

          expect(liteScene.width, closeTo(stageOneScene.width, 0.5));
          expect(liteScene.height, closeTo(stageOneScene.height, 0.5));
          expect(liteScene.center.dx, closeTo(stageOneScene.center.dx, 0.5));
          expect(liteScene.center.dy, closeTo(stageOneScene.center.dy, 0.5));
        },
      );
    }

    for (final screen in [
      const Size(412, 915),
      const Size(800, 1280),
      const Size(1280, 800),
    ]) {
      testWidgets('$screen 에서 카메라가 화면을 꽉 채운다', (tester) async {
        tester.view.padding = const FakeViewPadding(top: 48);
        await pumpAppAt(tester, screen);
        await openLite(tester);

        expect(find.text('톡톡 Lite'), findsOneWidget);

        // 카메라 레이어 위에 덮이는 딤 레이어가 곧 카메라가 차지한 영역이다.
        // 상태바 영역까지 포함해 화면 전체(0,0 ~ screen)를 덮어야 한다.
        final camera = tester.getRect(find.byType(ColoredBox).last);
        expect(camera.left, closeTo(0, 0.5));
        expect(camera.top, closeTo(0, 0.5));
        expect(camera.width, closeTo(screen.width, 0.5));
        expect(camera.height, closeTo(screen.height, 0.5));

        // 건반·악보 오버레이는 화면 방향에 맞는 장면 비율을 유지한다.
        final expected = screen.width > screen.height
            ? LessonScene.landscapeSize
            : LessonScene.portraitSize;
        final overlay = tester.getRect(find.byType(SceneView));
        expect(
          overlay.width / overlay.height,
          closeTo(expected.width / expected.height, 0.01),
        );
      });
    }

    testWidgets('카메라 모드가 아니면 전체 화면 배경을 쓰지 않는다', (tester) async {
      await pumpAppAt(tester, const Size(412, 915));
      await tester.tap(find.byType(StepCard).first);
      await tester.pumpAndSettle();

      expect(find.text('톡톡! 한 음 익히기'), findsOneWidget);
      expect(find.byType(AppBackground), findsOneWidget);
    });
  });
}
