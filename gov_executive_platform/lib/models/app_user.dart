import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class AppUser {
  final String id; // Firebase Auth UID
  final String name;
  final String email;
  final String phone; // بصيغة دولية E.164 مثل ‎+9715xxxxxxxx لإرسال واتساب
  final UserRole role;
  final String? customRoleId; // مرجع لمستند بمجموعة roles عند role == custom
  final String? departmentId; // null لمسؤول النظام والمستخدم التنفيذي
  final UserStatus status;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.customRoleId,
    this.departmentId,
    required this.status,
    required this.createdAt,
  });

  bool get active => status == UserStatus.approved;

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? customRoleId,
    String? departmentId,
    UserStatus? status,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      customRoleId: customRoleId ?? this.customRoleId,
      departmentId: departmentId ?? this.departmentId,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'customRoleId': customRoleId,
        'departmentId': departmentId,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromName(json['role'] as String? ?? UserRole.projectOfficer.name),
      customRoleId: json['customRoleId'] as String?,
      departmentId: json['departmentId'] as String?,
      status: UserStatus.fromName(json['status'] as String? ?? UserStatus.pending.name),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
