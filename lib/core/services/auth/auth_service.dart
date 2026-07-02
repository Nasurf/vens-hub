import 'package:firebase_auth/firebase_auth.dart'
    as fb_auth; // Alias to avoid name clash if we have our own User model

abstract class AuthService {
  fb_auth.User? get currentUser;
  Future<String> getIdToken({bool forceRefresh});
  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithGoogle();
  Future<fb_auth.User?> signInWithEmailAndPassword(
    String email,
    String password,
  );
  Future<fb_auth.User?> signInWithGoogle(); // Google Sign-In method
  Future<fb_auth.User?> signInWithGoogleTokens({
    String? idToken,
    String? accessToken,
  });
  Future<fb_auth.User?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    // User details like firstName, lastName will be handled by AuthRepositoryImpl after user creation
  });
  Stream<fb_auth.User?> authStateChanges();
  Future<void> signOut();
  Future<fb_auth.User?> getCurrentFirebaseUser();
  Future<void> forgotPassword();

  Future<void> reloadCurrentUser();

  Future<void> deleteCurrentUser();
}
