import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/social_button.dart';

// =============================================================================
// Design tokens — match the Figma / spec (colors, radii, shadow).
// =============================================================================

/// Primary brand purple used for headlines, links, and the main call-to-action.
const Color _kPrimary = Color(0xFF5B4FFF);

/// Page background behind the floating card.
const Color _kPageBackground = Color(0xFFF5F5F7);

/// Neo-brutalist outline and hard shadow color.
const Color _kBorderBlack = Color(0xFF000000);

/// Secondary copy (taglines, hints, divider label).
const Color _kMutedGray = Color(0xFF6B6B70);

/// Card corner rounding.
const double _kCardRadius = 16;

/// Inputs, buttons, and social tiles share this corner radius.
const double _kControlRadius = 12;

/// Inner padding for the white login card.
const double _kCardPadding = 24;

/// Solid “lifted card” shadow used across the screen.
const List<BoxShadow> _kNeoShadow = [
  BoxShadow(
    color: Colors.black,
    offset: Offset(4, 4),
    blurRadius: 0,
    spreadRadius: 0,
  ),
];

/// Named routes used from this screen (also registered in [MaterialApp.routes]).
abstract class LoginScreenRoutes {
  static const String home = '/home';
  static const String register = '/register';
}

/// High-energy neo-brutalist login experience wired to Firebase via [AuthService].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ---------------------------------------------------------------------------
  // Controllers — keep text separate from the widget tree so values survive
  // rebuilds and can be disposed cleanly in [dispose].
  // ---------------------------------------------------------------------------
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  /// When true, email/password and social actions are disabled and the primary
  /// button shows a spinner instead of the label.
  bool isLoading = false;

  /// Client-side validation for the email field (format).
  String? emailError;

  /// Client-side validation for the password field (length).
  String? passwordError;

  /// Firebase or network error that is not tied to a single field.
  String? firebaseError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation helpers — small pure functions keep the UI code readable.
  // ---------------------------------------------------------------------------

  /// Returns `null` when the string looks like a normal email address.
  String? validateEmailFormat(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Please enter your email.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Firebase password rules are stricter; we enforce at least six characters.
  String? validatePasswordLength(String value) {
    if (value.isEmpty) return 'Please enter your password.';
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  /// Clears server-side errors whenever the user edits a field.
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

  /// Maps [FirebaseAuthException.code] to short, human-readable copy.
  void _applyFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        emailError = 'That email address is not valid.';
        break;
      case 'user-disabled':
        firebaseError = 'This account has been disabled.';
        break;
      case 'user-not-found':
        emailError = 'No account found for that email.';
        break;
      case 'wrong-password':
        passwordError = 'Incorrect password. Try again.';
        break;
      case 'invalid-credential':
      case 'invalid-login-credentials':
        firebaseError = 'Those credentials did not work. Check email/password.';
        break;
      default:
        firebaseError = e.message ?? 'Something went wrong. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Auth actions — delegate all Firebase work to [AuthService].
  // ---------------------------------------------------------------------------

  Future<void> _handleEmailLogin(AuthService auth) async {
    FocusScope.of(context).unfocus();

    setState(() {
      emailError = validateEmailFormat(emailController.text);
      passwordError = validatePasswordLength(passwordController.text);
      firebaseError = null;
    });

    if (emailError != null || passwordError != null) {
      return;
    }

    setState(() => isLoading = true);

    try {
      await auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(LoginScreenRoutes.home);
    } on FirebaseAuthException catch (e) {
      setState(() => _applyFirebaseAuthError(e));
    } catch (e) {
      setState(() {
        firebaseError = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin(AuthService auth) async {
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
      setState(() => _applyFirebaseAuthError(e));
    } on StateError catch (e) {
      // User cancelled, or we couldn't initialize Google Sign-In on web.
      if (e.message == 'Google sign-in was cancelled.') return;
      if (mounted) {
        final msg = e.message;
        setState(() => firebaseError =
            msg.isNotEmpty ? msg : 'Google sign-in failed.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }



  /// Opens a lightweight dialog so the user can request a reset link.
  Future<void> _showForgotPasswordDialog(AuthService auth) async {
    final resetEmailController =
        TextEditingController(text: emailController.text.trim());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: resetEmailController,
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
                final email = resetEmailController.text.trim();
                final formatError = validateEmailFormat(email);
                if (formatError != null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(formatError)),
                  );
                  return;
                }
                try {
                  await auth.sendPasswordResetEmail(email);
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
                    SnackBar(content: Text(e.message ?? 'Could not send email.')),
                  );
                }
              },
              child: const Text('Send link'),
            ),
          ],
        );
      },
    );

    resetEmailController.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI building blocks — each helper returns one focused chunk of the layout.
  // ---------------------------------------------------------------------------

  /// Top branding outside the card (name + tagline).
  Widget _buildHeader() {
    return Column(
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
      ],
    );
  }

  /// White elevated panel that wraps the entire form.
  Widget _buildLoginCard(AuthService auth) {
    return Container(
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
          buildEmailField(),
          const SizedBox(height: 20),
          buildPasswordField(auth),
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
          buildContinueButton(auth),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Email text field with validation messaging.
  Widget buildEmailField() {
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

  /// Password field with inline “Forgot?” action on the label row.
  Widget buildPasswordField(AuthService auth) {
    return CustomTextField(
      label: 'Password',
      labelTrailing: GestureDetector(
        onTap: isLoading ? null : () => _showForgotPasswordDialog(auth),
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

  /// Primary filled button with gradient fill, border, and neo shadow.
  Widget buildContinueButton(AuthService auth) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(_kControlRadius)),
        boxShadow: _kNeoShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kControlRadius),
          onTap: isLoading ? null : () => _handleEmailLogin(auth),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kControlRadius),
              border: Border.all(color: _kBorderBlack, width: 2),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF5B4FFF),
                  Color(0xFF4A3FD9),
                ],
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

  /// “Or join with” label framed by thin horizontal rules.
  Widget _buildDivider() {
    final lineStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _kMutedGray,
    );

    return Row(
      children: [
        const Expanded(child: Divider(color: _kBorderBlack, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or join with', style: lineStyle),
        ),
        const Expanded(child: Divider(color: _kBorderBlack, thickness: 1)),
      ],
    );
  }

  /// Loads the colorful Google mark when network is available; falls back locally.
  Widget _buildGoogleIcon() {
    return SizedBox(
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
    );
  }


  /// Footer copy with tappable “Register now”.
  Widget _buildFooter() {
    final baseStyle = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _kMutedGray,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text("Don't have an account? ", style: baseStyle),
        GestureDetector(
          onTap: isLoading
              ? null
              : () {
                  Navigator.of(context).pushNamed(LoginScreenRoutes.register);
                },
          child: Text(
            'Register now',
            style: baseStyle.copyWith(
              color: _kPrimary,
              fontWeight: FontWeight.w700,
            ),
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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: _kPageBackground,
      ),
      child: Scaffold(
        backgroundColor: _kPageBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildLoginCard(auth),
                        const SizedBox(height: 28),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
