import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Department {
  final String id;
  final String name;
  final String headName; // اسم المسؤول عن الإدارة
  final int colorValue;
  final IconData icon;

  const Department({
    required this.id,
    required this.name,
    required this.headName,
    required this.colorValue,
    required this.icon,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
        'name': name,
        'headName': headName,
        'colorValue': colorValue,
        'iconCode': icon.codePoint,
      };

  factory Department.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return Department(
      id: doc.id,
      name: json['name'] as String? ?? '',
      headName: json['headName'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF0B3D66,
      icon: IconData(json['iconCode'] as int? ?? Icons.account_balance_rounded.codePoint,
          fontFamily: 'MaterialIcons'),
    );
  }
}
