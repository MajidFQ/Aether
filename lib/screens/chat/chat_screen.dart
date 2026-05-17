import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/groq_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kPrimary = Color(0xFF5B4FFF);
const Color _kAiBubble = Color(0xFFE0DCFF);
const Color _kPageBg = Color(0xFFF5F5F7);
const Color _kBorderBlack = Color(0xFF000000);
const Color _kMutedGray = Color(0xFF6B6B70);

const List<BoxShadow> _kNeoShadow = [
  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
];

// ── Message model ─────────────────────────────────────────────────────────────

class Message {
  Message({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GroqService _claude = GroqService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Start with two sample messages so the screen isn't empty on first open.
  final List<Message> _messages = [
    Message(
      text:
          "Hey there! I've analyzed your upcoming Quantum Physics quiz. Would you like to start with a rapid-fire review or dive into the complex formulas first? 🚀",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    Message(
      text:
          "Let's start with the formulas. I'm specifically struggling with Schrödinger's wave equation today.",
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Smoothly scroll to the latest message after the frame renders.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 1. Add the user's message and clear the input field.
    setState(() {
      _messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      // 2. Call the Claude API — key is read from .env inside ClaudeService.
      final reply = await _claude.getChatResponse(text);

      // 3. Add the AI reply.
      if (!mounted) return;
      setState(() {
        _messages.add(
          Message(text: reply, isUser: false, timestamp: DateTime.now()),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
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
        body: Column(
          children: [
            // Messages list — takes all available space above the input bar.
            Expanded(child: _buildMessageList()),
            // Typing indicator shown while waiting for Claude's response.
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(),
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
        'Aether AI',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _kPrimary,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorderBlack, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: const Center(
              child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Text(
            'Aether AI is typing...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _kMutedGray,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorderBlack, width: 2)),
      ),
      child: Row(
        children: [
          // Text input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kPageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderBlack, width: 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask Aether anything...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: _kMutedGray,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // Attach icon — placeholder, does nothing
                  IconButton(
                    icon: const Icon(Icons.attach_file, size: 20, color: _kMutedGray),
                    onPressed: () {},
                    tooltip: 'Attach',
                  ),
                  // Mic icon — placeholder, does nothing
                  IconButton(
                    icon: const Icon(Icons.mic_none, size: 20, color: _kMutedGray),
                    onPressed: () {},
                    tooltip: 'Voice',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderBlack, width: 2),
                boxShadow: _kNeoShadow,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender label + timestamp
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: isUser
                  ? [
                      Text(
                        '$timeStr  ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: _kMutedGray,
                        ),
                      ),
                      Text(
                        'You',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        'Aether AI  ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: _kMutedGray,
                        ),
                      ),
                    ],
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUser ? _kPrimary : _kAiBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(color: _kBorderBlack, width: 2),
              boxShadow: _kNeoShadow,
            ),
            child: Text(
              message.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isUser ? Colors.white : _kBorderBlack,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
