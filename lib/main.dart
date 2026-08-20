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
import 'pages/space_page.dart';
import 'pages/stage_three_flow_page.dart';
import 'subscription/entitlement.dart';
import 'subscription/subscription_backend.dart';
import 'subscription/subscription_controller.dart';
import 'subscription/trial_period.dart';
import 'widgets/responsive_viewport.dart';
import 'widgets/dialogs/main_settings_dialog.dart';

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
        // 로그인을 거친 앱에서는 계정 정보를 못 읽더라도 학습 콘텐츠가
        // 그냥 열려서는 안 된다.
        requiresPremium: true,
        onSignOut: _signOut,
        onDeleteAccount: _deleteAccount,
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
    await _clearLocalState();
  }

  Future<void> _deleteAccount() async {
    final account = widget.authGateway.currentAccount;
    final repository = widget.onboardingRepository;
    // 저장된 아이 정보를 먼저 지운다. 인증 계정이 사라진 뒤에는 보안 규칙이
    // 문서 삭제를 막아 데이터만 남는다.
    if (account != null && repository != null) {
      await repository.deleteProfile(account.uid);
    }
    await widget.authGateway.deleteAccount();
    await _clearLocalState();
  }

  Future<void> _clearLocalState() async {
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
    this.requiresPremium = false,
    this.onSignOut,
    this.onDeleteAccount,
  });

  final SharedPreferences? preferences;
  final AuthAccount? account;
  final GuardianProfile? profile;

  /// 유료 콘텐츠를 구독·무료 체험으로만 열지 여부. 로그인 없이 띄우는
  /// 테스트·데모 실행에서만 false 다.
  final bool requiresPremium;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onDeleteAccount;

  @override
  State<MusicLearningPage> createState() => _MusicLearningPageState();
}

class _MusicLearningPageState extends State<MusicLearningPage> {
  RootPage _page = RootPage.home;
  SubscriptionController? _subscriptionController;
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
    _configureSubscription();
  }

  @override
  void didUpdateWidget(covariant MusicLearningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account?.uid != widget.account?.uid ||
        oldWidget.account?.createdAt != widget.account?.createdAt) {
      _configureSubscription();
    }
  }

  void _configureSubscription() {
    _subscriptionController?.removeListener(_refreshSubscription);
    _subscriptionController?.dispose();
    if (!widget.requiresPremium) {
      _subscriptionController = null;
      return;
    }
    // 계정 생성 시각(Firebase metadata)은 비어 올 수 있다. 그때 컨트롤러를
    // 만들지 않으면 유료 콘텐츠가 통째로 열리므로, 기기에 남겨 둔 첫 실행
    // 시각으로 체험 시작일을 정한다.
    final createdAt = earliestTrialStart(
      _deviceFirstSeenAt(),
      widget.account?.createdAt,
    );
    final uid = widget.account?.uid;
    final controller = SubscriptionController(
      accountCreatedAt: createdAt,
      // 서버가 스토어에 확인한 결과로만 유료 잠금을 연다. Firebase 가 붙지
      // 않은 실행에서는 스토어 응답만 보고 판단한다.
      backend: uid != null && Firebase.apps.isNotEmpty
          ? FirebaseSubscriptionBackend(uid: uid)
          : null,
      accountToken: uid == null ? null : accountTokenFor(uid),
      preferences: widget.preferences,
      entitlementKey: uid,
    );
    _subscriptionController = controller;
    controller.addListener(_refreshSubscription);
    controller.initialize();
  }

  /// 이 기기에서 앱을 처음 켠 시각. 로그아웃·탈퇴로 지우지 않아, 재가입해도
  /// 체험 기간이 다시 시작되지 않는다.
  DateTime _deviceFirstSeenAt() {
    final preferences = widget.preferences;
    final stored = preferences?.getInt('trial_started_at');
    if (stored != null) return DateTime.fromMillisecondsSinceEpoch(stored);
    final now = DateTime.now();
    preferences?.setInt('trial_started_at', now.millisecondsSinceEpoch);
    return now;
  }

  void _refreshSubscription() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscriptionController?.removeListener(_refreshSubscription);
    _subscriptionController?.dispose();
    super.dispose();
  }

  void _open(RootPage next) => setState(() => _page = next);

  void _openPremiumContent(RootPage next) {
    final subscription = _subscriptionController;
    // 컨트롤러가 없는 경우는 유료 잠금을 쓰지 않는 실행뿐이다.
    if (subscription == null || subscription.hasPremiumAccess) {
      _open(next);
      return;
    }
    showSubscriptionManagement(context, subscription: subscription);
  }

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
    if (_page == RootPage.arLite || _page == RootPage.arSpace) {
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
            onStageOne: () => _openPremiumContent(RootPage.stageOne),
            onStageTwo: () => _openPremiumContent(RootPage.arModes),
            onStageThree: () => _openPremiumContent(RootPage.stageThree),
            voiceOn: _voiceOn,
            sparklesOn: _sparklesOn,
            onVoiceChanged: _setVoice,
            onSparklesChanged: _setSparkles,
            account: widget.account,
            profile: widget.profile,
            subscription: _subscriptionController,
            onSignOut: widget.onSignOut,
            onDeleteAccount: widget.onDeleteAccount,
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
            onSpace: () => _open(RootPage.arSpace),
          ),
        );
      case RootPage.arSpace:
        return _withSystemBackHandler(
          SpacePage(onExit: () => _open(RootPage.arModes)),
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
