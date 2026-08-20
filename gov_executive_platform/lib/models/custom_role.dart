import 'package:cloud_firestore/cloud_firestore.dart';

/// دور مخصص يُنشئه مسؤول النظام بمجموعة صلاحيات يختارها بنفسه، إضافة إلى
/// الأدوار الأساسية الأربعة الثابتة. لا تشمل الصلاحيات المخصصة أبداً بوابات
/// الموافقة الثلاث (تسجيل عضو / إضافة مشروع / تعديل موعد نهائي) التي تبقى
/// حصراً لمسؤول النظام (systemAdmin) بحسب متطلبات المنصة الأساسية.
class CustomRole {
  final String id;
  final String name;
  final bool viewAllDepartments; // عرض كل الإدارات (مثل المستخدم التنفيذي)
  final bool manageReports; // توليد التقارير وتحرير التعليقات عليها
  final bool manageDashboard; // تخصيص ودجات لوحة القيادة
  final bool approveGeneralDecisions; // اعتماد/رفض القرارات التنفيذية العامة
  final bool selfAssignProjects; // الاطلاع على مشاريع إدارته وتسجيل نفسه عليها

  // ملاحظة: سجل التدقيق ("viewAuditLog") أُزيل عمداً من الصلاحيات القابلة
  // للتفويض — يبقى الاطلاع عليه حصراً لمسؤول النظام في كل الأحوال.
  const CustomRole({
    required this.id,
    required this.name,
    this.viewAllDepartments = false,
    this.manageReports = false,
    this.manageDashboard = false,
    this.approveGeneralDecisions = false,
    this.selfAssignProjects = false,
  });

  /// مفاتيح مختصرة للتوافق مع حد حجم Custom Claims في Firebase Auth.
  Map<String, dynamic> toClaimsMap() => {
        'vad': viewAllDepartments,
        'mr': manageReports,
        'md': manageDashboard,
        'agd': approveGeneralDecisions,
        'sap': selfAssignProjects,
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'viewAllDepartments': viewAllDepartments,
        'manageReports': manageReports,
        'manageDashboard': manageDashboard,
        'approveGeneralDecisions': approveGeneralDecisions,
        'selfAssignProjects': selfAssignProjects,
      };

  factory CustomRole.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return CustomRole(
      id: doc.id,
      name: json['name'] as String? ?? '',
      viewAllDepartments: json['viewAllDepartments'] as bool? ?? false,
      manageReports: json['manageReports'] as bool? ?? false,
      manageDashboard: json['manageDashboard'] as bool? ?? false,
      approveGeneralDecisions: json['approveGeneralDecisions'] as bool? ?? false,
      selfAssignProjects: json['selfAssignProjects'] as bool? ?? false,
    );
  }
}
