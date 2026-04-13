class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? collegeId;
  final String? collegeName;
  final String? whatsapp;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.collegeId,
    this.collegeName,
    this.whatsapp,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      collegeId: map['college_id'],
      collegeName: map['college_name'],
      whatsapp: map['whatsapp'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'college_id': collegeId,
      'college_name': collegeName,
      'whatsapp': whatsapp,
    };
  }
}