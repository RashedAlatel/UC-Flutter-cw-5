// تعديلُ بيانات المشروع — الحقولُ التي تمرّ بالاعتماد، وحسابُ الفروق.
//
// ــــ وحدةٌ نقيّة، ولماذا ــــ
//
// هذا الملفُّ يقرّر **ماذا يُعتمد**، و**أيُّه جوهريّ يُميَّز للمعتمِد**،
// و**عند من يبدأ الطلب**. وثلاثتُها قراراتُ حوكمةٍ لا عرض: خطأٌ في الأولى
// يفتح باباً، وفي الثانية يُمرّر تغييرَ قيمة عقدٍ بلا أن يلحظه أحد، وفي
// الثالثة يجعل مديرَ المشروع يعتمد لنفسه.
//
// فهي هنا بلا Firestore ولا `BuildContext` — يُقاس كلُّ قرارٍ منها وحده،
// وتُقلب كلُّ قاعدةٍ بطفرة. وهو نمطٌ قائم: `splitDeleted` و`diffMaps`
// و`workUpdateOutcome` و`periodic_report.dart`.
//
// ــــ ونظيرُه على الخادم ــــ
//
// `functions/src/approval_stage.ts` يقرّر المرحلة، و`firestore.rules` تمنع
// الكتابة المباشرة. **والثلاثة تُقرأ معاً**: من غيّر واحداً ولم يغيّر أخويه
// فتح ثغرةً أو أغلق باباً مشروعاً. وحارسٌ في `approval_gates_test.sh` يمنع
// أن تفترق قائمةُ الحقول هنا عن قائمة المنع في القاعدة.
library;

import 'enums.dart';
import 'project.dart';

/// الحقولُ التي **لا تُكتب مباشرةً** وتمرّ بمسار الاعتماد.
///
/// وهي نفسُها قائمةُ المنع في `firestore.rules` (فرعُ `projects/update`)
/// **باستثناء** ما له بوابةٌ قائمةٌ بذاتها: الموعدُ النهائي والإدارةُ
/// والعضوية — تلك مساراتُها الخاصّة ولا تمرّ من هنا.
const List<String> kEditableProjectFields = [
  'name',
  'description',
  'priority',
  'categoryIds',
  'contractDate',
  'contractStartDate',
  'contractEndDate',
  'invoiceDueDate',
  'durationDays',
  'contractValue',
  'contractorName',
];

/// الحقولُ **الجوهرية** التي طلبتَ إبرازَها للمعتمِد.
///
/// وليست كلُّ حقول القائمة جوهرية: تصحيحُ وصفٍ ليس كتغيير قيمة عقد. فما
/// يُميَّز هو ما يُغيّر التزاماً أو مسؤوليةً أو موعداً.
///
/// و«الإدارة» و«المدير» و«تاريخ البدء» و«الاستحقاق» في قائمتك جوهريةٌ كذلك،
/// ولا تمرّ من هنا: لها بواباتُها. فتُذكر في القائمة ليُميَّزها العارضُ حين
/// تصله من مسارها، ولا تُقبل في هذا الطلب — راجع [isEditableField].
const Set<String> kSensitiveProjectFields = {
  'name',
  'departmentId',
  'managerUids',
  'startDate',
  'dueDate',
  'contractStartDate',
  'contractEndDate',
  'invoiceDueDate',
  'contractValue',
  'durationDays',
};

bool isEditableField(String field) => kEditableProjectFields.contains(field);
bool isSensitiveField(String field) => kSensitiveProjectFields.contains(field);

/// الاسمُ العربي للحقل — يُعرض في جدول الفروق وفي سجلّ التعديلات.
///
/// ومجهولٌ يُعاد **كما هو** لا مترجَماً: اسمٌ لا نعرفه في جدول اعتمادٍ شذوذٌ
/// يجب أن يُرى، لا أن يُخفى خلف ترجمةٍ مختلقة.
String projectFieldLabel(String field) => switch (field) {
      'name' => 'اسم المشروع',
      'description' => 'الوصف',
      'priority' => 'الأولوية',
      'categoryIds' => 'التصنيفات',
      'contractDate' => 'تاريخ العقد',
      'contractStartDate' => 'تاريخ بداية العقد',
      'contractEndDate' => 'تاريخ انتهاء العقد',
      'invoiceDueDate' => 'تاريخ استحقاق الفاتورة',
      'durationDays' => 'مدة المشروع',
      'contractValue' => 'قيمة العقد',
      'contractorName' => 'الجهة المنفّذة',
      'departmentId' => 'الإدارة',
      'managerUids' => 'مدير المشروع',
      'startDate' => 'تاريخ بدء المشروع',
      'dueDate' => 'تاريخ الاستحقاق',
      _ => field,
    };

