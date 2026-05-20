import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';

// --- Design tokens ---
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kBrown = Color(0xFFC87941);
const Color _kPageBg = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showTaskDetail(
    BuildContext context,
    Map<String, dynamic> data,
    QueryDocumentSnapshot doc,
    Color priorityColor,
    bool isDark,
    Color textColor,
  ) {
    final dueDate = DateTime.parse(data['dueDate']);
    final description = data['description'] as String? ?? '';
    final priority = data['priority'] ?? 'medium';
    final cardColor = isDark ? const Color(0xFF2A2A3E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F5F7);

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kMutedGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Priority badge + title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kBorderBlack, width: 1.5),
                  ),
                  child: Text(
                    priority[0].toUpperCase() + priority.substring(1),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data['title'] ?? 'Untitled',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Due date
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: _kMutedGray),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMM dd yyyy • hh:mm a').format(dueDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _kMutedGray,
                  ),
                ),
              ],
            ),

            // Description
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorderBlack, width: 2),
                ),
                child: Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Mark complete button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await doc.reference.update({'isCompleted': true});
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task completed! 🎉')),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  'Mark as Complete',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _kBorderBlack, width: 2),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthService>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'there';
    final firstName = displayName.split(' ').first;
    final initial = firstName[0].toUpperCase();
    
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : _kPageBg;
    final textColor = isDark ? Colors.white : _kBorderBlack;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, size: 26),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aether',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Dark mode toggle
                    IconButton(
                      icon: Icon(
                        Provider.of<ThemeProvider>(context).isDark
                            ? Icons.light_mode
                            : Icons.dark_mode,
                        size: 24,
                      ),
                      onPressed: () {
                        Provider.of<ThemeProvider>(context, listen: false)
                            .toggleTheme();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // Profile avatar
                    GestureDetector(
                      onTap: () => _logout(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBorderBlack, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Greeting ─────────────────────────────────────────
                Text(
                  'Hi $firstName! 👋',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to crush your goals today?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _kMutedGray,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Three action cards ────────────────────────────────
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ActionCard(
                          background: _kPrimary,
                          iconEmoji: '💬',
                          title: 'Chat',
                          subtitle: 'Ask Aether AI',
                          titleColor: Colors.white,
                          subtitleColor: Colors.white70,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/chat'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionCard(
                          background: const Color(0xFFEEEEF5),
                          iconEmoji: '📚',
                          title: 'Flashcards',
                          subtitle: 'Review & study',
                          titleColor: _kBorderBlack,
                          subtitleColor: _kMutedGray,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/flashcards'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionCard(
                          background: const Color(0xFFF5DFC0),
                          iconEmoji: '⏱️',
                          title: 'Timer',
                          subtitle: 'Focus session',
                          titleColor: _kBrown,
                          subtitleColor: _kBrown,
                          onTap: () => Navigator.of(context).pushNamed('/timer'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Upcoming Tasks ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📅 Upcoming Tasks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/add-task');
                      },
                      child: Text(
                        '+ Add',
                        style: GoogleFonts.plusJakartaSans(
                          color: _kPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .collection('tasks')
                      .where('isCompleted', isEqualTo: false)
                      .orderBy('dueDate')
                      .limit(3)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFEEEEF5),
                          border: Border.all(color: _kBorderBlack, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No tasks yet. Tap + Add to create one!',
                            style: GoogleFonts.plusJakartaSans(
                              color: _kMutedGray,
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final dueDate = DateTime.parse(data['dueDate']);
                        final priority = data['priority'] ?? 'medium';
                        Color priorityColor = priority == 'high'
                            ? Colors.red
                            : (priority == 'medium' ? Colors.orange : Colors.green);

                        return GestureDetector(
                          onTap: () => _showTaskDetail(context, data, doc, priorityColor, isDark, textColor),
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                            border: Border.all(color: _kBorderBlack, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Colored left accent bar
                                Container(
                                  width: 4,
                                  decoration: BoxDecoration(
                                    color: priorityColor,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['title'] ?? 'Untitled',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM dd, hh:mm a').format(dueDate),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _kMutedGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  color: Colors.green,
                                  onPressed: () async {
                                    await doc.reference.update({'isCompleted': true});
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Task completed! 🎉')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          ), // Container
                        ); // GestureDetector
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action Card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.background,
    required this.iconEmoji,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    required this.onTap,
  });

  final Color background;
  final String iconEmoji;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorderBlack, width: 2),
          boxShadow: _kNeoShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(iconEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
