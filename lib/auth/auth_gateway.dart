import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_models.dart';

abstract class AuthGateway {
  AuthAccount? get currentAccount;

  Future<AuthAccount> signIn(SignInProvider provider);

  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  bool _googleInitialized = false;

  @override
  AuthAccount? get currentAccount =>
      _accountFromUser(_firebaseAuth.currentUser);

  @override
  Future<AuthAccount> signIn(SignInProvider provider) async {
    try {
      final credential = switch (provider) {
        SignInProvider.google => await _signInWithGoogle(),
        SignInProvider.apple => await _signInWithApple(),
      };
      final account = _accountFromUser(credential.user);
      if (account == null) {
        throw const AuthFailure(
          AuthFailureKind.provider,
          '로그인 정보를 확인할 수 없어요. 다시 시도해 주세요.',
        );
      }
      return account;
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw _fromGoogleError(error);
    } on FirebaseAuthException catch (error) {
      throw _fromFirebaseError(error);
    } on SocketException {
      throw const AuthFailure(
        AuthFailureKind.network,
        '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
      );
    } catch (_) {
      throw const AuthFailure(
        AuthFailureKind.unknown,
        '지금은 로그인을 완료할 수 없어요. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  Future<UserCredential> _signInWithGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<UserCredential> _signInWithApple() {
    return _firebaseAuth.signInWithProvider(AppleAuthProvider());
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      if (_googleInitialized) GoogleSignIn.instance.signOut(),
    ]);
  }

  AuthAccount? _accountFromUser(User? user) {
    if (user == null) return null;
    final supported = user.providerData.where(
      (identity) =>
          identity.providerId == 'google.com' ||
          identity.providerId == 'apple.com',
    );
    if (supported.isEmpty) return null;
    final identity = supported.first;
    return AuthAccount(
      uid: user.uid,
      provider: identity.providerId == 'apple.com'
          ? SignInProvider.apple
          : SignInProvider.google,
      providerSubject: identity.uid ?? user.uid,
      email: identity.email ?? user.email,
    );
  }

  AuthFailure _fromGoogleError(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => const AuthFailure(
        AuthFailureKind.canceled,
        '로그인이 취소되었어요. 준비되면 다시 시도해 주세요.',
      ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError => const AuthFailure(
        AuthFailureKind.configuration,
        'Google 로그인 설정이 완료되지 않았어요.',
      ),
      _ => const AuthFailure(
        AuthFailureKind.provider,
        '지금은 Google 로그인을 완료할 수 없어요. 잠시 후 다시 시도해 주세요.',
      ),
    };
  }

  AuthFailure _fromFirebaseError(FirebaseAuthException error) {
    return switch (error.code) {
      'network-request-failed' => const AuthFailure(
        AuthFailureKind.network,
        '인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
      ),
      'account-exists-with-different-credential' => const AuthFailure(
        AuthFailureKind.accountConflict,
        '같은 이메일의 계정이 있어요. 기존 로그인 방법으로 본인 확인해 주세요.',
      ),
      'user-disabled' => const AuthFailure(
        AuthFailureKind.disabled,
        '현재 사용할 수 없는 계정이에요. 고객지원에 문의해 주세요.',
      ),
      'operation-not-allowed' ||
      'invalid-api-key' ||
      'app-not-authorized' => const AuthFailure(
        AuthFailureKind.configuration,
        '로그인 서비스 설정이 완료되지 않았어요.',
      ),
      'web-context-cancelled' || 'popup-closed-by-user' => const AuthFailure(
        AuthFailureKind.canceled,
        '로그인이 취소되었어요. 준비되면 다시 시도해 주세요.',
      ),
      _ => const AuthFailure(
        AuthFailureKind.provider,
        '지금은 로그인을 완료할 수 없어요. 잠시 후 다시 시도해 주세요.',
      ),
    };
  }
}

class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway(this.reason);

  final String reason;

  @override
  AuthAccount? get currentAccount => null;

  @override
  Future<AuthAccount> signIn(SignInProvider provider) {
    throw AuthFailure(AuthFailureKind.configuration, reason);
  }

  @override
  Future<void> signOut() async {}
}
