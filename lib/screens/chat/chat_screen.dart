import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Map<String, dynamic> toMap() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        text: map['text'] as String,
        isUser: map['isUser'] as bool,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  /// Pass [initialMessages] to pre-populate the chat from history.
  const ChatScreen({super.key, this.initialMessages});
  final List<Message>? initialMessages;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GroqService _groq = GroqService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<Message> _messages;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Use pre-loaded messages from history, or start fresh with a greeting.
    _messages = widget.initialMessages ??
        [
          Message(
            text:
                "Hey there! I'm Aether AI, your study assistant. What would you like to work on today? 🚀",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────

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

  // ── Send message ───────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _groq.getChatResponse(text);
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

  // ── Save chat to Firestore ─────────────────────────────────────────────────

  Future<void> _saveChat() async {
    // Need at least one real exchange beyond the greeting.
    if (_messages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start a conversation before saving.')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Default name = first user message, truncated.
    final defaultName = _messages
        .firstWhere((m) => m.isUser, orElse: () => _messages.first)
        .text;
    final nameController = TextEditingController(
      text: defaultName.length > 60
          ? '${defaultName.substring(0, 60)}...'
          : defaultName,
    );

    // Ask the user to name the chat before saving.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _kBorderBlack, width: 2),
        ),
        title: Text(
          'Save chat',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          maxLength: 80,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Chat name',
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: _kBorderBlack,
            ),
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _kMutedGray)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(color: _kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    // FIX 1: Capture the text immediately
    final chatName = nameController.text.trim();

    // FIX 2: Check conditions safely
    if (confirmed != true || chatName.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chats')
          .add({
        'messages': _messages.map((m) => m.toMap()).toList(),
        'firstQuestion': chatName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat saved! 💾')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
          if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _kPageBg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(),
          ],
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
        // History button
        IconButton(
          icon: const Icon(Icons.history, color: _kBorderBlack),
          tooltip: 'Chat history',
          onPressed: () => Navigator.of(context).pushNamed('/chat-history'),
        ),
        // Save button
        _isSaving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.save_outlined, color: _kBorderBlack),
                tooltip: 'Save chat',
                onPressed: _saveChat,
              ),
        const SizedBox(width: 4),
        // Avatar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
              border: Border.all(color: _kBorderBlack, width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
              ],
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800),
              ),
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
      itemBuilder: (context, index) =>
          _MessageBubble(message: _messages[index]),
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
                  IconButton(
                    icon: const Icon(Icons.attach_file,
                        size: 20, color: _kMutedGray),
                    onPressed: () {},
                    tooltip: 'Attach',
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic_none,
                        size: 20, color: _kMutedGray),
                    onPressed: () {},
                    tooltip: 'Voice',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: isUser
                  ? [
                      Text(
                        '$timeStr  ',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: _kMutedGray),
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
                            fontSize: 11, color: _kMutedGray),
                      ),
                    ],
            ),
          ),
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
