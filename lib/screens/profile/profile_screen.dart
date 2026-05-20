import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../utils/theme_helper.dart';

const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kBorderBlack = Color(0xFF000000);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _dailyGoal = 60;
  int _todayMinutes = 0;
  bool _isLoading = true;
  Map<String, int> _stats = {
    'totalStudyMinutes': 0,
    'tasksCompleted': 0,
    'flashcardDecks': 0,
    'chatsSaved': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _confirmLogout(BuildContext context) {
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
        child: Column(
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
            const SizedBox(height: 24),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 30),
            ),
            const SizedBox(height: 16),

            Text(
              'Log out?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll need to sign in again to access your study data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 28),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _kBorderBlack, width: 2),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Yes, log me out',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBorderBlack, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAll() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load daily goal from user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        _dailyGoal = userDoc.data()?['dailyGoal'] ?? 60;
      }

      // Sessions — total + today
      final sessions = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .get();

      int totalMinutes = 0;
      int todayMinutes = 0;
      final today = DateTime.now();

      for (final doc in sessions.docs) {
        final duration = (doc.data()['duration'] as num?)?.toInt() ?? 0;
        final ts = (doc.data()['completedAt'] as Timestamp?)?.toDate();
        totalMinutes += duration; // stored in minutes
        if (ts != null &&
            ts.year == today.year &&
            ts.month == today.month &&
            ts.day == today.day) {
          todayMinutes += duration;
        }
      }

      // Tasks completed
      final tasks = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('isCompleted', isEqualTo: true)
          .get();

      // Decks
      final decks = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('decks')
          .get();

      // Chats
      final chats = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('chats')
          .get();

      setState(() {
        _todayMinutes = todayMinutes;
        _stats = {
          'totalStudyMinutes': totalMinutes,
          'tasksCompleted': tasks.docs.length,
          'flashcardDecks': decks.docs.length,
          'chatsSaved': chats.docs.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDailyGoal(int newGoal) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'dailyGoal': newGoal}, SetOptions(merge: true));
      setState(() => _dailyGoal = newGoal);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Daily goal updated to $newGoal minutes! 🎯')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showGoalPicker() {
    int tempGoal = _dailyGoal;
    final isDark = isDarkMode(context);
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);

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
          builder: (ctx, setModalState) => Column(
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
                'Set Daily Study Goal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$tempGoal min',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 8),
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
                  value: tempGoal.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 11,
                  label: '$tempGoal min',
                  onChanged: (v) => setModalState(() => tempGoal = v.round()),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('15 min',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey, fontSize: 12)),
                  Text('180 min',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateDailyGoal(tempGoal);
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
                    'Save Goal',
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    final cardColor = getCardColor(context);
    final mutedColor = getMutedTextColor(context);

    final displayName = user?.displayName ?? user?.email ?? 'User';
    final initial = displayName[0].toUpperCase();
    final progress =
        _dailyGoal > 0 ? (_todayMinutes / _dailyGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            color: _kPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar & Info ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: _kBorderBlack, width: 2),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                              blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: _kBorderBlack, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(3, 3),
                                    blurRadius: 0),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user?.displayName ?? 'User',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Daily Goal Card ───────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B4FFF), Color(0xFF7C73FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: _kBorderBlack, width: 2),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                              blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🎯 Daily Goal',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              GestureDetector(
                                onTap: _showGoalPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.white54, width: 1.5),
                                  ),
                                  child: Text(
                                    'Edit',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$_todayMinutes',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8, left: 4),
                                child: Text(
                                  ' / $_dailyGoal min',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: Colors.white30,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            progress >= 1.0
                                ? '🎉 Goal completed! Great work!'
                                : '${((_dailyGoal - _todayMinutes).clamp(0, _dailyGoal))} min to go',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Stats ─────────────────────────────────────────
                    Text(
                      'Statistics',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _StatCard(
                          emoji: '⏱️',
                          label: 'Total Study Time',
                          value:
                              '${(_stats['totalStudyMinutes']! / 60).toStringAsFixed(1)}h',
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                        _StatCard(
                          emoji: '✅',
                          label: 'Tasks Done',
                          value: '${_stats['tasksCompleted']}',
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                        _StatCard(
                          emoji: '📚',
                          label: 'Flashcard Decks',
                          value: '${_stats['flashcardDecks']}',
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                        _StatCard(
                          emoji: '💬',
                          label: 'Chats Saved',
                          value: '${_stats['chatsSaved']}',
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Settings ──────────────────────────────────────
                    Text(
                      'Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        border: Border.all(color: _kBorderBlack, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black,
                              offset: Offset(4, 4),
                              blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Dark mode toggle
                          ListTile(
                            leading: Icon(
                              themeProvider.isDark
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: _kPrimary,
                            ),
                            title: Text(
                              'Dark Mode',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            trailing: Switch(
                              value: themeProvider.isDark,
                              activeColor: _kPrimary,
                              onChanged: (_) => themeProvider.toggleTheme(),
                            ),
                          ),
                          Divider(
                              height: 1,
                              color: _kBorderBlack.withOpacity(0.2)),
                          // About
                          ListTile(
                            leading: const Icon(Icons.info_outline,
                                color: _kPrimary),
                            title: Text(
                              'About',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            trailing:
                                Icon(Icons.chevron_right, color: mutedColor),
                            onTap: () => showAboutDialog(
                              context: context,
                              applicationName: 'Aether',
                              applicationVersion: '1.0.0',
                              applicationLegalese:
                                  'Your high-energy creative study hub.',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.cardColor,
    required this.textColor,
  });

  final String emoji;
  final String label;
  final String value;
  final Color cardColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: _kBorderBlack, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
