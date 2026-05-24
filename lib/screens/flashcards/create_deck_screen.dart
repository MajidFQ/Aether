import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/groq_service.dart';
import '../../utils/theme_helper.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
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

  // Manual creation state
  final List<({TextEditingController question, TextEditingController answer})>
      _cards = [];

  // AI generation state
  final TextEditingController _topicController = TextEditingController();
  int _numCardsToGenerate = 10;
  bool _isGenerating = false;
  List<Map<String, String>> _generatedCards = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addCard(); // start with one blank card for manual tab
  }

  @override
  void dispose() {
    _deckNameController.dispose();
    _topicController.dispose();
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

  // ── AI Generation ──────────────────────────────────────────────────────────

  Future<void> _generateFlashcardsWithAI() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedCards = [];
    });

    try {
      final groqService = GroqService();
      final prompt = '''Generate exactly $_numCardsToGenerate flashcards about: ${_topicController.text.trim()}

Format your response EXACTLY as a JSON array like this:
[
  {"question": "What is X?", "answer": "X is..."},
  {"question": "How does Y work?", "answer": "Y works by..."}
]

Requirements:
- Each question should be clear and concise
- Answers should be 1-2 sentences
- Cover key concepts
- Make questions test understanding, not just memorization
- Return ONLY valid JSON, no other text''';

      final response = await groqService.getChatResponse(prompt);

      // Extract JSON from response (in case AI adds extra text)
      String jsonString = response.trim();

      // Remove markdown code blocks if present
      if (jsonString.contains('```json')) {
        jsonString = jsonString.split('```json')[1].split('```')[0].trim();
      } else if (jsonString.contains('```')) {
        jsonString = jsonString.split('```')[1].split('```')[0].trim();
      }

      // Parse JSON
      final List<dynamic> cardsJson = jsonDecode(jsonString);

      setState(() {
        _generatedCards = cardsJson
            .map((card) => {
                  'question': card['question'].toString(),
                  'answer': card['answer'].toString(),
                })
            .toList();
        _isGenerating = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Generated ${_generatedCards.length} flashcards!'),
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Error generating cards. Try again or use manual mode.'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Error generating flashcards: $e');
    }
  }

  Future<void> _saveGeneratedDeck() async {
    if (_deckNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a deck name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_generatedCards.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('decks')
          .add({
        'name': _deckNameController.text.trim(),
        'cards': _generatedCards,
        'createdAt': FieldValue.serverTimestamp(),
        'generatedByAI': true, // Mark as AI-generated
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Deck saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
    final bgColor = getBackgroundColor(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(),
        body: TabBarView(
          children: [
            _buildManualTab(),
            _buildAIGenerateTab(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Create Deck',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
      bottom: TabBar(
        labelColor: _kPrimary,
        unselectedLabelColor: _kMutedGray,
        indicatorColor: _kPrimary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.edit), text: 'Manual'),
          Tab(icon: Icon(Icons.auto_awesome), text: 'AI Generate'),
        ],
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

  // ── Manual Tab ─────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    final textColor = getTextColor(context);
    
    return ListView(
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
            color: textColor,
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
    );
  }

  // ── AI Generate Tab ────────────────────────────────────────────────────────

  Widget _buildAIGenerateTab() {
    final textColor = getTextColor(context);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            border: Border.all(color: _kPrimary, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: _kPrimary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI will generate flashcards from your topic. Perfect for quick study prep! ✨',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Deck name
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Deck Name'),
              const SizedBox(height: 8),
              _NeoTextField(
                controller: _deckNameController,
                hintText: 'e.g., Biology Chapter 3',
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Topic input
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Topic / Subject'),
              const SizedBox(height: 8),
              _NeoTextField(
                controller: _topicController,
                hintText:
                    'e.g., Photosynthesis process and light reactions',
                textInputAction: TextInputAction.done,
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Number of cards slider
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Number of Cards: $_numCardsToGenerate'),
              const SizedBox(height: 8),
              Slider(
                value: _numCardsToGenerate.toDouble(),
                min: 5,
                max: 15,
                divisions: 10,
                activeColor: _kPrimary,
                label: '$_numCardsToGenerate cards',
                onChanged: (value) {
                  setState(() => _numCardsToGenerate = value.round());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Generate button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateFlashcardsWithAI,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(
              _isGenerating ? 'Generating...' : 'Generate Flashcards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              disabledBackgroundColor: _kMutedGray,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _kBorderBlack, width: 2),
              ),
              elevation: 0,
            ),
          ),
        ),

        // Preview generated cards
        if (_generatedCards.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Generated Cards (${_generatedCards.length})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              TextButton(
                onPressed: _saveGeneratedDeck,
                child: Text(
                  'Save Deck',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._generatedCards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getCardColor(context),
                border: Border.all(color: _kBorderBlack, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _kNeoShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card['question']!,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card['answer']!,
                    style: GoogleFonts.plusJakartaSans(
                      color: getMutedTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
        color: getTextColor(context),
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
        color: getCardColor(context),
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
    final bgColor = getBackgroundColor(context);
    final textColor = getTextColor(context);
    
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: _kMutedGray,
          fontSize: 14,
        ),
        filled: true,
        fillColor: bgColor,
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
            color: getCardColor(context),
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
