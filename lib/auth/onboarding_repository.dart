import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_models.dart';

abstract class OnboardingRepository {
  Future<GuardianProfile> loadOrCreate(AuthAccount account);

  Future<GuardianProfile> saveAge(String uid, int age);

  Future<GuardianProfile> saveNickname(String uid, String nickname);

  Future<GuardianProfile> savePreference(
    String uid,
    SensoryPreference preference,
  );

  Future<GuardianProfile> complete(String uid);

  /// 보호자 문서와 그 안의 아이 정보를 지운다. 계정 삭제의 일부라
  /// 인증 계정이 살아 있는 동안(= 규칙이 통과하는 동안) 먼저 호출해야 한다.
  Future<void> deleteProfile(String uid);
}

class FirebaseOnboardingRepository implements OnboardingRepository {
  FirebaseOnboardingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _guardian(String uid) =>
      _firestore.collection('guardians').doc(uid);

  @override
  Future<GuardianProfile> loadOrCreate(AuthAccount account) async {
    final reference = _guardian(account.uid);
    final snapshot = await reference.get();
    final provider = account.provider.name;
    if (!snapshot.exists) {
      await reference.set({
        'authProvider': provider,
        'providerSubject': account.providerSubject,
        'email': account.email,
        'currentStep': OnboardingStep.age.name,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      await reference.set({
        'authProvider': provider,
        'providerSubject': account.providerSubject,
        'email': account.email,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return _read(account.uid);
  }

  @override
  Future<GuardianProfile> saveAge(String uid, int age) async {
    if (age < 2 || age > 20) {
      throw ArgumentError.value(age, 'age', '2세부터 20세까지 입력할 수 있습니다.');
    }
    await _guardian(uid).set({
      'childAge': age,
      'ageReferenceYear': _koreaNow().year,
      'currentStep': OnboardingStep.nickname.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return _read(uid);
  }

  @override
  Future<GuardianProfile> saveNickname(String uid, String nickname) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.runes.length > 12) {
      throw ArgumentError.value(
        nickname,
        'nickname',
        '닉네임은 1자부터 12자까지 입력할 수 있습니다.',
      );
    }
    final snapshot = await _guardian(uid).get();
    final currentStep = _enumByName(
      OnboardingStep.values,
      snapshot.data()?['currentStep'] as String?,
    );
    final nextStep =
        currentStep == null ||
            currentStep == OnboardingStep.age ||
            currentStep == OnboardingStep.nickname
        ? OnboardingStep.preference
        : currentStep;
    await _guardian(uid).set({
      'childNickname': normalized,
      'currentStep': nextStep.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return _read(uid);
  }

  @override
  Future<GuardianProfile> savePreference(
    String uid,
    SensoryPreference preference,
  ) async {
    final settings = LearningSettings.fromPreference(preference);
    await _guardian(uid).set({
      'sensoryPreference': preference.name,
      'sparkleEnabled': settings.sparkleEnabled,
      'solfegeVoiceEnabled': settings.solfegeVoiceEnabled,
      'settingsSource': settings.source,
      'recommendationVersion': '1.1',
      'currentStep': OnboardingStep.confirmation.name,
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return _read(uid);
  }

  @override
  Future<GuardianProfile> complete(String uid) async {
    await _guardian(uid).set({
      'currentStep': OnboardingStep.completed.name,
      'onboardingCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return _read(uid);
  }

  @override
  Future<void> deleteProfile(String uid) => _guardian(uid).delete();

  Future<GuardianProfile> _read(String uid) async {
    final snapshot = await _guardian(uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final preference = _enumByName(
      SensoryPreference.values,
      data['sensoryPreference'] as String?,
    );
    final hasSettings =
        data['sparkleEnabled'] is bool && data['solfegeVoiceEnabled'] is bool;
    return GuardianProfile(
      uid: uid,
      step:
          _enumByName(OnboardingStep.values, data['currentStep'] as String?) ??
          OnboardingStep.age,
      childAge: data['childAge'] as int?,
      ageReferenceYear: data['ageReferenceYear'] as int?,
      childNickname: data['childNickname'] as String?,
      sensoryPreference: preference,
      settings: hasSettings
          ? LearningSettings(
              sparkleEnabled: data['sparkleEnabled'] as bool,
              solfegeVoiceEnabled: data['solfegeVoiceEnabled'] as bool,
              source: data['settingsSource'] as String? ?? 'recommended',
            )
          : preference == null
          ? null
          : LearningSettings.fromPreference(preference),
    );
  }
}

T? _enumByName<T extends Enum>(Iterable<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

DateTime _koreaNow() => DateTime.now().toUtc().add(const Duration(hours: 9));
