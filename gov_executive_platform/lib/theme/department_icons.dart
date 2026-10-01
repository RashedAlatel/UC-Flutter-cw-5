import 'package:flutter/material.dart';

/// مجموعة أيقونات ثابتة (const) يمكن اختيارها للإدارات.
///
/// نخزّن بقاعدة البيانات "مفتاح" نصي فقط (مثل "memory") بدل رمز الأيقونة
/// الخام (codePoint)، لأن Flutter يتطلب أن تكون كل قيم [IconData] ثابتة وقت
/// الترجمة حتى يعمل تقليص خطوط الأيقونات (icon tree-shaking) في بناء
/// الإصدار (release) على الويب؛ بناء [IconData] من رقم قادم من قاعدة بيانات
/// وقت التشغيل يفشّل بناء الإصدار بالكامل.
class DepartmentIcons {
  static const Map<String, IconData> byKey = {
    'flag': Icons.flag_rounded,
    'memory': Icons.memory_rounded,
    'people': Icons.people_alt_rounded,
    'account_balance': Icons.account_balance_rounded,
    'support_agent': Icons.support_agent_rounded,
    'business': Icons.business_center_rounded,
    'groups': Icons.groups_rounded,
    'engineering': Icons.engineering_rounded,
    'gavel': Icons.gavel_rounded,
    'school': Icons.school_rounded,
    'local_hospital': Icons.local_hospital_rounded,
    'security': Icons.security_rounded,
  };

  static const String defaultKey = 'account_balance';

  static IconData resolve(String? key) => byKey[key] ?? byKey[defaultKey]!;
}
