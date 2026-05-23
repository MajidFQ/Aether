import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';

// --- Design tokens (matches LoginScreen exactly) ---

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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  // Inline error state — shown under each field
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateName(String value) {
    final t = value.trim();
    if (t.isEmpty) return 'Please enter your name.';
    if (t.length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  String? _validateEmail(String value) {
    final t = value.trim();
    if (t.isEmpty) return 'Please enter your email.';

    // Must have exactly one @
    final parts = t.split('@');
    if (parts.length != 2) return 'Email must contain exactly one @ symbol.';

    final local = parts[0];
    final domain = parts[1];

    // ── Local part checks ──────────────────────────────────────────
    if (local.isEmpty) return 'Enter something before the @ symbol.';
    if (local.length > 64) return 'Email is too long before the @ symbol.';
    if (local.startsWith('.') || local.endsWith('.')) {
      return 'Email cannot start or end with a dot before @.';
    }
    if (local.contains('..')) return 'Email cannot have consecutive dots.';
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+$').hasMatch(local)) {
      return 'Email contains invalid characters before @.';
    }

    // ── Domain part checks ─────────────────────────────────────────
    if (domain.isEmpty) return 'Enter a domain after the @ symbol.';
    if (domain.startsWith('.') || domain.endsWith('.')) {
      return 'Domain cannot start or end with a dot.';
    }
    if (domain.contains('..')) return 'Domain cannot have consecutive dots.';

    // Domain must be: label.label (exactly one dot separating domain + TLD)
    // e.g. gmail.com ✅  gmail.com.com ❌  sub.gmail.com ✅ but we block 2+ TLD dots
    final domainParts = domain.split('.');
    if (domainParts.length < 2) return 'Domain must include a dot (e.g. gmail.com).';
    if (domainParts.length > 2) {
      // Allow one subdomain max: mail.domain.com → 3 parts OK
      // Block obvious duplicates like domain.com.com → last two parts same
      final tld = domainParts.last;
      final secondLast = domainParts[domainParts.length - 2];
      if (tld == secondLast) {
        return 'Domain looks invalid (e.g. .com.com is not allowed).';
      }
    }

    // Each domain label must be valid (letters, digits, hyphens; no leading/trailing hyphen)
    for (final label in domainParts) {
      if (label.isEmpty) return 'Domain contains an empty section.';
      if (label.startsWith('-') || label.endsWith('-')) {
        return 'Domain labels cannot start or end with a hyphen.';
      }
      if (!RegExp(r'^[a-zA-Z0-9\-]+$').hasMatch(label)) {
        return 'Domain contains invalid characters.';
      }
    }

    // TLD must be 2–6 letters only (no digits)
    final tld = domainParts.last;
    if (!RegExp(r'^[a-zA-Z]{2,6}$').hasMatch(tld)) {
      return 'Invalid domain ending (e.g. .com, .org, .edu).';
    }

    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Please enter a password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Password must contain at least one letter.';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must contain at least one number.';
    return null;
  }

  Future<void> _signUp(AuthService auth) async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;

    // Run all validators and show inline errors
    setState(() {
      _nameError = _validateName(name);
      _emailError = _validateEmail(email);
      _passwordError = _validatePassword(password);
    });

    // Stop if any field is invalid
    if (_nameError != null || _emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    try {
      await auth.registerWithEmail(
          email: email.trim(), password: password);
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(name.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account with this email already exists.';
          setState(() => _emailError = message);
          break;
        case 'invalid-email':
          message = 'That email address is not valid.';
          setState(() => _emailError = message);
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          setState(() => _passwordError = message);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Registration failed.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _signUpButton(AuthService auth) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(_kControlRadius)),
        boxShadow: _kNeoShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kControlRadius),
          onTap: _isLoading ? null : () => _signUp(auth),
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
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Sign Up →',
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

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      Theme.of(context).textTheme,
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
                    // Brand header
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

                    // Card
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
                            'Create Account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _kBorderBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your details to get started.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _kMutedGray,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Name field
                          CustomTextField(
                            label: 'Name',
                            controller: _nameController,
                            hintText: 'Your full name',
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            errorText: _nameError,
                            onChanged: (_) {
                              if (_nameError != null) setState(() => _nameError = null);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Email field
                          CustomTextField(
                            label: 'Email Address',
                            controller: _emailController,
                            hintText: 'hello@aether.app',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            errorText: _emailError,
                            onChanged: (_) {
                              if (_emailError != null) setState(() => _emailError = null);
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          CustomTextField(
                            label: 'Password',
                            controller: _passwordController,
                            hintText: '••••••••',
                            obscureText: true,
                            autocorrect: false,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            errorText: _passwordError,
                            onChanged: (_) {
                              if (_passwordError != null) setState(() => _passwordError = null);
                            },
                          ),
                          const SizedBox(height: 24),

                          _signUpButton(auth),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Footer
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Already have an account? ', style: footerStyle),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(
                            'Login now',
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
