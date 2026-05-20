import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme_helper.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

// Quick-pick presets in minutes
const List<int> _kPresets = [5, 10, 15, 25, 30, 45, 60, 90];

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // Selected duration in minutes (default 25)
  int _selectedMinutes = 25;

  int get _sessionSeconds => _selectedMinutes * 60;

  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;

  // Tracks total minutes completed today (shown in the bottom stat).
  int _todaySeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Duration picker ────────────────────────────────────────────────────────

  void _showDurationPicker() {
    if (_isRunning) return; // can't change while running
    final isDark = isDarkMode(context);
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    int tempMinutes = _selectedMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: const Border(
            top: BorderSide(color: _kBorderBlack, width: 2),
            left: BorderSide(color: _kBorderBlack, width: 2),
            right: BorderSide(color: _kBorderBlack, width: 2),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Set Timer Duration',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),

              // Big minute display
              Text(
                '$tempMinutes min',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Slider 1–120 min
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: _kPrimary,
                  inactiveTrackColor: isDark
                      ? const Color(0xFF2A2A3E)
                      : const Color(0xFFE0DCFF),
                  thumbColor: _kPrimary,
                  overlayColor: _kPrimary.withOpacity(0.2),
                  valueIndicatorColor: _kPrimary,
                  valueIndicatorTextStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Slider(
                  value: tempMinutes.toDouble(),
                  min: 1,
                  max: 120,
                  divisions: 119,
                  label: '$tempMinutes min',
                  onChanged: (v) => setModal(() => tempMinutes = v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 min',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey, fontSize: 12)),
                  Text('120 min',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),

              const SizedBox(height: 20),

              // Quick-pick preset chips
              Text(
                'Quick pick',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kMutedGray,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kPresets.map((p) {
                  final selected = tempMinutes == p;
                  return GestureDetector(
                    onTap: () => setModal(() => tempMinutes = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? _kPrimary : _kBorderBlack,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${p}m',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : textColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedMinutes = tempMinutes;
                      _secondsRemaining = tempMinutes * 60;
                      _isRunning = false;
                    });
                    _timer?.cancel();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: _kBorderBlack, width: 2),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Set $tempMinutes min',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    setState(() => _todaySeconds += _sessionSeconds);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .add({
          'duration': _selectedMinutes,
          'completedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore write failed: $e');
      }
    }

    if (!mounted) return;
    _showCompleteDialog();
  }

  void _showCompleteDialog() {
    final mutedColor = getMutedTextColor(context);
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
          'Great work! You finished a $_selectedMinutes-minute focus session.',
          style: GoogleFonts.plusJakartaSans(color: mutedColor),
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

  double get _progress =>
      _sessionSeconds > 0 ? 1 - (_secondsRemaining / _sessionSeconds) : 0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    final cardColor = getCardColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Study Timer',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        // Duration edit button — disabled while running
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _showDurationPicker,
            icon: Icon(
              Icons.tune,
              size: 18,
              color: _isRunning ? _kMutedGray : _kPrimary,
            ),
            label: Text(
              '$_selectedMinutes min',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: _isRunning ? _kMutedGray : _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),

            // ── Circular timer ───────────────────────────────────────
            _CircularTimer(
              progress: _progress,
              formattedTime: _formattedTime,
            ),

            const SizedBox(height: 16),

            // Label shows selected duration
            GestureDetector(
              onTap: _isRunning ? null : _showDurationPicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Focus Time · $_selectedMinutes min',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _kMutedGray,
                    ),
                  ),
                  if (!_isRunning) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14, color: _kMutedGray),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // ── Control buttons ──────────────────────────────────────
            _buildButtons(cardColor),

            const SizedBox(height: 32),

            // ── Today stat ───────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardColor,
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
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(Color cardColor) {
    return Column(
      children: [
        // Start button
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

        // Pause + Reset row
        if (_isRunning ||
            (_secondsRemaining < _sessionSeconds &&
                _secondsRemaining > 0)) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (_isRunning)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _kNeoShadow,
                    ),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: _kBorderBlack, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: cardColor,
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
    final cardColor = getCardColor(context);
    final textColor = getTextColor(context);

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow layer
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
          // Background circle
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: cardColor,
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_kPrimary),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Time text
          Text(
            formattedTime,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
