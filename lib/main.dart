import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_gateway.dart';
import 'auth/auth_models.dart';
import 'auth/onboarding_repository.dart';
import 'core/models.dart';
import 'firebase_options.dart';
import 'pages/ar_mode_page.dart';
import 'pages/home_page.dart';
import 'pages/lesson_flow_page.dart';
import 'pages/signup_flow_page.dart';
import 'pages/sensory_setup_page.dart';
import 'pages/stage_three_flow_page.dart';
import 'widgets/responsive_viewport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  late final AuthGateway authGateway;
  OnboardingRepository? onboardingRepository;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    authGateway = FirebaseAuthGateway();
    onboardingRepository = FirebaseOnboardingRepository();
  } catch (_) {
    authGateway = const UnavailableAuthGateway(
      '로그인 서비스 연결이 완료되지 않았어요. Firebase 앱 설정을 확인해 주세요.',
    );
  }
  runApp(
    MusicMvpApp(
      preferences: preferences,
      authGateway: authGateway,
      onboardingRepository: onboardingRepository,
    ),
  );
}

class MusicMvpApp extends StatelessWidget {
  const MusicMvpApp({
    super.key,
    this.preferences,
    this.authGateway,
    this.onboardingRepository,
  });

  final SharedPreferences? preferences;
  final AuthGateway? authGateway;
  final OnboardingRepository? onboardingRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '너두! 도레미!',
      theme: ThemeData(
        fontFamily: 'NanumGothic',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffed4f7f)),
        useMaterial3: true,
      ),
      // 페이지뿐 아니라 다이얼로그·스낵바까지 같은 배율을 적용하기 위해
      // Navigator 바깥이 아닌 builder 단계에서 감싼다.
      builder: (context, child) =>
          ResponsiveViewport(child: child ?? const SizedBox.shrink()),
      home: authGateway == null
          ? MusicLearningPage(preferences: preferences)
          : _AuthenticatedEntry(
              preferences: preferences,
              authGateway: authGateway!,
              onboardingRepository: onboardingRepository,
            ),
    );
  }
}

class _AuthenticatedEntry extends StatefulWidget {
  const _AuthenticatedEntry({
    required this.preferences,
    required this.authGateway,
    required this.onboardingRepository,
  });

  final SharedPreferences? preferences;
  final AuthGateway authGateway;
  final OnboardingRepository? onboardingRepository;

  @override
  State<_AuthenticatedEntry> createState() => _AuthenticatedEntryState();
}

class _AuthenticatedEntryState extends State<_AuthenticatedEntry> {
  bool _onboardingComplete = false;
  GuardianProfile? _profile;

  void _finishOnboarding(LearningSettings settings) {
    widget.preferences?.setBool('voice_on', settings.solfegeVoiceEnabled);
    widget.preferences?.setBool('sparkles_on', settings.sparkleEnabled);
    widget.preferences?.setBool('sensory_setup_complete', true);
    if (mounted) setState(() => _onboardingComplete = true);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final account = widget.authGateway.currentAccount;
    final repository = widget.onboardingRepository;
    if (account == null || repository == null) return;
    try {
      final profile = await repository.loadOrCreate(account);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // 프로필 표시 실패가 학습 화면 진입을 막지 않게 한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete) {
      return MusicLearningPage(
        preferences: widget.preferences,
        account: widget.authGateway.currentAccount,
        profile: _profile,
        onSignOut: _signOut,
      );
    }
    return SignupFlowPage(
      authGateway: widget.authGateway,
      onboardingRepository: widget.onboardingRepository,
      onCompleted: _finishOnboarding,
    );
  }

  Future<void> _signOut() async {
    await widget.authGateway.signOut();
    await widget.preferences?.remove('voice_on');
    await widget.preferences?.remove('sparkles_on');
    await widget.preferences?.remove('sensory_setup_complete');
    if (mounted) {
      setState(() {
        _profile = null;
        _onboardingComplete = false;
      });
    }
  }
}

