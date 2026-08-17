import 'package:flutter/material.dart';

import '../models/department.dart';

/// إدارات مقترحة افتراضياً لتسريع الإعداد الأولي للمنصة عند خلوّ قاعدة البيانات.
/// يستخدمها مسؤول النظام اختيارياً عبر زر "استيراد الإدارات الافتراضية"،
/// ويمكنه لاحقاً إضافة/تعديل الإدارات يدوياً من شاشة الإدارات.
class DefaultDepartments {
  static List<Department> suggestions() => [
        Department(
          id: 'dept_strategy',
          name: 'إدارة المشاريع الاستراتيجية',
          headName: '',
          colorValue: 0xFF0B3D66,
          icon: Icons.flag_rounded,
        ),
        Department(
          id: 'dept_it',
          name: 'إدارة تقنية المعلومات',
          headName: '',
          colorValue: 0xFF1565A6,
          icon: Icons.memory_rounded,
        ),
        Department(
          id: 'dept_hr',
          name: 'إدارة الموارد البشرية',
          headName: '',
          colorValue: 0xFF2E7D32,
          icon: Icons.people_alt_rounded,
        ),
        Department(
          id: 'dept_finance',
          name: 'إدارة الشؤون المالية',
          headName: '',
          colorValue: 0xFFC9A227,
          icon: Icons.account_balance_rounded,
        ),
        Department(
          id: 'dept_service',
          name: 'إدارة خدمة المتعاملين',
          headName: '',
          colorValue: 0xFFE0692B,
          icon: Icons.support_agent_rounded,
        ),
      ];
}
