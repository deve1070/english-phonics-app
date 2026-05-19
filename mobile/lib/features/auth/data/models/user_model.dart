import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.userName,
    required super.role,
    required super.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString();
    final fatherName = (json['father_name'] ?? '').toString();
    final fullName = [firstName, fatherName]
        .where((e) => e.trim().isNotEmpty)
        .join(' ')
        .trim();

    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? (fullName.isNotEmpty ? fullName : '')).toString(),
      userName: (json['user_name'] ?? json['username'] ?? '').toString(),
      role: (json['role'] ?? 'student').toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'user_name': userName,
        'role': role,
        'is_active': isActive,
      };
}
