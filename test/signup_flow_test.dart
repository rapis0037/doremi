import 'package:doremi/auth/auth_gateway.dart';
import 'package:doremi/auth/auth_models.dart';
import 'package:doremi/auth/onboarding_repository.dart';
import 'package:doremi/pages/signup_flow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown preference starts with both effects off', () {
    final settings = LearningSettings.fromPreference(SensoryPreference.unknown);

    expect(settings.sparkleEnabled, isFalse);
    expect(settings.solfegeVoiceEnabled, isFalse);
    expect(settings.source, 'default');
  });

  test('age increases once per reference year', () {
    const profile = GuardianProfile(
      uid: 'guardian-1',
      step: OnboardingStep.preference,
      childAge: 6,
      ageReferenceYear: 2026,
    );

    expect(profile.currentAge(now: DateTime.utc(2026, 12, 31)), 6);
    expect(profile.currentAge(now: DateTime.utc(2027, 1, 1)), 7);
  });

  testWidgets('Google login continues to the age screen', (tester) async {
    final gateway = _FakeAuthGateway();
    final repository = _FakeOnboardingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SignupFlowPage(
          authGateway: gateway,
          onboardingRepository: repository,
          onCompleted: (_) {},
        ),
      ),
    );

    expect(find.text('Google로 계속하기'), findsOneWidget);
    await tester.tap(find.text('Google로 계속하기'));
    await tester.pumpAndSettle();

    expect(find.text('아이의 나이를 알려주세요'), findsOneWidget);
    expect(find.text('6세'), findsOneWidget);
    expect(gateway.lastProvider, SignInProvider.google);
  });

  testWidgets('preference page includes the agreed unknown copy', (
    tester,
  ) async {
    final gateway = _FakeAuthGateway(signedIn: true);
    final repository = _FakeOnboardingRepository(
      initialStep: OnboardingStep.preference,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SignupFlowPage(
          authGateway: gateway,
          onboardingRepository: repository,
          onCompleted: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 잘 모르겠어요. 끄고 시작할게요.'), findsOneWidget);
  });
}

const _account = AuthAccount(
  uid: 'guardian-1',
  provider: SignInProvider.google,
  providerSubject: 'google-subject',
  email: 'guardian@example.com',
);

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.signedIn = false});

  final bool signedIn;
  SignInProvider? lastProvider;

  @override
  AuthAccount? get currentAccount => signedIn ? _account : null;

  @override
  Future<AuthAccount> signIn(SignInProvider provider) async {
    lastProvider = provider;
    return _account;
  }

  @override
  Future<void> signOut() async {}
}

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({this.initialStep = OnboardingStep.age});

  final OnboardingStep initialStep;

  @override
  Future<GuardianProfile> loadOrCreate(AuthAccount account) async {
    return GuardianProfile(uid: account.uid, step: initialStep);
  }

  @override
  Future<GuardianProfile> saveAge(String uid, int age) async {
    return GuardianProfile(
      uid: uid,
      step: OnboardingStep.preference,
      childAge: age,
      ageReferenceYear: 2026,
    );
  }

  @override
  Future<GuardianProfile> savePreference(
    String uid,
    SensoryPreference preference,
  ) async {
    return GuardianProfile(
      uid: uid,
      step: OnboardingStep.confirmation,
      sensoryPreference: preference,
      settings: LearningSettings.fromPreference(preference),
    );
  }

  @override
  Future<GuardianProfile> complete(String uid) async {
    return GuardianProfile(
      uid: uid,
      step: OnboardingStep.completed,
      settings: LearningSettings.fromPreference(SensoryPreference.unknown),
    );
  }
}