class MusicLearningPage extends StatefulWidget {
  const MusicLearningPage({
    super.key,
    this.preferences,
    this.account,
    this.profile,
    this.onSignOut,
  });

  final SharedPreferences? preferences;
  final AuthAccount? account;
  final GuardianProfile? profile;
  final Future<void> Function()? onSignOut;

  @override
  State<MusicLearningPage> createState() => _MusicLearningPageState();
}

class _MusicLearningPageState extends State<MusicLearningPage> {
  RootPage _page = RootPage.home;
  late bool _voiceOn;
  late bool _sparklesOn;
  late bool _needsSensorySetup;

  @override
  void initState() {
    super.initState();
    _voiceOn = widget.preferences?.getBool('voice_on') ?? false;
    _sparklesOn = widget.preferences?.getBool('sparkles_on') ?? false;
    _needsSensorySetup =
        widget.preferences != null &&
        !(widget.preferences!.getBool('sensory_setup_complete') ?? false);
  }

  void _open(RootPage next) => setState(() => _page = next);
  void _setVoice(bool value) {
    setState(() => _voiceOn = value);
    widget.preferences?.setBool('voice_on', value);
  }

  void _setSparkles(bool value) {
    setState(() => _sparklesOn = value);
    widget.preferences?.setBool('sparkles_on', value);
  }

  void _finishSensorySetup(SensoryChoice choice) {
    setState(() {
      _voiceOn = choice.voiceOn;
      _sparklesOn = choice.sparklesOn;
      _needsSensorySetup = false;
    });
    widget.preferences?.setBool('voice_on', choice.voiceOn);
    widget.preferences?.setBool('sparkles_on', choice.sparklesOn);
    widget.preferences?.setBool('sensory_setup_complete', true);
  }

  void _handleSystemBack() {
    if (_page == RootPage.arLite) {
      _open(RootPage.arModes);
    } else if (_page != RootPage.home) {
      _open(RootPage.home);
    }
  }

  Widget _withSystemBackHandler(Widget child) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handleSystemBack();
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (_needsSensorySetup) {
      return _withSystemBackHandler(
        SensorySetupPage(onSelected: _finishSensorySetup),
      );
    }
    switch (_page) {
      case RootPage.home:
        return _withSystemBackHandler(
          HomePage(
            onStageOne: () => _open(RootPage.stageOne),
            onStageTwo: () => _open(RootPage.arModes),
            onStageThree: () => _open(RootPage.stageThree),
            voiceOn: _voiceOn,
            sparklesOn: _sparklesOn,
            onVoiceChanged: _setVoice,
            onSparklesChanged: _setSparkles,
            account: widget.account,
            profile: widget.profile,
            onSignOut: widget.onSignOut,
          ),
        );
      case RootPage.stageOne:
        return _withSystemBackHandler(
          LessonFlowPage(
            cameraMode: false,
            soundOn: _voiceOn,
            onSoundChanged: _setVoice,
            sparklesOn: _sparklesOn,
            onSparklesChanged: _setSparkles,
            onExit: () => _open(RootPage.home),
          ),
        );
      case RootPage.arModes:
        return _withSystemBackHandler(
          ArModePage(
            soundOn: _voiceOn,
            onSoundChanged: _setVoice,
            onBack: () => _open(RootPage.home),
            onLite: () => _open(RootPage.arLite),
          ),
        );
      case RootPage.arLite:
        return _withSystemBackHandler(
          LessonFlowPage(
            cameraMode: true,
            soundOn: _voiceOn,
            onSoundChanged: _setVoice,
            sparklesOn: _sparklesOn,
            onSparklesChanged: _setSparkles,
            onExit: () => _open(RootPage.arModes),
          ),
        );
      case RootPage.stageThree:
        return _withSystemBackHandler(
          StageThreeFlowPage(
            soundOn: _voiceOn,
            onSoundChanged: _setVoice,
            onExit: () => _open(RootPage.home),
          ),
        );
    }
  }
}
