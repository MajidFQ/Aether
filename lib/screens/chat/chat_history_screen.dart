import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../utils/theme_helper.dart';
import 'chat_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kPageBg = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  // ── Rename dialog ──────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(
    BuildContext context,
    String docId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        title: Text(
          'Rename chat',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter a name...',
            hintStyle: GoogleFonts.plusJakartaSans(color: _kMutedGray),
            filled: true,
            fillColor: _kPageBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBorderBlack, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: _kMutedGray),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              // Capture uid BEFORE popping — dialog context is invalid after pop.
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              Navigator.of(ctx).pop();

              // Firestore update uses uid captured above, not ctx.
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('chats')
                  .doc(docId)
                  .update({'firstQuestion': newName});
            },
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(
                color: _kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);

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
            'Chat History',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        body: uid == null
            ? const Center(child: Text('Not logged in.'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('chats')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const _EmptyState();

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final title =
                          data['firstQuestion'] as String? ?? 'Chat session';
                      final createdAt = data['createdAt'] as Timestamp?;
                      final rawMessages = data['messages'] as List? ?? [];

                      return _ChatHistoryTile(
                        title: title,
                        createdAt: createdAt?.toDate(),
                        messageCount: rawMessages.length,
                        onTap: () {
                          final messages = rawMessages
                              .map((m) => Message.fromMap(
                                  Map<String, dynamic>.from(m as Map)))
                              .toList();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(initialMessages: messages),
                            ),
                          );
                        },
                        onRename: () => _showRenameDialog(
                          context,
                          doc.id,
                          title,
                        ),
                      );
                    },
                  );
                },
              ),
      );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────

class _ChatHistoryTile extends StatelessWidget {
  const _ChatHistoryTile({
    required this.title,
    required this.createdAt,
    required this.messageCount,
    required this.onTap,
    required this.onRename,
  });

  final String title;
  final DateTime? createdAt;
  final int messageCount;
  final VoidCallback onTap;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt!)
        : 'Unknown date';
    
    final cardColor = getCardColor(context);
    final textColor = getTextColor(context);
    final mutedColor = getMutedTextColor(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorderBlack, width: 2),
          boxShadow: _kNeoShadow,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE0DCFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderBlack, width: 1.5),
              ),
              child: const Center(
                child: Text('💬', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr  •  $messageCount messages',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Rename button
            GestureDetector(
              onTap: onRename,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 18, color: mutedColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(context);
    final mutedColor = getMutedTextColor(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No saved chats yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation and tap 💾 to save it.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}
