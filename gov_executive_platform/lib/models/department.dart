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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'headName': headName,
        'colorValue': colorValue,
        'iconCode': icon.codePoint,
      };

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as String,
        name: json['name'] as String,
        headName: json['headName'] as String,
        colorValue: json['colorValue'] as int,
        icon: IconData(json['iconCode'] as int, fontFamily: 'MaterialIcons'),
      );
}
