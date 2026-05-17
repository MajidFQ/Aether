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

/// Lists all decks for the current user and lets them start a study session
/// or create a new deck.
class DeckListScreen extends StatelessWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

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
            'Flashcards',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kBorderBlack,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/create-deck'),
                style: TextButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: _kBorderBlack, width: 2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'New',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        body: uid == null
            ? const Center(child: Text('Not logged in.'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('decks')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _EmptyState(
                      onCreateTap: () =>
                          Navigator.of(context).pushNamed('/create-deck'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data =
                          docs[i].data() as Map<String, dynamic>;
                      final name = data['name'] as String? ?? 'Untitled';
                      final cards = (data['cards'] as List?)?.length ?? 0;
                      return _DeckTile(
                        name: name,
                        cardCount: cards,
                        onStudy: () => Navigator.of(context).pushNamed(
                          '/study',
                          arguments: data,
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

// ── Deck tile ─────────────────────────────────────────────────────────────────

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.name,
    required this.cardCount,
    required this.onStudy,
  });

  final String name;
  final int cardCount;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderBlack, width: 2),
        boxShadow: _kNeoShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: Text('📚', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kBorderBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cardCount card${cardCount == 1 ? '' : 's'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _kMutedGray,
                    ),
                  ),
                ],
              ),
            ),
            // Study button
            GestureDetector(
              onTap: onStudy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderBlack, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0),
                  ],
                ),
                child: Text(
                  'Study',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
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
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No decks yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kBorderBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first deck to start studying.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: _kMutedGray),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorderBlack, width: 2),
                  boxShadow: _kNeoShadow,
                ),
                child: Text(
                  '+ Create Deck',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
