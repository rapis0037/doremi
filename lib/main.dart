import 'package:flutter/material.dart';

import 'core/models.dart';
import 'pages/ar_mode_page.dart';
import 'pages/home_page.dart';
import 'pages/lesson_flow_page.dart';
import 'pages/stage_three_flow_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicMvpApp());
}

class MusicMvpApp extends StatelessWidget {
  const MusicMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '너두! 도레미!',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffed4f7f)),
        useMaterial3: true,
      ),
      home: const MusicLearningPage(),
    );
  }
}

class MusicLearningPage extends StatefulWidget {
  const MusicLearningPage({super.key});

  @override
  State<MusicLearningPage> createState() => _MusicLearningPageState();
}

class _MusicLearningPageState extends State<MusicLearningPage> {
  RootPage _page = RootPage.home;
  bool _soundOn = true;

  void _open(RootPage next) => setState(() => _page = next);
  void _setSound(bool value) => setState(() => _soundOn = value);

  @override
  Widget build(BuildContext context) {
    switch (_page) {
      case RootPage.home:
        return HomePage(
          onStageOne: () => _open(RootPage.stageOne),
          onStageTwo: () => _open(RootPage.arModes),
          onStageThree: () => _open(RootPage.stageThree),
        );
      case RootPage.stageOne:
        return LessonFlowPage(
          cameraMode: false,
          soundOn: _soundOn,
          onSoundChanged: _setSound,
          onExit: () => _open(RootPage.home),
        );
      case RootPage.arModes:
        return ArModePage(
          soundOn: _soundOn,
          onSoundChanged: _setSound,
          onBack: () => _open(RootPage.home),
          onLite: () => _open(RootPage.arLite),
        );
      case RootPage.arLite:
        return LessonFlowPage(
          cameraMode: true,
          soundOn: _soundOn,
          onSoundChanged: _setSound,
          onExit: () => _open(RootPage.arModes),
        );
      case RootPage.stageThree:
        return StageThreeFlowPage(
          soundOn: _soundOn,
          onSoundChanged: _setSound,
          onExit: () => _open(RootPage.home),
        );
    }
  }
}
