import '../data/app_store.dart';
import '../models/enums.dart';
import '../models/role_permissions.dart';

/// شاشات القائمة الجانبية — **قراراً لا صفحات**.
///
/// ــــ لماذا مفصولةٌ عن `app_shell.dart`؟ ــــ
///
/// لأن الشلّ يستورد كل شاشة في المنصة، ومنها ما يستورد `package:web` (شريط
/// التحديث يقرأ عنوان الصفحة ويعيد التحميل). فلا يُستورَد الشلّ من اختبارٍ
/// يعمل على جهاز Dart الافتراضي إطلاقاً — أي أن **قرارات القائمة كلها كانت
/// خارج مدى أي اختبار**.
///
/// وهي أخطر ما في المنصة سكوتاً: شرطٌ واحدٌ خاطئ يحجب صفحةً كاملة عن دور
/// كامل، ولا يظهر ذلك في تحليلٍ ولا اختبار — بل في شكوى مستخدم. وقد وقع:
/// «المُسنَد إليّ» كانت محجوبة عن مسؤول النظام والمستخدم التنفيذي بشرط
/// `!canViewAllDepartments`.
///
/// فصار القرار هنا: قائمةُ **مفاتيح** خالصة تُبنى من المتجر وحده، والشلّ
/// يترجم كل مفتاح إلى صفحته. والمفاتيح تُختبر.
enum NavKey {
  dashboard('لوحة القيادة'),
  departments('الإدارات'),
  myDepartments('إداراتي'),
  myDepartment('إدارتي'),
  projects('المشاريع'),
  works('الأعمال'),
  myAssignments('المُسنَد إليّ'),
  decisions('مركز القرارات'),
  dailyReport('التقرير اليومي'),
  reports('التقارير'),
  periodicReports('التقارير الدورية'),
  feedback('الشكاوى والاقتراحات'),
  people('متابعة الأشخاص'),
  auditLog('سجل التدقيق'),
  archived('المحذوفات'),
  users('المستخدمون'),
  roles('إدارة الأدوار'),
  rolePermissions('صلاحيات الأدوار'),
  registration('سياسة التسجيل'),
  appearance('إعدادات المظهر');

  final String label;
  const NavKey(this.label);
}

