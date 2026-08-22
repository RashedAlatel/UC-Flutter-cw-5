// ــــ قاعدة الإسناد الواحدة: من يحقّ له أن يُسنِد إلى مَن ــــ
//
// كانت كل شاشة تبني قائمة مرشَّحيها بنفسها، وبالمعيار نفسه الضيّق:
// `status == approved` + الانتماء للإدارة. ولا شيء في هذا المعيار يعرف
// **الهرمية** إطلاقاً. فكان الموظف يفتح «إضافة عمل» فيجد **المسؤول
// التنفيذي** في قائمة المسؤولين، ومدير المشروع يضيف **مدير الإدارة**
// منفّذاً عنده.
//
// وإصلاح شاشةٍ شاشة يُعيد العطل من الشاشة التي لم تُصلَح. فالقرار هنا:
// **دالّة واحدة** تُغذّي المواضع الخمسة كلها، والخادم يرفض ما يخالفها.
//
// وهذا الملف بلا `flutter` ولا `provider` عمداً — دوالّ خالصة تُختبر على
// جهاز Dart مباشرةً، كما فُعل بـ`nav_entries.dart` لسببٍ مطابق.

import 'app_user.dart';
import 'enums.dart';


/// رتبة الإسناد لكل دور.
///
/// **ولماذا رقمٌ لا جدول «من يصلح لماذا»؟** لأن الجدول يتضاعف: حقل المديرين
/// وحقل المنفّذين والمسؤول عن العمل، في خمسة أدوار، تسعون خانة تُملأ يدوياً
/// وتتناقض عند أول إضافة. والرقم قاعدةٌ واحدة تُنتج الجدول كله.
///
/// و**الدور المخصّص = 2** قرارٌ صريح لا سهو: جعلُه 1 يجعل أي موظف يُسنِد
/// إليه، وجعلُه 4 يحجبه عن مدير الإدارة. والوسط أقلّ الضررين.
int assignRank(UserRole role) {
  switch (role) {
    case UserRole.systemAdmin:
      return 5;
    case UserRole.executiveViewer:
      return 4;
    case UserRole.departmentManager:
      return 3;
    case UserRole.projectOfficer:
      return 2;
    case UserRole.custom:
      return 2;
    case UserRole.employee:
      return 1;
  }
}

/// هل ينتمي [user] إلى الإدارة [departmentId]؟
///
/// إدارةٌ فارغة أو معدومة تعني «بلا نطاق» — كما في مشروعٍ بلا إدارة — فلا
/// تُقصي أحداً. ومدير الإدارة قد يدير أكثر من واحدة، فتُفحص القائمتان.
bool inDepartment(AppUser user, String? departmentId) {
  if (departmentId == null || departmentId.isEmpty) return true;
  return user.departmentId == departmentId || user.departmentIds.contains(departmentId);
}

/// هل يحقّ لـ[actor] أن يُسنِد إلى [target]؟
///
/// القاعدة: رتبة الهدف **أقل أو تساوي** رتبة الفاعل. والمساواة مقصودة —
/// «الموظف يُسنِد إلى زميله» و«يُسنِد إلى نفسه» كلاهما منها، فلا استثناء
/// مكتوب للنفس.
///
/// ومسؤول النظام بلا قيد: رتبته 5 وهي الأعلى، فالقاعدة نفسها تكفله.
bool canAssignTo({
  required AppUser? actor,
  required AppUser target,
  String? departmentId,
}) {
  if (actor == null) return false;
  if (target.status != UserStatus.approved) return false;
  if (!inDepartment(target, departmentId)) return false;
  return assignRank(target.role) <= assignRank(actor.role);
}

/// المستخدمون الذين يحقّ لـ[actor] إسناد عملٍ أو مشروع إليهم.
///
/// مرتَّبة بالاسم، وهي ما يُمرَّر إلى `PersonPicker` وإلى كل قائمة اختيار
/// في المنصة. وعقد المنتقي أن **المستدعي يصفّي** — وهذا هو المصفّي.
List<AppUser> eligibleAssignees({
  required Iterable<AppUser> allUsers,
  required AppUser? actor,
  String? departmentId,
  /// معرّفات تُستبعَد بعد التصفية — كمن هو مديرٌ الآن في نافذة تغيير المدير.
  Set<String> exclude = const {},
}) {
  if (actor == null) return const [];
  final list = allUsers
      .where((u) => !exclude.contains(u.id))
      .where((u) => canAssignTo(actor: actor, target: u, departmentId: departmentId))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return list;
}

/// لماذا لا يظهر أحد في القائمة — نصٌّ يُعرض بدل صندوقٍ خالٍ يبدو عطلاً.
///
/// والفرق بين السببين ليس تجميلاً: «لا أحد في الإدارة» يُعالَج بإضافة موظف،
/// و«كلّهم أعلى منك» يُعالَج بأن يُسنِد من هو أعلى — ولا يُخلط بينهما.
String emptyAssigneeReason({
  required Iterable<AppUser> allUsers,
  required AppUser? actor,
  String? departmentId,
  Set<String> exclude = const {},
}) {
  if (actor == null) return 'لا يوجد مستخدم مسجَّل.';
  // و[exclude] يُطبَّق هنا كما يُطبَّق هناك: من استُبعد لأنه مديرٌ الآن ليس
  // «أعلى رتبةً» — وقولُ ذلك عنه يوجّه القارئ إلى علاجٍ لا يعالج شيئاً.
  final inDept = allUsers
      .where((u) =>
          !exclude.contains(u.id) &&
          u.status == UserStatus.approved &&
          inDepartment(u, departmentId))
      .toList();
  if (inDept.isEmpty) {
    return 'لا يوجد حساب معتمَد في هذه الإدارة بعد.';
  }
  return 'لا يوجد من يمكنك الإسناد إليه هنا: من في هذه الإدارة أعلى منك في '
      'ترتيب الإسناد. الإسناد إلى من هو أعلى يقوم به مسؤول النظام.';
}
