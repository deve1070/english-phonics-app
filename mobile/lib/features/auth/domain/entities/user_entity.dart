class UserEntity {
  final int id;
  final String name;
  final String userName;
  final String role;
  final bool isActive;

  const UserEntity({
    required this.id,
    required this.name,
    required this.userName,
    required this.role,
    required this.isActive,
  });
}
