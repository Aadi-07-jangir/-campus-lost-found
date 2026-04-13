class ItemModel {
  final String id;
  final String type;
  final String title;
  final String description;
  final String imageFileId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String userId;
  final String userName;
  final String? collegeId;
  final String status;
  final List<double>? embedding;
  final String? aiCaption;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.imageFileId,
    this.location,
    this.latitude,
    this.longitude,
    required this.userId,
    required this.userName,
    this.collegeId,
    this.status = 'open',
    this.embedding,
    this.aiCaption,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLost => type == 'lost';
  bool get isFound => type == 'found';
  bool get isOpen => status == 'open';

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'image_file_id': imageFileId,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
      'user_name': userName,
      'college_id': collegeId,
      'status': status,
      'embedding': embedding?.map((e) => e.toString()).join(',') ?? '',
      'ai_caption': aiCaption ?? '',
    };
  }

  ItemModel copyWith({
    String? status,
    List<double>? embedding,
    String? aiCaption,
  }) {
    return ItemModel(
      id: id,
      type: type,
      title: title,
      description: description,
      imageFileId: imageFileId,
      location: location,
      latitude: latitude,
      longitude: longitude,
      userId: userId,
      userName: userName,
      collegeId: collegeId,
      status: status ?? this.status,
      embedding: embedding ?? this.embedding,
      aiCaption: aiCaption ?? this.aiCaption,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
