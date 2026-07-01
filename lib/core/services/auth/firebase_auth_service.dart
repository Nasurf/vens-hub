import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'auth_service.dart';
import 'dart:developer' as developer;
import 'package:google_sign_in/google_sign_in.dart' as gsi;

class FirebaseAuthService implements AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth;
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;

  FirebaseAuthService({fb_auth.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance;

  static bool _googleInitialized = false;
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await gsi.GoogleSignIn.instance.initialize();
    } catch (_) {
      // Ignore repeated init or platform-specific behavior
    }
    _googleInitialized = true;
  }

  @override
  Stream<fb_auth.User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  fb_auth.User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<String> getIdToken({bool forceRefresh = true}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthenticationException(message: 'No user signed in.');
    }
    final String? token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw AuthenticationException(message: 'Failed to get ID token.');
    }
    return token;
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final trace = kIsWeb ? null : _performance?.newTrace('auth_reauthenticate');
    await trace?.start();
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthenticationException(message: 'No user signed in.');
      }
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw AuthenticationException(
          message: 'Current user has no email for reauthentication.',
        );
      }
      final credential = fb_auth.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'Failed to reauthenticate. Please try again.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    // Disabled per product requirement: password-only reauthentication
    throw AuthenticationException(
      message: 'Please reauthenticate with your password to continue.',
    );
  }

  @override
  Future<fb_auth.User?> getCurrentFirebaseUser() async {
    return _firebaseAuth.currentUser;
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw AuthenticationException(message: 'No user signed in.');
    }
    try {
      await user.reload();
    } on fb_auth.FirebaseAuthException catch (e) {
      final mapped = _mapFirebaseAuthException(e);
      if (mapped is NetworkException) {
        throw NetworkException(
          message:
              'We could not reach the server. Please check your internet connection and try again.',
        );
      }
      if (mapped is AuthenticationException) {
        throw mapped;
      }
      throw AuthenticationException(
        message:
            e.message ?? 'Failed to refresh your account. Please try again.',
      );
    } catch (_) {
      throw AuthenticationException(
        message: 'Failed to refresh your account. Please try again.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('auth_sendEmailVerification');
    await trace?.start();
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthenticationException(message: 'No user signed in.');
      }
      if (kIsWeb) {
        // Redirect users back to the public /verify landing path on the site.
        // Ensure this domain is in Firebase Auth Authorized Domains.
        const continueUrl = 'https://engineeringhub.nuesaabuad.ng/verify';
        final actionCodeSettings = fb_auth.ActionCodeSettings(
          url: continueUrl,
          // Let Firebase handle verification in the browser, then redirect.
          handleCodeInApp: false,
        );
        await user.sendEmailVerification(actionCodeSettings);
      } else {
        await user.sendEmailVerification();
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'Failed to send verification email.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<bool> isEmailVerified() async {
    await reloadCurrentUser();
    final refreshedUser = _firebaseAuth.currentUser;
    if (refreshedUser == null) {
      throw AuthenticationException(message: 'No user signed in.');
    }
    return refreshedUser.emailVerified;
  }

  @override
  Future<void> forgotPassword() async {
    // This is a placeholder. You might want to pass email as parameter
    throw UnimplementedError('forgotPassword needs to be implemented');
  }

  @override
  Future<fb_auth.User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('auth_signInWithEmailAndPassword');
    await trace?.start();
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      trace?.putAttribute('success', 'true');
      return userCredential.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      switch (e.code) {
        case 'user-not-found':
          throw UserNotFoundException(
            message: 'No user found with this email.',
          );
        case 'wrong-password':
          throw WrongPasswordException(message: 'Incorrect password.');
        case 'user-disabled':
          throw UserDisabledException(
            message: 'This user account has been disabled.',
          );
        case 'invalid-email':
          throw InvalidEmailException(message: 'The email address is invalid.');
        case 'network-request-failed':
          throw NetworkException(
            message: 'Network error. Please check your connection.',
          );
        case 'too-many-requests':
          throw AuthenticationException(
            message: 'Too many attempts. Please try again later.',
          );
        default:
          throw AuthenticationException(
            message:
                e.message ??
                'Sign in failed: An unexpected Firebase error occurred.',
          );
      }
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'An unknown error occurred during sign in.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<fb_auth.User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final trace = _performance?.newTrace('auth_signUpWithEmailAndPassword');
    await trace?.start();
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      trace?.putAttribute('success', 'true');
      return userCredential.user;
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      switch (e.code) {
        case 'weak-password':
          throw WeakPasswordException(
            message:
                'The password is too weak. Please use a stronger password.',
          );
        case 'email-already-in-use':
          throw EmailAlreadyInUseException(
            message: 'An account already exists with this email.',
          );
        case 'invalid-email':
          throw InvalidEmailException(message: 'The email address is invalid.');
        case 'operation-not-allowed':
          throw OperationNotAllowedException(
            message: 'Email/password accounts are not enabled.',
          );
        case 'network-request-failed':
          throw NetworkException(
            message: 'Network error. Please check your connection.',
          );
        default:
          throw AuthenticationException(
            message:
                e.message ??
                'Sign up failed: An unexpected Firebase error occurred.',
          );
      }
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'An unknown error occurred during sign up.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<fb_auth.User?> signInWithGoogle() async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('auth_signInWithGoogle');
    await trace?.start();
    try {
      if (kIsWeb) {
        // Web uses popup
        final provider =
            fb_auth.GoogleAuthProvider()
              ..addScope('email')
              ..addScope('profile')
              ..setCustomParameters({'prompt': 'select_account'});
        final credential = await _firebaseAuth.signInWithPopup(provider);
        return credential.user;
      }

      // Prefer native Google Sign-In (Google Play Services) on Android/iOS
      try {
        await _ensureGoogleInitialized();
        final gsi.GoogleSignInAccount account =
            await gsi.GoogleSignIn.instance.authenticate();
        final gsi.GoogleSignInAuthentication googleAuth =
            account.authentication;
        if (googleAuth.idToken == null) {
          throw AuthenticationException(
            message: 'Missing ID token from Google.',
          );
        }
        final oauthCred = fb_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        final result = await _firebaseAuth.signInWithCredential(oauthCred);
        return result.user;
      } catch (nativeError) {
        // Fallback: use provider flow (may open browser/OneTap)
        developer.log(
          'Native GoogleSignIn failed, falling back to provider: $nativeError',
        );
        final provider =
            fb_auth.GoogleAuthProvider()
              ..addScope('email')
              ..addScope('profile')
              ..setCustomParameters({'prompt': 'select_account'});
        final userCredential = await _firebaseAuth.signInWithProvider(provider);
        return userCredential.user;
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw AuthenticationException(
            message:
                'An account already exists with a different sign-in method.',
          );
        case 'invalid-credential':
          throw AuthenticationException(
            message: 'Invalid credentials. Please try again.',
          );
        case 'operation-not-allowed':
          throw OperationNotAllowedException(
            message: 'Google sign-in is not enabled.',
          );
        case 'user-disabled':
          throw UserDisabledException(
            message: 'This user account has been disabled.',
          );
        default:
          throw AuthenticationException(
            message: e.message ?? 'Google sign-in failed.',
          );
      }
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      developer.log('Google sign-in error: $e');
      throw AuthenticationException(
        message: 'An unexpected error occurred during Google sign-in.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<fb_auth.User?> signInWithGoogleTokens({
    String? idToken,
    String? accessToken,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('auth_signInWithGoogleTokens');
    await trace?.start();
    try {
      // If tokens are provided, always use them to sign in (preflight-approved)
      if (idToken != null || accessToken != null) {
        final credential = fb_auth.GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        );
        final result = await _firebaseAuth.signInWithCredential(credential);
        return result.user;
      }

      // Otherwise fallback to provider flows (will trigger auth state changes)
      final provider = fb_auth.GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      provider.setCustomParameters({'prompt': 'select_account'});

      if (kIsWeb) {
        final credential = await _firebaseAuth.signInWithPopup(provider);
        return credential.user;
      } else {
        final userCredential = await _firebaseAuth.signInWithProvider(provider);
        return userCredential.user;
      }
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      throw AuthenticationException(
        message: e.message ?? 'Google sign-in failed.',
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'An unexpected error occurred during Google sign-in.',
      );
    } finally {
      await trace?.stop();
    }
  }

  @override
  Future<void> signOut() async {
    final trace = kIsWeb ? null : _performance?.newTrace('auth_signOut');
    await trace?.start();
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      developer.log(
        'Error signing out',
        error: e.toString(),
        name: 'FirebaseAuthService',
      );
      throw AuthenticationException(message: 'Failed to sign out.');
    } finally {
      await trace?.stop();
    }
  }

  // Map Firebase Auth exceptions to custom exceptions
  Exception _mapFirebaseAuthException(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return UserNotFoundException(message: 'No user found with this email.');
      case 'wrong-password':
        return WrongPasswordException(message: 'Incorrect password.');
      case 'user-disabled':
        return UserDisabledException(
          message: 'This user account has been disabled.',
        );
      case 'invalid-email':
        return InvalidEmailException(message: 'The email address is invalid.');
      case 'email-already-in-use':
        return EmailAlreadyInUseException(
          message: 'An account already exists with this email.',
        );
      case 'weak-password':
        return WeakPasswordException(message: 'The password is too weak.');
      case 'operation-not-allowed':
        return OperationNotAllowedException(
          message: 'This operation is not allowed.',
        );
      case 'network-request-failed':
        return NetworkException(
          message: 'Network error. Please check your connection.',
        );
      case 'too-many-requests':
        return AuthenticationException(
          message: 'Too many attempts. Please wait a minute and try again.',
        );
      default:
        return AuthenticationException(
          message: e.message ?? 'An authentication error occurred.',
        );
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('auth_deleteCurrentUser');
    await trace?.start();
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw AuthenticationException(
          message: 'No authenticated user to delete.',
        );
      }
      await user.delete();
    } on fb_auth.FirebaseAuthException catch (e) {
      trace?.putAttribute('error', e.code);
      throw AuthenticationException(
        message: e.message ?? 'Failed to delete user account.',
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      throw AuthenticationException(
        message: 'An unknown error occurred during account deletion.',
      );
    } finally {
      await trace?.stop();
    }
  }
}
