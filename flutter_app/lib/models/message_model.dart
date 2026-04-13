class MessageModel {
  final String id;
  final String itemId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.itemId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      itemId: map['item_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      receiverId: map['receiver_id'] ?? '',
      message: map['message'] ?? '',
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'sender_id': senderId,
      'sender_name': senderName,
      'receiver_id': receiverId,
      'message': message,
    };
  }
}