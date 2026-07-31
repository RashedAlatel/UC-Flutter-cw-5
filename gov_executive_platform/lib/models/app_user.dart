import 'enums.dart';

class AppUser {
  final String id;
  final String name;
  final String username;
  final String password;
  final UserRole role;
  final String? departmentId; // null لمسؤول النظام والمستخدم التنفيذي
  final bool active;

  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    this.departmentId,
    this.active = true,
  });

  AppUser copyWith({
    String? name,
    String? username,
    String? password,
    UserRole? role,
    String? departmentId,
    bool? active,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      departmentId: departmentId ?? this.departmentId,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'role': role.name,
        'departmentId': departmentId,
        'active': active,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        role: UserRole.fromName(json['role'] as String),
        departmentId: json['departmentId'] as String?,
        active: json['active'] as bool? ?? true,
      );
}
