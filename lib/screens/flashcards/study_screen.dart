import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kPageBg = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);
const Color _kGreen = Color(0xFF22C55E);
const Color _kRed = Color(0xFFEF4444);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

// ── Screen ────────────────────────────────────────────────────────────────────

/// Accepts deck data via Navigator arguments as a Map with keys:
///   'name' (String) and 'cards' (List of Maps with 'question'/'answer').
///
/// Each card map has 'question' and 'answer' string fields.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final String _deckName;
  late final List<Map<String, dynamic>> _cards;

  int _currentIndex = 0;
  bool _showAnswer = false;
  int _correctCount = 0;

  // Parsed once from Navigator arguments in didChangeDependencies.
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    _deckName = (args?['name'] as String?) ?? 'Study';
    final raw = args?['cards'] as List?;
    _cards = raw
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _flipCard() => setState(() => _showAnswer = !_showAnswer);

  void _gotIt() {
    setState(() => _correctCount++);
    _nextCard();
  }

  void _studyAgain() => _nextCard();

  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) {
      _showCompletionDialog();
    } else {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    }
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        title: Text(
          '🎉 Complete!',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_correctCount / ${_cards.length} correct',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _scoreMessage,
              style: GoogleFonts.plusJakartaSans(
                color: _kMutedGray,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Restart the deck from the beginning.
              setState(() {
                _currentIndex = 0;
                _showAnswer = false;
                _correctCount = 0;
              });
            },
            child: Text(
              'Study again',
              style: GoogleFonts.plusJakartaSans(
                color: _kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // back to deck list
            },
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String get _scoreMessage {
    final pct = _cards.isEmpty ? 0 : (_correctCount / _cards.length * 100).round();
    if (pct == 100) return 'Perfect score! 🌟';
    if (pct >= 80) return 'Great job! Keep it up.';
    if (pct >= 50) return 'Good effort. Review the missed cards.';
    return 'Keep practicing — you\'ll get there!';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Guard: no cards in deck
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_deckName)),
        body: const Center(child: Text('This deck has no cards.')),
      );
    }

    final card = _cards[_currentIndex];

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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Progress ───────────────────────────────────────────
              _buildProgress(),

              const Spacer(),

              // ── Flashcard ──────────────────────────────────────────
              _FlashCard(
                question: card['question'] as String? ?? '',
                answer: card['answer'] as String? ?? '',
                showAnswer: _showAnswer,
                onTap: _flipCard,
              ),

              const Spacer(),

              // ── Buttons ────────────────────────────────────────────
              _buildButtons(),

              const SizedBox(height: 36),
            ],
          ),
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
        _deckName,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _kBorderBlack,
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final total = _cards.length;
    final current = _currentIndex + 1;
    final progress = current / total;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current / $total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kMutedGray,
              ),
            ),
            Text(
              '$_correctCount correct',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE0DCFF),
            valueColor: const AlwaysStoppedAnimation<Color>(_kPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        // Study again — red
        Expanded(
          child: _ActionButton(
            label: 'Study again',
            color: _kRed,
            textColor: Colors.white,
            icon: Icons.replay,
            onTap: _studyAgain,
          ),
        ),
        const SizedBox(width: 12),
        // Got it — green
        Expanded(
          child: _ActionButton(
            label: 'Got it!',
            color: _kGreen,
            textColor: Colors.white,
            icon: Icons.check,
            onTap: _gotIt,
          ),
        ),
      ],
    );
  }
}

// ── Flashcard widget ──────────────────────────────────────────────────────────

class _FlashCard extends StatelessWidget {
  const _FlashCard({
    required this.question,
    required this.answer,
    required this.showAnswer,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool showAnswer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        decoration: BoxDecoration(
          color: showAnswer ? const Color(0xFFE0DCFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorderBlack, width: 2.5),
          boxShadow: _kNeoShadow,
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Q / A badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: showAnswer ? _kPrimary : const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorderBlack, width: 1.5),
              ),
              child: Text(
                showAnswer ? 'Answer' : 'Question',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: showAnswer ? Colors.white : _kMutedGray,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              showAnswer ? answer : question,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kBorderBlack,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tap to flip',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorderBlack, width: 2),
          boxShadow: _kNeoShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
