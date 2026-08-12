enum SignInProvider { google, apple }

class AuthAccount {
  const AuthAccount({
    required this.uid,
    required this.provider,
    required this.providerSubject,
    this.email,
  });

  final String uid;
  final SignInProvider provider;
  final String providerSubject;
  final String? email;
}

enum AuthFailureKind {
  canceled,
  network,
  accountConflict,
  configuration,
  disabled,
  provider,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind, this.message);

  final AuthFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

enum SensoryPreference { calm, voiceOnly, visualOnly, both, unknown }

enum OnboardingStep { age, nickname, preference, confirmation, completed }

class LearningSettings {
  const LearningSettings({
    required this.sparkleEnabled,
    required this.solfegeVoiceEnabled,
    required this.source,
  });

  final bool sparkleEnabled;
  final bool solfegeVoiceEnabled;
  final String source;

  static LearningSettings fromPreference(SensoryPreference preference) {
    return switch (preference) {
      SensoryPreference.calm => const LearningSettings(
        sparkleEnabled: false,
        solfegeVoiceEnabled: false,
        source: 'recommended',
      ),
      SensoryPreference.voiceOnly => const LearningSettings(
        sparkleEnabled: false,
        solfegeVoiceEnabled: true,
        source: 'recommended',
      ),
      SensoryPreference.visualOnly => const LearningSettings(
        sparkleEnabled: true,
        solfegeVoiceEnabled: false,
        source: 'recommended',
      ),
      SensoryPreference.both => const LearningSettings(
        sparkleEnabled: true,
        solfegeVoiceEnabled: true,
        source: 'recommended',
      ),
      SensoryPreference.unknown => const LearningSettings(
        sparkleEnabled: false,
        solfegeVoiceEnabled: false,
        source: 'default',
      ),
    };
  }
}

class GuardianProfile {
  const GuardianProfile({
    required this.uid,
    required this.step,
    this.childAge,
    this.ageReferenceYear,
    this.childNickname,
    this.sensoryPreference,
    this.settings,
  });

  final String uid;
  final OnboardingStep step;
  final int? childAge;
  final int? ageReferenceYear;
  final String? childNickname;
  final SensoryPreference? sensoryPreference;
  final LearningSettings? settings;

  int? currentAge({DateTime? now}) {
    if (childAge == null || ageReferenceYear == null) return null;
    final reference =
        now ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    return childAge! + reference.year - ageReferenceYear!;
  }
}
