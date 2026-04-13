import 'package:flutter/material.dart';
import '../models/chat_contact_model.dart';
import '../models/item_model.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';
import 'chat_screen.dart';

class ItemChatsScreen extends StatefulWidget {
  final ItemModel item;

  const ItemChatsScreen({super.key, required this.item});

  @override
  State<ItemChatsScreen> createState() => _ItemChatsScreenState();
}

class _ItemChatsScreenState extends State<ItemChatsScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<ChatContactModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final contacts = await _db.getItemChatContacts(widget.item.id);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chats for ${widget.item.title}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No chats yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Messages about this item will appear here.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return Card(
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  itemId: widget.item.id,
                                  itemTitle: widget.item.title,
                                  otherUserId: contact.otherUserId,
                                  otherUserName: contact.otherUserName,
                                ),
                              ),
                            ).then((_) => _loadChats());
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(0.12),
                            child: Text(
                              contact.otherUserName.isNotEmpty
                                  ? contact.otherUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.otherUserName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            contact.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: contact.unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${contact.unreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
