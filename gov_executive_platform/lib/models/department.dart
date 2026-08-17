import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/department_icons.dart';

class Department {
  final String id;
  final String name;
  final String headName; // اسم المسؤول عن الإدارة
  final int colorValue;
  final String iconKey; // مفتاح ضمن DepartmentIcons.byKey

  const Department({
    required this.id,
    required this.name,
    required this.headName,
    required this.colorValue,
    required this.iconKey,
  });

  Color get color => Color(colorValue);
  IconData get icon => DepartmentIcons.resolve(iconKey);

  Map<String, dynamic> toMap() => {
        'name': name,
        'headName': headName,
        'colorValue': colorValue,
        'iconKey': iconKey,
      };

  factory Department.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return Department(
      id: doc.id,
      name: json['name'] as String? ?? '',
      headName: json['headName'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF0B3D66,
      iconKey: json['iconKey'] as String? ?? DepartmentIcons.defaultKey,
    );
  }
}
