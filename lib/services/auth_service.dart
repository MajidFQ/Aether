import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Auth + Google Sign-In for the login screen.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Set after a successful [GoogleSignIn.instance.initialize] on non-web (Android, etc.).
  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// google_sign_in v7 — only used on Android (and other non-web targets). Web uses Firebase popup instead.
  Future<void> _initializeGoogleSignInForMobile() async {
    if (kIsWeb || _googleInitialized) return;

    try {
      const envId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
      if (envId.isNotEmpty) {
        await GoogleSignIn.instance.initialize(clientId: envId);
      } else {
        await GoogleSignIn.instance.initialize();
      }
      _googleInitialized = true;
    } catch (e) {
      throw StateError('Google Sign-In could not start: $e');
    }
  }

  /// **Web:** Firebase opens the Google account popup (`signInWithPopup`).
  /// **Android:** `google_sign_in` runs `authenticate()`, then Firebase gets an ID token credential.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        return await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          throw StateError('Google sign-in was cancelled.');
        }
        rethrow;
      }
    }

    await _initializeGoogleSignInForMobile();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw StateError('Google sign-in was cancelled.');
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'No ID token from Google. Enable the Google sign-in provider in Firebase.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb && _googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
