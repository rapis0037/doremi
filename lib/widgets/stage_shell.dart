import 'package:flutter/material.dart';

import 'app_background.dart';
import 'app_header.dart';
import 'dialogs/sound_settings_dialog.dart';
import 'scene_view.dart';

class StageShell extends StatelessWidget {
  const StageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.soundOn,
    required this.onSoundChanged,
    required this.onBack,
    required this.child,
    this.backdrop,
    this.headerHeight = AppHeader.defaultHeight,
    this.headerContentScale = 1,
    this.headerContentOffsetY = 0,
    this.headerContentWidthScale = 1,
    this.headerTitleColor = const Color(0xff252a2e),
    this.headerSubtitleColor = const Color(0xff687582),
    this.headerIconColor,
    this.headerSubtitleScale = 1,
    this.sparklesOn,
    this.onSparklesChanged,
  });
  final String title;
  final String subtitle;
  final bool soundOn;
  final ValueChanged<bool> onSoundChanged;
  final VoidCallback onBack;
  final Widget child;

  /// 상태바 영역까지 포함해 화면 전체를 채우는 배경(예: 카메라 프리뷰).
  /// 지정하면 기본 그라데이션 배경 대신 사용된다.
  final Widget? backdrop;
  final double headerHeight;
  final double headerContentScale;
  final double headerContentOffsetY;
  final double headerContentWidthScale;
  final Color headerTitleColor;
  final Color headerSubtitleColor;
  final Color? headerIconColor;
  final double headerSubtitleScale;
  final bool? sparklesOn;
  final ValueChanged<bool>? onSparklesChanged;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      // 상단 상태 표시줄은 피하되, 하단 내비게이션 바 때문에 콘텐츠를
      // 위로 밀어 올리는 패딩은 사용하지 않는다.
      bottom: false,
      child: Column(
        children: [
          AppHeader(
            title: title,
            subtitle: subtitle,
            leading: Icons.arrow_back_rounded,
            onLeading: onBack,
            height: headerHeight,
            contentScale: headerContentScale,
            contentOffsetY: headerContentOffsetY,
            contentWidthScale: headerContentWidthScale,
            titleColor: headerTitleColor,
            subtitleColor: headerSubtitleColor,
            iconColor: headerIconColor,
            subtitleScale: headerSubtitleScale,
            trailing: Icons.music_note_rounded,
            onTrailing: () => showSoundSettings(
              context,
              value: soundOn,
              onChanged: onSoundChanged,
              sparklesOn: sparklesOn,
              onSparklesChanged: onSparklesChanged,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: StageInsets(
                top: AppHeader.contentOverflow(
                  height: headerHeight,
                  contentScale: headerContentScale,
                  contentOffsetY: headerContentOffsetY,
                  subtitleScale: headerSubtitleScale,
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: backdrop == null
          ? AppBackground(child: content)
          : Stack(
              fit: StackFit.expand,
              children: [backdrop!, const _HeaderScrim(), content],
            ),
    );
  }
}

/// 카메라 위에서도 헤더 글자가 읽히도록 상단에만 깔아 주는 밝은 그라데이션.
class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height:
              MediaQuery.of(context).padding.top + AppHeader.defaultHeight + 16,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xf5fff8fb),
                  Color(0xd9fff8fb),
                  Color(0x00fff8fb),
                ],
                stops: [0, 0.6, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
