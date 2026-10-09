class UserProfile {
  final String id;
  final String fullName;
  final String phone;
  final String role;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      fullName: map['full_name'],
      phone: map['phone'],
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'role': role,
    };
  }
}