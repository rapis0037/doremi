import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 현재 UI가 설계된 기준 화면의 짧은 변(dp). 일반적인 폰 세로 폭.
const double kReferenceShortSide = 412;

/// 기준보다 큰 화면에서의 확대 강도. 1이면 화면 크기에 정비례, 0이면 확대하지 않음.
const double _upscaleDamping = 0.8;

/// 태블릿에서 요소가 지나치게 커지지 않도록 하는 상한.
const double _maxScale = 2.0;

/// 화면 크기에 대응하는 UI 배율.
///
/// - 기준(412dp)보다 좁은 화면: 폭에 정비례해 축소해 기존 레이아웃을 유지한다.
/// - 기준보다 넓은 화면(태블릿): 완만하게 확대해 요소를 키우되, 남는 공간은
///   여백이 아니라 논리 크기(= 레이아웃이 쓸 수 있는 dp)로 돌려준다.
double responsiveScaleFor(Size size) {
  final short = size.shortestSide;
  if (short <= 0) return 1;
  final raw = short / kReferenceShortSide;
  if (raw <= 1) return raw;
  return math.min(math.pow(raw, _upscaleDamping).toDouble(), _maxScale);
}

/// 앱 전체를 화면 크기에 맞춰 확대/축소하는 래퍼.
///
/// 화면과 같은 비율의 논리 캔버스를 만들기 때문에 레터박스(빈 여백)가 생기지
/// 않고, 자식 위젯은 확대된 dp 공간을 그대로 사용한다. `MaterialApp.builder`에
/// 설치되어 페이지뿐 아니라 다이얼로그·스낵바까지 같은 배율로 그려진다.
class ResponsiveViewport extends StatelessWidget {
  const ResponsiveViewport({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }
        final media = MediaQuery.of(context);
        final scale = responsiveScaleFor(constraints.biggest);
        if (scale <= 0) return child;
        final logical = constraints.biggest / scale;
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: logical,
            child: MediaQuery(
              data: media.copyWith(
                size: logical,
                padding: media.padding / scale,
                viewPadding: media.viewPadding / scale,
                viewInsets: media.viewInsets / scale,
                systemGestureInsets: media.systemGestureInsets / scale,
                textScaler: TextScaler.noScaling,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
