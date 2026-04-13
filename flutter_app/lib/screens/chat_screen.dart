import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';

class ChatScreen extends StatefulWidget {
  final String itemId;
  final String itemTitle;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.itemId,
    required this.itemTitle,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _db = DatabaseService();
  late final String _myId;
  List<MessageModel> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _myId = AuthService().userId;
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _db.getMessages(
        itemId: widget.itemId,
        otherUserId: widget.otherUserId,
      );
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        _scrollToBottom();
      }
      await _db.markMessagesAsRead(
        itemId: widget.itemId,
        senderId: widget.otherUserId,
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final msgs = await _db.getMessages(
        itemId: widget.itemId,
        otherUserId: widget.otherUserId,
      );
      if (mounted && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
        await _db.markMessagesAsRead(
          itemId: widget.itemId,
          senderId: widget.otherUserId,
        );
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
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
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    final tempMsg = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      itemId: widget.itemId,
      senderId: _myId,
      senderName: 'You',
      receiverId: widget.otherUserId,
      message: text,
      isRead: false,
      createdAt: DateTime.now(),
    );

    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      await _db.sendMessage(
        itemId: widget.itemId,
        receiverId: widget.otherUserId,
        message: text,
      );
      await _refreshMessages();
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m.id == tempMsg.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const SizedBox(height: 2),
                            Text('Re: ${widget.itemTitle}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withOpacity(0.20)),
                              const SizedBox(height: 16),
                              Text('No messages yet', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text('Start the conversation.', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = _messages[i];
                            final isMe = msg.senderId == _myId;
                            return _MessageBubble(
                              message: msg.message,
                              isMe: isMe,
                              senderName: msg.senderName,
                              time: msg.createdAt,
                            );
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.94),
                border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.8))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: AppTheme.cardBgSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 10))],
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String senderName;
  final DateTime time;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe ? AppTheme.accentGradient : null,
          color: isMe ? null : AppTheme.cardBgSoft,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 18),
          ),
          border: isMe ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondary)),
              ),
            Text(message, style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimary, fontSize: 15, height: 1.35)),
            const SizedBox(height: 5),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