/// مرحلةُ الطلب — ومن يبتّ فيها.
enum EditStage {
  /// مديرُ إدارة المشروع.
  departmentManager('مدير الإدارة'),

  /// مسؤولُ النظام — الاعتمادُ النهائي، وعنده وحده يُطبَّق التغيير.
  systemAdmin('مسؤول النظام');

  final String label;
  const EditStage(this.label);

  static EditStage fromName(String? name) =>
      name == EditStage.systemAdmin.name ? EditStage.systemAdmin : EditStage.departmentManager;
}

/// عند من يبدأ الطلب، بحسب **رتبة مقدّمه**.
///
/// مديرُ المشروع يبدأ عند مدير الإدارة، ومديرُ الإدارة يبدأ عند مسؤول النظام
/// مباشرةً — فلا يعتمد أحدٌ طلبَ نفسه. ومسؤولُ النظام لا يقدّم طلباً أصلاً:
/// يعدّل مباشرةً، وقاعدةُ Firestore تسمح له وحده.
EditStage firstStageFor({required bool requesterIsDepartmentManager}) =>
    requesterIsDepartmentManager ? EditStage.systemAdmin : EditStage.departmentManager;

/// فرقٌ في حقلٍ واحد: ما كان، وما سيصير.
class FieldChange {
  final String field;
  final Object? before;
  final Object? after;

  const FieldChange({required this.field, required this.before, required this.after});

  String get label => projectFieldLabel(field);
  bool get isSensitive => isSensitiveField(field);

  Map<String, dynamic> toMap() => {'before': before, 'after': after};

  static FieldChange? fromMap(String field, Object? raw) {
    if (raw is! Map) return null;
    return FieldChange(
      field: field,
      before: raw['before'],
      after: raw['after'],
    );
  }
}

/// ما تغيّر بين المشروع القائم وما أُدخل — **الحقولُ المتغيّرة وحدها**.
///
/// ولا يُرسَل الحقلُ الذي لم يتغيّر: طلبُ اعتمادٍ فيه أحدَ عشرَ سطراً أحدُها
/// وحده تغيّر يُقرأ بعينٍ متعبة، فيمرّ فيه ما لا يُقصد. والمعتمِد يرى ما
/// يبتّ فيه لا ما لم يُمسّ.
///
/// والمقارنةُ بالقيمة لا بالمرجع، والفراغُ يساوي الفراغ: نصٌّ فارغ لم يصر
/// «غير مسجّل»، فلا يُعرض فرقاً.
List<FieldChange> diffProjectFields(Project current, Map<String, Object?> proposed) {
  final out = <FieldChange>[];
  for (final field in kEditableProjectFields) {
    if (!proposed.containsKey(field)) continue;
    final before = _currentValue(current, field);
    final after = proposed[field];
    if (_sameValue(before, after)) continue;
    out.add(FieldChange(field: field, before: before, after: after));
  }
  return out;
}

Object? _currentValue(Project p, String field) => switch (field) {
      'name' => p.name,
      'description' => p.description,
      'priority' => p.priority.name,
      'categoryIds' => p.categoryIds,
      'contractDate' => p.contractDate?.toIso8601String(),
      'contractStartDate' => p.contractStartDate?.toIso8601String(),
      'contractEndDate' => p.contractEndDate?.toIso8601String(),
      'invoiceDueDate' => p.invoiceDueDate?.toIso8601String(),
      'durationDays' => p.durationDays,
      'contractValue' => p.contractValue,
      'contractorName' => p.contractorName,
      _ => null,
    };

bool _sameValue(Object? a, Object? b) {
  // «غير مسجّل» ونصٌّ فارغ شيءٌ واحدٌ في حقلٍ نصّي: من فتح النموذج وأغلقه
  // لا يُنشئ طلباً بلا تغيير.
  if (a == null && b is String && b.trim().isEmpty) return true;
  if (b == null && a is String && a.trim().isEmpty) return true;
  if (a is String && b is String) return a.trim() == b.trim();
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

/// وصفٌ يُقرأ في بطاقة الطلب وفي سجلّ التدقيق.
String describeChanges(List<FieldChange> changes) {
  if (changes.isEmpty) return 'لا تغييرات';
  return changes.map((c) => c.label).join('، ');
}

/// هل في التغييرات ما هو جوهريّ؟ به تُميَّز البطاقة ويُرسل الإشعار.
bool hasSensitiveChange(List<FieldChange> changes) => changes.any((c) => c.isSensitive);

/// الأولويةُ التي تُعطى للطلب — الجوهريُّ أعلى، فيتصدّر قائمة المعتمِد.
PriorityLevel priorityForChanges(List<FieldChange> changes) =>
    hasSensitiveChange(changes) ? PriorityLevel.high : PriorityLevel.medium;