/// مفاتيح القائمة الجانبية لهذا المستخدم، بترتيب ظهورها.
///
/// كان «مدير المشروع» يُعطى قائمةً بمشاريعه المُسنَدة وحدها — بلا لوحة قيادة
/// ولا تبويب مشاريع إطلاقاً. فلم يكن له طريق إلى مشاريع إدارته ليضيف نفسه
/// على أحدها. صار يأخذ الشاشات نفسها كبقية الأدوار.
List<NavKey> navKeysFor(AppStore store) {
  final keys = <NavKey>[];

  // لوحة القيادة بمفتاح: مغلقة لدور «موظف» افتراضياً، ومسؤول النظام يفتحها
  // لدور أو لفرد. ومسؤول النظام نفسه لا يُفحص — صلاحياته كاملة عبر isAdmin.
  if (store.hasPermission(RolePermission.viewDashboard)) keys.add(NavKey.dashboard);

  if (!store.hasPermission(RolePermission.viewDepartmentPage)) {
    // بلا مدخل إدارة إطلاقاً — ويبقى «المشاريع» و«الأعمال» و«المُسنَد إليّ»
    // فلا تخلو شاشته.
  } else if (store.canViewAllDepartments) {
    keys.add(NavKey.departments);
  } else if (store.isManager) {
    // مدير الإدارة قد يدير أكثر من إدارة، فيرى شاشة «الإدارات» نفسها
    // (تُصفَّى عبر `visibleDepartments`) بدل صفحة إدارة واحدة ثابتة.
    keys.add(store.myDepartmentIds.length > 1 ? NavKey.myDepartments : NavKey.myDepartment);
  } else if (store.currentUser?.departmentId != null) {
    keys.add(NavKey.myDepartment);
  }

  keys.add(NavKey.projects);
  keys.add(NavKey.works);

  // ــ «المُسنَد إليّ» لكل مستخدم بلا استثناء ــ
  //
  // بقية الشاشات مبنية على **الإدارة**، وهذه على **العضوية**: فمن أُسنِد
  // إليه مشروع أو عمل في إدارة أخرى يجده هنا بدل أن يبحث عنه بين ما ليس له.
  //
  // وكانت مشروطةً بـ`!canViewAllDepartments` بحجّة أن من يرى كل الإدارات
  // «لوحته أصلاً هي كل شيء». وهي حجّة خاطئة: **رؤية كل شيء ليست معرفة ما هو
  // عليّ أنا**. ومسؤول النظام قد يكون مدير مشروعٍ ومنفّذ عملٍ كغيره.
  //
  // ولا تُشترط عضويةٌ لعرض المدخل: من لا عضوية له يرى حالاً فارغةً تقول
  // ذلك — لا مدخلاً يظهر ويختفي بتبدّل بياناته فيظنّه عطلاً.
  keys.add(NavKey.myAssignments);

  // مركز القرارات لمن يعتمد فعلاً قراراً فيه.
  //
  // وكان معلَّقاً بصلاحية «اعتماد القرارات العامة» وحدها. ثم صار على مدير
  // الإدارة أن يعتمد **تعيين مدير مشروع** في إدارته — فلم يكن يجد الشاشة
  // التي يعتمد فيها، ويبقى الطلب معلّقاً بلا أن يعرف أحدٌ لماذا.
  //
  // فصار المدخل يظهر كذلك لمن عليه طلبٌ معلّق يستطيع البتّ فيه. وهو أصدق
  // شرطٍ ممكن: يُبنى من الطلبات نفسها لا من قائمة أنواعٍ تُنسى عند إضافة
  // نوعٍ جديد — وقد نُسيت مرة.
  if (store.hasPermission(RolePermission.approveGeneralDecisions) ||
      store.approvalsIOwe.isNotEmpty) {
    keys.add(NavKey.decisions);
  }

  // ــ التقرير التنفيذي اليومي: للمستوى الإشرافي وحده ــ
  //
  // بقرار صريح: لا نسخة للموظف العادي. والشرط في `canReadDailyReport`
  // **يطابق `scopesFor` على الخادم** حرفاً — فمن يظهر له المدخل هو من
  // يُولَّد له مستند. ولو افترقا لَوجد مستخدمٌ مدخلاً يفتح كل يوم على
  // «لم يُولَّد تقريرك» بلا سبب مفهوم.
  if (store.canReadDailyReport) keys.add(NavKey.dailyReport);

  if (store.currentUser?.role != UserRole.projectOfficer &&
      store.currentUser?.role != UserRole.employee) {
    keys.add(NavKey.reports);
  }

  // ــ التقارير الدورية: لمن يُتابع أداء غيره ــ
  //
  // الشرط في `canViewPeriodicReports` لا هنا، فهو نفسُه الذي يُبنى به نطاق
  // `periodicReportInput` — ولو كُتب في موضعين لَافترقا: مدخلٌ يظهر وتقريرٌ
  // يخرج فارغاً، أو صفحةٌ تُحجب عمّن يملك بياناتها.
  if (store.canViewPeriodicReports) keys.add(NavKey.periodicReports);

  // الشكاوى: يظهر المدخل لمن يرفع أو لمن يتابع الوارد. ومن رفع شيئاً سابقاً
  // ثم سُحبت منه صلاحية الرفع يبقى المدخل ليتابع ردّه.
  if (store.canSubmitFeedback || store.canManageFeedback || store.myFeedback.isNotEmpty) {
    keys.add(NavKey.feedback);
  }
  if (store.canTrackPeople) keys.add(NavKey.people);
  if (store.canViewAuditLog) keys.add(NavKey.auditLog);
  if (store.isAdmin) keys.add(NavKey.archived);
  if (store.canManageUsers) {
    keys
      ..add(NavKey.users)
      ..add(NavKey.roles)
      ..add(NavKey.rolePermissions);
  }
  if (store.isAdmin) {
    keys
      ..add(NavKey.registration)
      ..add(NavKey.appearance);
  }
  return keys;
}
