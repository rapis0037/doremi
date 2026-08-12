import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_gateway.dart';
import '../auth/auth_models.dart';
import '../auth/onboarding_repository.dart';

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
      if (profile.step == OnboardingStep.completed &&
          profile.settings != null) {
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
    setState(() {
      _profile = profile;
      _age = profile.currentAge() ?? _age;
      _selectedPreference = profile.sensoryPreference;
      _busy = false;
      _message = null;
    });
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
      return _SignupScaffold(
        title: '너두! 도레미 시작하기',
        subtitle: '보호자 계정으로 간편하게 시작해 주세요.',
        message: _message,
        busy: _busy,
        child: _LoginButtons(busy: _busy, onSignIn: _signIn),
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
    if (_showPreferenceEditor || profile.step == OnboardingStep.preference) {
      return _preferencePage();
    }
    return switch (profile.step) {
      OnboardingStep.age => _agePage(),
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
      title: '아이의 나이를 알려주세요',
      subtitle: '아이의 나이에 맞는 학습 환경을 준비할게요.',
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

  Widget _preferencePage() {
    return _SignupScaffold(
      title: '아이에게 편안한 학습 방식을 선택해 주세요',
      subtitle: '현재 아이에게 가장 가까운 모습을 하나 선택해 주세요.',
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
      title: '아이에게 맞는 학습 환경을 준비했어요',
      subtitle: '선택한 내용을 바탕으로 실제 저장될 설정이에요.',
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
            '보호자 설정에서 언제든 자유롭게 변경할 수 있어요.',
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
                  minHeight: constraints.maxHeight - 200,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
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
    final providers = !kIsWeb && Platform.isIOS
        ? const [SignInProvider.apple, SignInProvider.google]
        : const [SignInProvider.google, SignInProvider.apple];
    return Column(
      children: [
        for (final provider in providers) ...[
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: busy ? null : () => onSignIn(provider),
              icon: Icon(
                provider == SignInProvider.google
                    ? Icons.g_mobiledata_rounded
                    : Icons.apple,
                size: 30,
              ),
              label: Text(
                provider == SignInProvider.google
                    ? 'Google로 계속하기'
                    : 'Apple로 계속하기',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 14),
        const Text(
          '계속하면 이용약관과 개인정보처리방침에 동의하게 됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff687582), height: 1.45),
        ),
      ],
    );
  }
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
  _PreferenceOption(SensoryPreference.calm, '조용하고 차분한 환경에서 더 편안하게 집중해요.'),
  _PreferenceOption(
    SensoryPreference.voiceOnly,
    '계이름 음성은 좋아하지만, 반짝이는 화면 효과는 불편해해요.',
  ),
  _PreferenceOption(
    SensoryPreference.visualOnly,
    '화면의 축하 효과는 좋아하지만, 계이름 음성은 불편해해요.',
  ),
  _PreferenceOption(SensoryPreference.both, '반짝이는 효과와 계이름 음성을 모두 편안하게 받아들여요.'),
  _PreferenceOption(SensoryPreference.unknown, '아직 잘 모르겠어요. 끄고 시작할게요.'),
];
