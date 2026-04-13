import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_contact_model.dart';
import '../models/item_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<ItemModel> createItem({
    required String type,
    required String title,
    required String description,
    required String imageFileId,
    String? location,
    double? latitude,
    double? longitude,
    String? collegeId,
    List<double>? embedding,
    String? aiCaption,
  }) async {
    final auth = AuthService();
    final data = {
      'type': type,
      'title': title,
      'description': description,
      'image_file_id': imageFileId,
      'location': location ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'user_id': auth.userId,
      'user_name': auth.userName,
      'college_id': collegeId ?? 'default',
      'status': 'open',
      'ai_caption': aiCaption ?? '',
      'embedding': embedding?.map((e) => e.toString()).join(',') ?? '',
    };

    final res = await _client.from('items').insert(data).select().single();
    return _mapToItem(res);
  }

  Future<List<ItemModel>> getItems({String? type, String? status, int limit = 50}) async {
    var query = _client.from('items').select().order('created_at', ascending: false).limit(limit);
    if (type != null) query = _client.from('items').select().eq('type', type).order('created_at', ascending: false).limit(limit);
    final res = await query;
    return (res as List).map((e) => _mapToItem(e)).toList();
  }

  Future<List<ItemModel>> getMyItems() async {
    final res = await _client.from('items').select().eq('user_id', AuthService().userId).order('created_at', ascending: false);
    return (res as List).map((e) => _mapToItem(e)).toList();
  }

  Future<ItemModel> getItem(String itemId) async {
    final res = await _client.from('items').select().eq('id', itemId).single();
    return _mapToItem(res);
  }

  Future<List<ItemModel>> getCandidateItems(String oppositeType) async {
    final res = await _client.from('items').select().eq('type', oppositeType).eq('status', 'open').limit(200);
    return (res as List).map((e) => _mapToItem(e)).toList();
  }

  Future<void> updateItemStatus(String itemId, String status) async {
    await _client.from('items').update({'status': status}).eq('id', itemId);
  }

  Future<void> updateItemAI(String itemId, {required List<double> embedding, required String caption}) async {
    await _client.from('items').update({
      'embedding': embedding.map((e) => e.toString()).join(','),
      'ai_caption': caption,
    }).eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await _client.from('items').delete().eq('id', itemId);
  }

  Future<void> saveUserProfile({
    required String userId,
    required String name,
    required String email,
    String? phone,
    String? collegeId,
    String? collegeName,
    String? whatsapp,
  }) async {
    await _client.from('users').upsert({
      'id': userId,
      'name': name,
      'email': email,
      'phone': phone ?? '',
      'college_id': collegeId ?? 'default',
      'college_name': collegeName ?? '',
      'whatsapp': whatsapp ?? '',
    });
  }

  // ─── Contact & Chat Functions ──────────────────────────────────

  Future<UserModel?> getUserById(String userId) async {
    try {
      final res = await _client.from('users').select().eq('id', userId).single();
      return UserModel.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  Future<MessageModel> sendMessage({
    required String itemId,
    required String receiverId,
    required String message,
  }) async {
    final auth = AuthService();
    final data = {
      'item_id': itemId,
      'sender_id': auth.userId,
      'sender_name': auth.userName,
      'receiver_id': receiverId,
      'message': message,
    };
    final res = await _client.from('messages').insert(data).select().single();
    return MessageModel.fromMap(res);
  }

  /// Get ALL messages for a specific item
  Future<List<MessageModel>> getMessages({
    required String itemId,
    required String otherUserId,
  }) async {
    final myId = AuthService().userId;
    final res = await _client
        .from('messages')
        .select()
        .eq('item_id', itemId)
        .or(
          'and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)',
        )
        .order('created_at', ascending: true);
    return (res as List).map((e) => MessageModel.fromMap(e)).toList();
  }

  Future<List<ChatContactModel>> getItemChatContacts(String itemId) async {
    final myId = AuthService().userId;
    final res = await _client
        .from('messages')
        .select()
        .eq('item_id', itemId)
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);

    final threads = <String, ChatContactModel>{};
    for (final row in (res as List)) {
      final senderId = row['sender_id'] ?? '';
      final receiverId = row['receiver_id'] ?? '';
      final otherUserId = senderId == myId ? receiverId : senderId;
      final inferredName = senderId == myId ? 'User' : (row['sender_name'] ?? 'User');
      final isUnreadIncoming = senderId != myId && receiverId == myId && (row['is_read'] ?? false) == false;

      if (!threads.containsKey(otherUserId)) {
        threads[otherUserId] = ChatContactModel(
          otherUserId: otherUserId,
          otherUserName: inferredName,
          lastMessage: row['message'] ?? '',
          lastMessageAt: row['created_at'] != null
              ? DateTime.parse(row['created_at'])
              : DateTime.now(),
          unreadCount: isUnreadIncoming ? 1 : 0,
        );
      } else if (isUnreadIncoming) {
        final existing = threads[otherUserId]!;
        threads[otherUserId] = ChatContactModel(
          otherUserId: existing.otherUserId,
          otherUserName: existing.otherUserName,
          lastMessage: existing.lastMessage,
          lastMessageAt: existing.lastMessageAt,
          unreadCount: existing.unreadCount + 1,
        );
      }
    }

    return threads.values.toList();
  }

  Future<void> markMessagesAsRead({
    required String itemId,
    required String senderId,
  }) async {
    final myId = AuthService().userId;
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('item_id', itemId)
        .eq('sender_id', senderId)
        .eq('receiver_id', myId);
  }

  ItemModel _mapToItem(Map<String, dynamic> map) {
    List<double>? embedding;
    if (map['embedding'] != null && (map['embedding'] as String).isNotEmpty) {
      embedding = (map['embedding'] as String).split(',').where((s) => s.isNotEmpty).map((s) => double.tryParse(s) ?? 0.0).toList();
    }
    return ItemModel(
      id: map['id'].toString(),
      type: map['type'] ?? 'lost',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageFileId: map['image_file_id'] ?? '',
      location: map['location'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Unknown',
      collegeId: map['college_id'],
      status: map['status'] ?? 'open',
      embedding: embedding,
      aiCaption: map['ai_caption'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }
}