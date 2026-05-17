import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kPageBg = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  static const int _sessionSeconds = 25 * 60; // 25 minutes

  int _secondsRemaining = _sessionSeconds;
  bool _isRunning = false;
  Timer? _timer;

  // Tracks total seconds completed today (shown in the bottom stat).
  int _todaySeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Timer control ──────────────────────────────────────────────────────────

  void _start() {
    if (_isRunning || _secondsRemaining == 0) return;
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
        });
        _onSessionComplete();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = _sessionSeconds;
      _isRunning = false;
    });
  }

  // ── Session complete ───────────────────────────────────────────────────────

  Future<void> _onSessionComplete() async {
    // Update today's stat locally.
    setState(() => _todaySeconds += _sessionSeconds);

    // Save session to Firestore under users/{uid}/sessions/{autoId}.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .add({
          'duration': 25,           // minutes
          'completedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Non-fatal — session still counts locally even if Firestore write fails.
        debugPrint('Firestore write failed: $e');
      }
    }

    if (!mounted) return;
    _showCompleteDialog();
  }

  void _showCompleteDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        title: Text(
          '🎉 Session complete!',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Great work! You finished a 25-minute focus session.',
          style: GoogleFonts.plusJakartaSans(color: _kMutedGray),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _reset();
            },
            child: Text(
              'Start another',
              style: GoogleFonts.plusJakartaSans(
                color: _kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get _todayStat {
    final h = _todaySeconds ~/ 3600;
    final m = (_todaySeconds % 3600) ~/ 60;
    return 'Today: ${h}h ${m}m';
  }

  // Progress 0.0 → 1.0 for the circular indicator.
  double get _progress => 1 - (_secondsRemaining / _sessionSeconds);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: _kPageBg,
      ),
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: AppBar(
          backgroundColor: _kPageBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _kBorderBlack),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Study Timer',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kBorderBlack,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── Circular timer ─────────────────────────────────────────
              _CircularTimer(
                progress: _progress,
                formattedTime: _formattedTime,
              ),

              const SizedBox(height: 16),

              Text(
                'Focus Time',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kMutedGray,
                ),
              ),

              const Spacer(),

              // ── Control buttons ────────────────────────────────────────
              _buildButtons(),

              const SizedBox(height: 32),

              // ── Today stat ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorderBlack, width: 2),
                  boxShadow: _kNeoShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: _kPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _todayStat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kBorderBlack,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        // Start button — full width, purple
        if (!_isRunning)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _kNeoShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _start,
                child: Ink(
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorderBlack, width: 2),
                  ),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        _secondsRemaining == 0 ? 'Restart' : 'Start',
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

        // Pause + Reset row — shown while running or paused mid-session
        if (_isRunning || (_secondsRemaining < _sessionSeconds && _secondsRemaining > 0)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              // Pause button
              if (_isRunning)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _kNeoShadow,
                    ),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorderBlack, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: _pause,
                      child: Text(
                        'Pause',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: _kBorderBlack,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_isRunning) const SizedBox(width: 12),

              // Reset button
              Expanded(
                child: TextButton(
                  onPressed: _reset,
                  child: Text(
                    'Reset',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: _kMutedGray,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Circular timer widget ─────────────────────────────────────────────────────

class _CircularTimer extends StatelessWidget {
  const _CircularTimer({
    required this.progress,
    required this.formattedTime,
  });

  final double progress;
  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Offset shadow layer
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // White background circle
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorderBlack, width: 3),
            ),
          ),
          // Progress arc
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: const Color(0xFFE0DCFF),
              valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Time text
          Text(
            formattedTime,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: _kBorderBlack,
            ),
          ),
        ],
      ),
    );
  }
}
