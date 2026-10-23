import 'package:flutter/material.dart';

import '../backend/chat_service.dart';
import '../models.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Real-time chat screen for patient-doctor messaging.
class ChatScreen extends StatefulWidget {
  final String otherId;
  final String otherName;
  final bool otherIsDoctor;
  final String myId;
  final String myName;

  const ChatScreen({
    super.key,
    required this.otherId,
    required this.otherName,
    required this.otherIsDoctor,
    required this.myId,
    required this.myName,
  });

  /// Opens (or starts) a 1-to-1 chat between the signed-in user and [otherId].
  /// [otherIsDoctor] says whether the other party is the doctor.
  static void open(BuildContext context,
      {required String otherId,
      required String otherName,
      required bool otherIsDoctor}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        otherId: otherId,
        otherName: otherName,
        otherIsDoctor: otherIsDoctor,
        myId: DB.uid,
        myName: DB.myName,
      ),
    ));
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _marking = false;
  String? _chatId;
  String? _initError;
  Stream<List<ChatMessage>>? _messages;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Creates/validates the parent chat BEFORE any listener is attached.
  Future<void> _init() async {
    setState(() {
      _initError = null;
      _chatId = null;
      _messages = null;
    });
    try {
      final id = await ChatService.ensureChatExists(
        myId: widget.myId,
        myName: widget.myName,
        otherId: widget.otherId,
        otherName: widget.otherName,
        otherIsDoctor: widget.otherIsDoctor,
      );
      if (!mounted) return;
      setState(() {
        _chatId = id;
        _messages = ChatService.messages(id);
      });
      ChatService.markConversationRead(id);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  /// Marks incoming messages read once per batch of new messages.
  void _markReadIfNeeded(List<ChatMessage> messages) {
    final id = _chatId;
    if (id == null || _marking) return;
    if (!messages.any((m) => m.senderId != widget.myId && !m.isRead)) return;
    _marking = true;
    ChatService.markConversationRead(id).whenComplete(() => _marking = false);
  }

  Future<void> _send() async {
    final id = _chatId;
    final text = _msgCtrl.text.trim();
    if (id == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.sendMessage(
        chatDocId: id,
        senderName: widget.myName,
        recipientId: widget.otherId,
        text: text,
      );
      _msgCtrl.clear(); // keep the text if the send failed
    } catch (e) {
      if (mounted) {
        showMsg(context, 'Could not send message: $e', error: true);
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  Widget _statusBody(String? error) {
    if (error == null) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _init, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InitialsAvatar(widget.otherName, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.otherName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snap) {
                if (_messages == null) return _statusBody(_initError);
                if (snap.hasError) {
                  return _statusBody('Could not load messages.');
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!;
                _markReadIfNeeded(messages);
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('No messages yet.\nSay hello! 👋',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.senderId == widget.myId;
                    return _MessageBubble(message: m, isMe: isMe);
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: kPrimary,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _chatId == null || _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? kPrimary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(message.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary.withValues(alpha: 0.8),
                  )),
            Text(message.text,
                style: TextStyle(
                  color: isMe ? Colors.white : null,
                  fontSize: 15,
                )),
            const SizedBox(height: 2),
            Text(
              _timeLabel(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}
