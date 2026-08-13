import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTrailing,
    this.leading,
    this.onLeading,
    this.height = defaultHeight,
    this.contentScale = 1,
    this.titleColor = const Color(0xff252a2e),
    this.subtitleColor = const Color(0xff687582),
    this.iconColor,
    this.subtitleScale = 1,
    this.contentOffsetY = 0,
    this.contentWidthScale = 1,
  });
  final String title;
  final String subtitle;

  /// 왼쪽 버튼. 없으면 자리만 비워 두어 제목이 가운데를 유지한다.
  final IconData? leading;
  final VoidCallback? onLeading;
  final IconData trailing;
  final VoidCallback onTrailing;

  /// 헤더가 차지하는 높이. 글자·아이콘 크기가 모두 여기에 비례한다.
  final double height;

  /// 높이에서 나온 크기 위에 제목과 아이콘만 더 키우고 싶을 때 쓴다.
  final double contentScale;
  final Color titleColor;
  final Color subtitleColor;
  final Color? iconColor;
  final double subtitleScale;
  final double contentOffsetY;
  final double contentWidthScale;

  /// 기본 높이. 배경 스크림 등 바깥에서 높이를 맞출 때 쓴다.
  static const double defaultHeight = 68;

  /// [contentOffsetY]로 내려 그린 글자가 헤더 상자 아래로 삐져나오는 높이.
  ///
  /// 헤더는 글자를 상자 안에 가두지 않고 [Transform.translate]로 내려 그린다.
  /// 아래에 오는 콘텐츠가 이만큼을 비워 두지 않으면 글자를 덮는다.
  static double contentOverflow({
    required double height,
    double contentScale = 1,
    double contentOffsetY = 0,
    double subtitleScale = 1,
  }) {
    if (contentOffsetY <= 0) return 0;
    final scale = height / defaultHeight;
    // Text 는 글꼴 크기의 약 1.2배 높이를 차지한다.
    final title = 20 * scale * contentScale * 1.2;
    final subtitle = 11 * scale * contentScale * subtitleScale * 1.2;
    final block = title + 2 * scale + subtitle;
    return math.max(0, contentOffsetY + block / 2 - height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final scale = height / defaultHeight;
    final iconSize = 28 * scale * contentScale;
    // 아이콘 자리는 좌우 대칭으로 잡혀야 제목이 가운데 온다. 그만큼 제목이
    // 쓸 폭이 줄어드니 여백은 최소로 둔다.
    final slot = iconSize + 6;

    // 왼쪽 버튼이 없어도 같은 폭을 차지해야 제목이 화면 가운데에 온다.
    Widget iconSlot(IconData? icon, VoidCallback? onPressed, String tooltip) =>
        SizedBox(
          width: slot,
          height: slot,
          child: icon == null
              ? null
              : IconButton(
                  tooltip: tooltip,
                  onPressed: onPressed,
                  padding: EdgeInsets.zero,
                  icon: Icon(icon, size: iconSize, color: iconColor),
                ),
        );

    // 헤더를 키우면 글자가 좌우 아이콘 사이를 넘칠 수 있다. 잘라내는 대신
    // 들어갈 만큼만 줄인다.
    Widget fitted(Widget child) =>
        FittedBox(fit: BoxFit.scaleDown, child: child);

    final content = Transform.translate(
      offset: Offset(0, contentOffsetY),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          fitted(
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20 * scale * contentScale,
                color: titleColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 2 * scale),
          fitted(
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11 * scale * contentScale * subtitleScale,
                color: subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final trailingSlot = Transform.translate(
      offset: Offset(trailing == Icons.settings_outlined ? -5 : 0, -5),
      child: iconSlot(
        trailing,
        onTrailing,
        trailing == Icons.settings_outlined ? '설정' : '음정 소리',
      ),
    );

    return SizedBox(
      height: height,
      child: Row(
        children: [
          iconSlot(leading, onLeading, '뒤로'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth * contentWidthScale;
                return OverflowBox(
                  minWidth: contentWidth,
                  maxWidth: contentWidth,
                  alignment: Alignment.center,
                  child: content,
                );
              },
            ),
          ),
          trailingSlot,
        ],
      ),
    );
  }
}
