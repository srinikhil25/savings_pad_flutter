import 'package:firebase_auth/firebase_auth.dart';

/// Lecture 08: Using Cloud APIs 1 — Authentication.
///
/// Wrapping FirebaseAuth rather than calling it from widgets keeps the View
/// layer free of backend types, which is the point of the MVC split.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Fires on sign-in, sign-out, and once on startup with the restored
  /// session. The controller listens to this rather than polling currentUser,
  /// which the lecture warns can run before sign-in has completed.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get uid => _auth.currentUser?.uid;

  bool get isSignedIn => _auth.currentUser != null;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// FirebaseAuthException codes are machine-readable but not human-readable.
  /// Translating them here means every screen shows the same wording.
  static String describe(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'That email already has an account — sign in instead.',
        'weak-password' => 'Password needs to be at least 6 characters.',
        'network-request-failed' => 'No connection. Check your network and try again.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        _ => error.message ?? 'Sign-in failed (${error.code}).',
      };
    }
    return error.toString();
  }
}
