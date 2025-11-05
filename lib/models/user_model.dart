class UserModel {
  final String userId;
  final String fullName;
  final String department;
  final String role;

  UserModel({
    required this.userId,
    required this.fullName,
    required this.department,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] ?? '',
      department: json['department'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'department': department,
      'role': role,
    };
  }
}

