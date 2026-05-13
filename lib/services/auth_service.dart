import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Central place for all Firebase Authentication operations used by the app.
///
/// The login screen calls these methods so UI code stays focused on layout and
/// validation, while sign-in logic lives in one testable class.
class AuthService {

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  User? get currentUser =>
      _auth.currentUser;

  // EMAIL LOGIN
  Future<UserCredential>
  signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {

    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // GOOGLE LOGIN
  Future<UserCredential>
  signInWithGoogle() async {

    await _googleSignIn.initialize();

    final GoogleSignInAccount googleUser =
        await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final credential =
        GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(
      credential,
    );
  }

  // RESET PASSWORD
  Future<void> sendPasswordResetEmail(String email) 
  {

    return _auth.sendPasswordResetEmail(
      email: email,
    );
  }

  // LOGOUT
  Future<void> signOut() async {

    await _googleSignIn.signOut();

    await _auth.signOut();
  }
}