import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

// --- Design tokens (matches LoginScreen / RegisterScreen) ---

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthService>();
    await auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Unknown user';
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
        appBar: AppBar(
          backgroundColor: _kPageBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Aether',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => _logout(context),
                style: TextButton.styleFrom(
                  foregroundColor: _kMutedGray,
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    border: Border.all(color: _kBorderBlack, width: 2),
                    boxShadow: _kNeoShadow,
                  ),
                  padding: const EdgeInsets.all(_kCardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Heading
                      Text(
                        'Welcome to Aether!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _kBorderBlack,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // User email
                      Text(
                        email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _kMutedGray,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // "Start Studying" button
                      Container(
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(_kControlRadius),
                          ),
                          boxShadow: _kNeoShadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(_kControlRadius),
                            onTap: () {},
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(_kControlRadius),
                                border:
                                    Border.all(color: _kBorderBlack, width: 2),
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
                                  child: Text(
                                    'Start Studying →',
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
