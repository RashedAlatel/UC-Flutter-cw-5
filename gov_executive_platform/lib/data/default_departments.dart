import '../models/department.dart';

/// إدارات مقترحة افتراضياً لتسريع الإعداد الأولي للمنصة عند خلوّ قاعدة البيانات.
/// يستخدمها مسؤول النظام اختيارياً عبر زر "استيراد الإدارات الافتراضية"،
/// ويمكنه لاحقاً إضافة/تعديل الإدارات يدوياً من شاشة الإدارات.
class DefaultDepartments {
  static List<Department> suggestions() => const [
        Department(
          id: 'dept_strategy',
          name: 'إدارة المشاريع الاستراتيجية',
          headName: '',
          colorValue: 0xFF0B3D66,
          iconKey: 'flag',
        ),
        Department(
          id: 'dept_it',
          name: 'إدارة تقنية المعلومات',
          headName: '',
          colorValue: 0xFF1565A6,
          iconKey: 'memory',
        ),
        Department(
          id: 'dept_hr',
          name: 'إدارة الموارد البشرية',
          headName: '',
          colorValue: 0xFF2E7D32,
          iconKey: 'people',
        ),
        Department(
          id: 'dept_finance',
          name: 'إدارة الشؤون المالية',
          headName: '',
          colorValue: 0xFFC9A227,
          iconKey: 'account_balance',
        ),
        Department(
          id: 'dept_service',
          name: 'إدارة خدمة المتعاملين',
          headName: '',
          colorValue: 0xFFE0692B,
          iconKey: 'support_agent',
        ),
      ];
}
