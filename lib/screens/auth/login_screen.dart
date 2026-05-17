import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/social_button.dart';

// --- Design tokens (neo-brutalist) ---

const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kPageBackground = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const double _kCardRadius = 16;
const double _kControlRadius = 12;
const double _kCardPadding = 24;

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(
    color: Colors.black,
    offset: Offset(4, 4),
    blurRadius: 0,
    spreadRadius: 0,
  ),
];

abstract class LoginScreenRoutes {
  static const String home = '/home';
  static const String register = '/register';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- State & controllers ---

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String? emailError;
  String? passwordError;
  String? firebaseError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Auth & validation ---

  String? _validateEmail(String value) {
    final t = value.trim();
    if (t.isEmpty) return 'Please enter your email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Please enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  void _onEmailChanged(String _) {
    if (firebaseError != null || emailError != null) {
      setState(() {
        firebaseError = null;
        emailError = null;
      });
    }
  }

  void _onPasswordChanged(String _) {
    if (firebaseError != null || passwordError != null) {
      setState(() {
        firebaseError = null;
        passwordError = null;
      });
    }
  }

  void _mapFirebaseAuthError(FirebaseAuthException e) {
    final code = e.code;
    if (code == 'invalid-email') {
      emailError = 'That email address is not valid.';
    } else if (code == 'user-disabled') {
      firebaseError = 'This account has been disabled.';
    } else if (code == 'user-not-found') {
      emailError = 'No account found for that email.';
    } else if (code == 'wrong-password') {
      passwordError = 'Incorrect password. Try again.';
    } else if (code == 'invalid-credential' ||
        code == 'invalid-login-credentials') {
      firebaseError =
          'Those credentials did not work. Check email/password.';
    } else {
      firebaseError = e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _loginWithEmail(AuthService auth) async {
    FocusScope.of(context).unfocus();

    setState(() {
      emailError = _validateEmail(emailController.text);
      passwordError = _validatePassword(passwordController.text);
      firebaseError = null;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => isLoading = true);
    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoginScreenRoutes.home);
    } on FirebaseAuthException catch (e) {
      setState(() => _mapFirebaseAuthError(e));
    } catch (e) {
      // On web, Firebase errors can bypass the typed catch — extract from toString
      final raw = e.toString();
      final match = RegExp(r'\[firebase_auth/([^\]]+)\](.*)').firstMatch(raw);
      if (match != null) {
        final code = match.group(1)!.trim();
        final msg = match.group(2)!.trim();
        setState(() => _mapFirebaseAuthError(
              FirebaseAuthException(code: code, message: msg.isEmpty ? null : msg),
            ));
      } else {
        setState(() => firebaseError = raw.isNotEmpty ? raw : 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loginWithGoogle(AuthService auth) async {
    FocusScope.of(context).unfocus();
    setState(() {
      firebaseError = null;
      isLoading = true;
    });
    try {
      await auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoginScreenRoutes.home);
    } on FirebaseAuthException catch (e) {
      setState(() => _mapFirebaseAuthError(e));
    } on StateError catch (e) {
      if (e.message == 'Google sign-in was cancelled.') return;
      final m = e.message;
      setState(
        () => firebaseError =
            m.isNotEmpty ? m : 'Google sign-in failed.',
      );
    } catch (e) {
      setState(() => firebaseError = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _forgotPassword(AuthService auth) async {
    final resetCtrl = TextEditingController(text: emailController.text.trim());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: resetCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final err = _validateEmail(resetCtrl.text);
                if (err != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err)),
                    );
                  }
                  return;
                }
                try {
                  await auth.sendPasswordResetEmail(resetCtrl.text.trim());
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Check your inbox for reset instructions.'),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message ?? 'Could not send email.'),
                    ),
                  );
                }
              },
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );

    resetCtrl.dispose();
  }

  // --- UI sections (same look as before) ---

  Widget _emailField() {
    return CustomTextField(
      label: 'Email Address',
      controller: emailController,
      hintText: 'hello@aether.app',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      errorText: emailError,
      onChanged: _onEmailChanged,
    );
  }

  Widget _passwordField(AuthService auth) {
    return CustomTextField(
      label: 'Password',
      labelTrailing: GestureDetector(
        onTap: isLoading ? null : () => _forgotPassword(auth),
        child: Text(
          'Forgot?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: _kPrimary,
            fontSize: 14,
          ),
        ),
      ),
      controller: passwordController,
      hintText: '••••••••',
      obscureText: true,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      errorText: passwordError,
      onChanged: _onPasswordChanged,
    );
  }

  Widget _continueButton(AuthService auth) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(_kControlRadius)),
        boxShadow: _kNeoShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kControlRadius),
          onTap: isLoading ? null : () => _loginWithEmail(auth),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kControlRadius),
              border: Border.all(color: _kBorderBlack, width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFF5B4FFF), Color(0xFF4A3FD9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              height: 52,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue →',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Web uses Firebase popup inside [AuthService]; Android uses `google_sign_in` — same UI entry point.
  Widget _googleButton(AuthService auth) {
    return Row(
      children: [
        Expanded(
          child: SocialButton(
            label: 'Google',
            icon: SizedBox(
              width: 22,
              height: 22,
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/64px-Google_%22G%22_logo.svg.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return FittedBox(
                    child: Text(
                      'G',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4285F4),
                      ),
                    ),
                  );
                },
              ),
            ),
            isEnabled: !isLoading,
            onPressed: () => _loginWithGoogle(auth),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      Theme.of(context).textTheme,
    );
    final dividerLabelStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _kMutedGray,
    );
    final footerStyle = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _kMutedGray,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: _kPageBackground,
      ),
      child: Scaffold(
        backgroundColor: _kPageBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    Text(
                      'Aether',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: _kPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your high-energy creative study hub.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _kMutedGray,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_kCardRadius),
                        border: Border.all(color: _kBorderBlack, width: 2),
                        boxShadow: _kNeoShadow,
                      ),
                      padding: const EdgeInsets.all(_kCardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome Back',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _kBorderBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your details to dive back in.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _kMutedGray,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _emailField(),
                          const SizedBox(height: 20),
                          _passwordField(auth),
                          if (firebaseError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              firebaseError!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _continueButton(auth),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: _kBorderBlack,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or join with',
                                  style: dividerLabelStyle,
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: _kBorderBlack,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _googleButton(auth),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: footerStyle),
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => Navigator.of(context)
                                  .pushNamed(LoginScreenRoutes.register),
                          child: Text(
                            'Register now',
                            style: footerStyle.copyWith(
                              color: _kPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
