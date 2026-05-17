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

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final TextEditingController _deckNameController = TextEditingController();

  // Each card is a pair of controllers so we can read/dispose them cleanly.
  final List<({TextEditingController question, TextEditingController answer})>
      _cards = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addCard(); // start with one blank card
  }

  @override
  void dispose() {
    _deckNameController.dispose();
    for (final c in _cards) {
      c.question.dispose();
      c.answer.dispose();
    }
    super.dispose();
  }

  // ── Card management ────────────────────────────────────────────────────────

  void _addCard() {
    if (_cards.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 cards per deck.')),
      );
      return;
    }
    setState(() {
      _cards.add((
        question: TextEditingController(),
        answer: TextEditingController(),
      ));
    });
  }

  void _deleteCard(int index) {
    if (_cards.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A deck needs at least one card.')),
      );
      return;
    }
    final card = _cards[index];
    card.question.dispose();
    card.answer.dispose();
    setState(() => _cards.removeAt(index));
  }

  // ── Save to Firestore ──────────────────────────────────────────────────────

  Future<void> _save() async {
    final deckName = _deckNameController.text.trim();
    if (deckName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a deck name.')),
      );
      return;
    }

    // Validate that every card has at least a question.
    for (int i = 0; i < _cards.length; i++) {
      if (_cards[i].question.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Card ${i + 1} is missing a question.')),
        );
        return;
      }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      // Build the plain list that Firestore will store.
      final cardData = _cards
          .map((c) => {
                'question': c.question.text.trim(),
                'answer': c.answer.text.trim(),
              })
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('decks')
          .add({
        'name': deckName,
        'cards': cardData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deck saved! 📚')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save deck: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
        appBar: _buildAppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Deck name ────────────────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Deck Name'),
                  const SizedBox(height: 8),
                  _NeoTextField(
                    controller: _deckNameController,
                    hintText: 'e.g. Quantum Physics',
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Cards heading ────────────────────────────────────────
            Text(
              'Cards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kBorderBlack,
              ),
            ),
            const SizedBox(height: 12),

            // ── Card list ────────────────────────────────────────────
            ...List.generate(_cards.length, (i) => _buildCardItem(i)),

            const SizedBox(height: 12),

            // ── Add card button ──────────────────────────────────────
            _AddCardButton(
              onTap: _addCard,
              disabled: _cards.length >= 10,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPageBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _kBorderBlack),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'New Deck',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _kBorderBlack,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _kBorderBlack, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCardItem(int index) {
    final card = _cards[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header row
            Row(
              children: [
                Text(
                  'Card ${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _deleteCard(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question
            _label('Question'),
            const SizedBox(height: 6),
            _NeoTextField(
              controller: card.question,
              hintText: 'Enter question...',
              textInputAction: TextInputAction.next,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Answer
            _label('Answer'),
            const SizedBox(height: 6),
            _NeoTextField(
              controller: card.answer,
              hintText: 'Enter answer...',
              textInputAction: TextInputAction.next,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kBorderBlack,
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorderBlack, width: 2),
        boxShadow: _kNeoShadow,
      ),
      child: child,
    );
  }
}

class _NeoTextField extends StatelessWidget {
  const _NeoTextField({
    required this.controller,
    required this.hintText,
    this.textInputAction = TextInputAction.done,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputAction textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: _kMutedGray,
          fontSize: 14,
        ),
        filled: true,
        fillColor: _kPageBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 2),
        ),
      ),
    );
  }
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap, required this.disabled});
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary, width: 2),
            boxShadow: _kNeoShadow,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: _kPrimary, size: 20),
                const SizedBox(width: 6),
                Text(
                  '+ Add Card',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
