import 'package:doremi/main.dart';
import 'package:doremi/widgets/responsive_viewport.dart';
import 'package:doremi/widgets/step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 기기별 논리 크기와 안전 영역. dpr 1로 두어 논리=물리로 맞춘다.
class _Device {
  const _Device(this.name, this.size, this.topPad, this.bottomPad);
  final String name;
  final Size size;
  final double topPad;
  final double bottomPad;
}

const _iPhone17ProMax = _Device('iPhone 17 Pro Max', Size(440, 956), 59, 34);
const _iPadPro13 = _Device('iPad Pro 13-inch', Size(1032, 1376), 24, 20);

Future<void> _pumpHome(WidgetTester tester, _Device device) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = device.size
    ..padding = FakeViewPadding(
      top: device.topPad,
      bottom: device.bottomPad,
    );
  addTearDown(tester.view.reset);
  // authGateway 를 주지 않으면 로그인 게이트 없이 홈으로 들어간다.
  await tester.pumpWidget(const MusicMvpApp());
  await tester.pumpAndSettle();
}

void main() {
  for (final device in [_iPhone17ProMax, _iPadPro13]) {
    testWidgets('${device.name}: 홈이 스크롤 없이 세 단계를 모두 보여준다', (tester) async {
      await _pumpHome(tester, device);

      expect(find.byType(StepCard), findsNWidgets(3));
      // 홈 세로 배치에는 스크롤이 없어야 한다.
      expect(find.byType(SingleChildScrollView), findsNothing);

      final screen = Rect.fromLTWH(0, 0, device.size.width, device.size.height);
      for (final label in ['1단계', '2단계', '3단계']) {
        final rect = tester.getRect(find.text(label));
        expect(
          screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
          isTrue,
          reason: '$label 카드가 화면 밖으로 나갔다: $rect (화면 $screen)',
        );
      }
    });
  }

  testWidgets('폰에서는 카드가 줄어들지 않는다', (tester) async {
    await _pumpHome(tester, _iPhone17ProMax);

    // ResponsiveViewport 배율만 적용되고 추가 축소는 없어야 한다.
    final scale = responsiveScaleFor(_iPhone17ProMax.size);
    final rendered = tester.getRect(find.byType(StepCard).first).height;

    expect(rendered, closeTo(StepCard.height * scale, 0.5));
  });

  testWidgets('아이패드에서는 넘치는 만큼만 줄여 담는다', (tester) async {
    await _pumpHome(tester, _iPadPro13);

    final scale = responsiveScaleFor(_iPadPro13.size);
    final rendered = tester.getRect(find.byType(StepCard).first).height;

    // 세로가 모자라 축소되지만, 폰보다 작아질 만큼 줄지는 않는다.
    expect(rendered, lessThan(StepCard.height * scale));
    expect(rendered, greaterThan(StepCard.height));
  });
}
