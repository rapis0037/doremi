import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../auth/auth_gateway.dart';
import '../auth/auth_models.dart';
import '../auth/onboarding_repository.dart';
import '../widgets/app_background.dart';
import '../widgets/cat_face.dart';

class SignupFlowPage extends StatefulWidget {
  const SignupFlowPage({
    super.key,
    required this.authGateway,
    required this.onboardingRepository,
    required this.onCompleted,
  });

  final AuthGateway authGateway;
  final OnboardingRepository? onboardingRepository;
  final ValueChanged<LearningSettings> onCompleted;

  @override
  State<SignupFlowPage> createState() => _SignupFlowPageState();
}

class _SignupFlowPageState extends State<SignupFlowPage> {
  AuthAccount? _account;
  GuardianProfile? _profile;
  SensoryPreference? _selectedPreference;
  final TextEditingController _nicknameController = TextEditingController();
  int _age = 6;
  bool _busy = false;
  bool _showPreferenceEditor = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _account = widget.authGateway.currentAccount;
    if (_account != null) {
      _loadProfile(_account!);
    }
  }

  Future<void> _loadProfile(AuthAccount account) async {
    final repository = widget.onboardingRepository;
    if (repository == null) {
      setState(() {
        _busy = false;
        _message = 'Firebase 프로젝트 설정이 필요해요.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final profile = await repository.loadOrCreate(account);
      if (!mounted) return;
      _applyProfile(profile);
      final hasNickname = profile.childNickname?.trim().isNotEmpty ?? false;
      if (profile.step == OnboardingStep.completed &&
          profile.settings != null &&
          hasNickname) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCompleted(profile.settings!);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '가입 정보를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.';
      });
    }
  }

  void _applyProfile(GuardianProfile profile) {
    final nickname = profile.childNickname;
    if (nickname != null && _nicknameController.text != nickname) {
      _nicknameController.text = nickname;
    }
    setState(() {
      _profile = profile;
      _age = profile.currentAge() ?? _age;
      _selectedPreference = profile.sensoryPreference;
      _busy = false;
      _message = null;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _signIn(SignInProvider provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final account = await widget.authGateway.signIn(provider);
      if (!mounted) return;
      setState(() => _account = account);
      await _loadProfile(account);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = failure.message;
      });
    }
  }

  Future<void> _saveAge() async {
    final repository = widget.onboardingRepository;
    final account = _account;
    if (repository == null || account == null || _busy) return;
    setState(() => _busy = true);
    try {
      _applyProfile(await repository.saveAge(account.uid, _age));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '나이를 저장하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _savePreference() async {
    final repository = widget.onboardingRepository;
    final account = _account;
    final preference = _selectedPreference;
    if (repository == null || account == null || preference == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _showPreferenceEditor = false;
    });
    try {
      _applyProfile(await repository.savePreference(account.uid, preference));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '설정을 저장하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _saveNickname() async {
    final repository = widget.onboardingRepository;
    final account = _account;
    final nickname = _nicknameController.text.trim();
    if (repository == null || account == null || _busy) return;
    if (nickname.isEmpty || nickname.runes.length > 12) {
      setState(() => _message = '닉네임을 1자부터 12자까지 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final profile = await repository.saveNickname(account.uid, nickname);
      _applyProfile(profile);
      if (profile.step == OnboardingStep.completed &&
          profile.settings != null) {
        widget.onCompleted(profile.settings!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '닉네임을 저장하지 못했어요.\n다시 시도해 주세요.';
      });
    }
  }

  Future<void> _complete() async {
    final repository = widget.onboardingRepository;
    final account = _account;
    if (repository == null || account == null || _busy) return;
    setState(() => _busy = true);
    try {
      final profile = await repository.complete(account.uid);
      if (!mounted) return;
      _applyProfile(profile);
      final settings = profile.settings;
      if (settings != null) widget.onCompleted(settings);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '가입을 완료하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (_account == null) {
      return _WelcomeSignupPage(
        message: _message,
        busy: _busy,
        onSignIn: _signIn,
      );
    }
    if (profile == null) {
      return _SignupScaffold(
        title: '가입 정보를 확인하고 있어요',
        message: _message,
        busy: _busy,
        onRetry: () => _loadProfile(_account!),
        child: const SizedBox.shrink(),
      );
    }
    if (profile.step != OnboardingStep.age &&
        (profile.childNickname == null ||
            profile.childNickname!.trim().isEmpty)) {
      return _nicknamePage();
    }
    if (_showPreferenceEditor || profile.step == OnboardingStep.preference) {
      return _preferencePage();
    }
    return switch (profile.step) {
      OnboardingStep.age => _agePage(),
      OnboardingStep.nickname => _nicknamePage(),
      OnboardingStep.preference => _preferencePage(),
      OnboardingStep.confirmation => _confirmationPage(profile),
      OnboardingStep.completed => _SignupScaffold(
        title: '학습 환경을 준비하고 있어요',
        message: _message,
        busy: true,
        child: const SizedBox.shrink(),
      ),
    };
  }

  Widget _agePage() {
    return _SignupScaffold(
      title: '아이의 나이를\n알려주세요',
      subtitle: '아이의 나이에 맞는\n학습 환경을 준비할게요.',
      message: _message,
      busy: _busy,
      child: Column(
        children: [
          const Text('아이의 나이', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AgeButton(
                label: '한 살 줄이기',
                icon: Icons.remove,
                enabled: !_busy && _age > 2,
                onPressed: () => setState(() => _age--),
              ),
              SizedBox(
                width: 112,
                child: Semantics(
                  liveRegion: true,
                  label: '아이의 나이 $_age세',
                  child: Text(
                    '$_age세',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _AgeButton(
                label: '한 살 늘리기',
                icon: Icons.add,
                enabled: !_busy && _age < 20,
                onPressed: () => setState(() => _age++),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '2세부터 20세까지 선택할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff596775), height: 1.5),
          ),
          const SizedBox(height: 28),
          _PrimaryButton(label: '다음', busy: _busy, onPressed: _saveAge),
        ],
      ),
    );
  }

  Widget _nicknamePage() {
    return _SignupScaffold(
      title: '아이가 사용할\n닉네임을 정해 주세요',
      subtitle: '학습 화면에서 아이를\n이 이름으로 불러줄게요.',
      message: _message,
      busy: _busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '닉네임',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('child-nickname-field'),
            controller: _nicknameController,
            enabled: !_busy,
            autofocus: true,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            maxLength: 12,
            decoration: InputDecoration(
              hintText: '예: 도레미',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onChanged: (_) => setState(() => _message = null),
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 8),
          const Text(
            '한글·영문·숫자로\n12자까지 입력할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff596775), height: 1.5),
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            label: '다음',
            busy: _busy,
            onPressed: _nicknameController.text.trim().isEmpty
                ? null
                : _saveNickname,
          ),
        ],
      ),
    );
  }

  Widget _preferencePage() {
    return _SignupScaffold(
      title: '아이에게 편안한\n학습 방식을 선택해 주세요',
      subtitle: '현재 아이에게 가장 가까운 모습을\n하나 선택해 주세요.',
      message: _message,
      busy: _busy,
      child: Column(
        children: [
          RadioGroup<SensoryPreference>(
            groupValue: _selectedPreference,
            onChanged: (value) {
              if (!_busy) setState(() => _selectedPreference = value);
            },
            child: Column(
              children: [
                for (final option in _preferenceOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RadioListTile<SensoryPreference>(
                      value: option.preference,
                      enabled: !_busy,
                      title: Text(option.label),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _selectedPreference == option.preference
                              ? const Color(0xffed4f7f)
                              : const Color(0xffd8dee4),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _PrimaryButton(
            label: '다음',
            busy: _busy,
            onPressed: _selectedPreference == null ? null : _savePreference,
          ),
        ],
      ),
    );
  }

  Widget _confirmationPage(GuardianProfile profile) {
    final settings = profile.settings;
    if (settings == null) {
      return _SignupScaffold(
        title: '설정을 다시 확인해 주세요',
        message: '저장된 추천 설정을 찾을 수 없어요.',
        onRetry: () => setState(() => _showPreferenceEditor = true),
        child: const SizedBox.shrink(),
      );
    }
    return _SignupScaffold(
      title: '아이에게 맞는 학습 환경을\n준비했어요',
      subtitle: '선택한 내용을 바탕으로\n실제로 저장될 설정이에요.',
      message: _message,
      busy: _busy,
      child: Column(
        children: [
          _SettingResult(label: '스파클 효과', enabled: settings.sparkleEnabled),
          const SizedBox(height: 12),
          _SettingResult(
            label: '계이름 음성',
            enabled: settings.solfegeVoiceEnabled,
          ),
          const SizedBox(height: 20),
          const Text(
            '보호자 설정에서 언제든\n자유롭게 변경할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff596775)),
          ),
          const SizedBox(height: 28),
          _PrimaryButton(label: '이대로 시작하기', busy: _busy, onPressed: _complete),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _showPreferenceEditor = true),
            child: const Text('설정 다시 선택하기'),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSignupPage extends StatelessWidget {
  const _WelcomeSignupPage({
    required this.message,
    required this.busy,
    required this.onSignIn,
  });

  final String? message;
  final bool busy;
  final ValueChanged<SignInProvider> onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 64).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kWelcomeMaxWidth,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '너두! 도레미!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xff241d20),
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '고양이와 함께 시작하는 음악 탐험',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xff687680),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 44),
                          const _CatWelcome(),
                          const SizedBox(height: 40),
                          const Text(
                            '반가워요!',
                            style: TextStyle(
                              color: Color(0xff241d20),
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '보호자 계정을 연결하고\n우리만의 음악 탐험을 시작해요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xff687680),
                              height: 1.45,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 18),
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: const Color(0xffffedf2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          _LoginButtons(busy: busy, onSignIn: onSignIn),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (busy)
              const Positioned(
                top: 12,
                right: 16,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CatWelcome extends StatelessWidget {
  const _CatWelcome();

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    height: 210,
    decoration: BoxDecoration(
      color: const Color(0xfffff0c9),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: const Center(child: CatFace(width: 174)),
  );
}

class _SignupScaffold extends StatelessWidget {
  const _SignupScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.message,
    this.busy = false,
    this.onRetry,
  });

  final String title;
  final String? subtitle;
  final String? message;
  final bool busy;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfffffbfc),
    body: SafeArea(
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // 첫 프레임에는 maxHeight가 0으로 들어와 음수가 된다.
                  minHeight: (constraints.maxHeight - 200).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kFormMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 18),
                          Semantics(
                            liveRegion: true,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xffffedf2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Text(message!, textAlign: TextAlign.center),
                                    if (onRetry != null)
                                      TextButton(
                                        onPressed: onRetry,
                                        child: const Text('다시 시도하기'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (busy)
            const Positioned(
              top: 12,
              right: 16,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
        ],
      ),
    ),
  );
}

class _LoginButtons extends StatelessWidget {
  const _LoginButtons({required this.busy, required this.onSignIn});

  final bool busy;
  final ValueChanged<SignInProvider> onSignIn;

  @override
  Widget build(BuildContext context) {
    final providers = const [SignInProvider.apple, SignInProvider.google];
    return Column(
      children: [
        for (final provider in providers) ...[
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: busy ? null : () => onSignIn(provider),
              style: FilledButton.styleFrom(
                backgroundColor: provider == SignInProvider.apple
                    ? const Color(0xff191919)
                    : Colors.white,
                foregroundColor: provider == SignInProvider.apple
                    ? Colors.white
                    : const Color(0xff2f3135),
                disabledBackgroundColor: provider == SignInProvider.apple
                    ? const Color(0xff777777)
                    : const Color(0xfff2f2f2),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: provider == SignInProvider.google
                      ? const BorderSide(color: Color(0xffd9dde2))
                      : BorderSide.none,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: provider == SignInProvider.apple
                        ? const Icon(Icons.apple, size: 28)
                        : const _GoogleMark(),
                  ),
                  Text(
                    provider == SignInProvider.google
                        ? 'Google로 회원가입'
                        : 'Apple로 회원가입',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 14),
        const Text(
          '계속하면 이용약관과 개인정보처리방침에\n동의하게 됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff687582), height: 1.45),
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 27,
    height: 27,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xffe1e4e8)),
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xff4285f4),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AgeButton extends StatelessWidget {
  const _AgeButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      iconSize: 28,
      constraints: const BoxConstraints.tightFor(width: 52, height: 52),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _SettingResult extends StatelessWidget {
  const _SettingResult({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label ${enabled ? '켜짐' : '꺼짐'}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xffe8f7ed) : const Color(0xfff0f2f4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(enabled ? Icons.check_circle : Icons.cancel_outlined),
            const SizedBox(width: 8),
            Text(
              enabled ? '켜짐' : '꺼짐',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreferenceOption {
  const _PreferenceOption(this.preference, this.label);

  final SensoryPreference preference;
  final String label;
}

const _preferenceOptions = [
  _PreferenceOption(SensoryPreference.calm, '조용하고 차분한 환경에서\n더 편안하게 집중해요.'),
  _PreferenceOption(
    SensoryPreference.voiceOnly,
    '계이름 음성은 좋아하지만,\n반짝이는 화면 효과는 불편해해요.',
  ),
  _PreferenceOption(
    SensoryPreference.visualOnly,
    '화면의 축하 효과는 좋아하지만,\n계이름 음성은 불편해해요.',
  ),
  _PreferenceOption(SensoryPreference.both, '반짝이는 효과와 계이름 음성을\n모두 편안하게 받아들여요.'),
  _PreferenceOption(SensoryPreference.unknown, '아직 잘 모르겠어요.\n끄고 시작할게요.'),
];
