import 'project.dart';
import 'project_category.dart';

/// مجموعة معروضة في صفحة المشاريع: عنوان (قد يكون فارغاً) ومشاريعه.
typedef ProjectGroup = ({String label, List<Project> projects});

/// عنوان مجموعة المشاريع التي لا تحمل تصنيفاً معروفاً.
const String kUncategorizedLabel = 'بلا تصنيف';

/// ترتيب صفحة المشاريع.
enum ProjectSort {
  name('الاسم'),
  newest('الأحدث إضافةً'),
  dueDate('تاريخ الاستحقاق'),
  delay('أيام التأخير'),
  progress('نسبة الإنجاز'),
  category('التصنيف');

  final String label;
  const ProjectSort(this.label);
}

/// يرتّب المشاريع أو يجمّعها حسب [sort].
///
/// ــــ لماذا التصنيف **تجميع** لا فرز؟ ــــ
///
/// المشروع يحمل أكثر من تصنيف، و«رتّب حسب التصنيف» بلا معنى لمشروعٍ هو
/// «رقمنة» و«أولوية وزارية» معاً: تحت أيّهما يُوضع؟ فيظهر تحت **كليهما**.
///
/// وهذا النمط قائم في المنصة لا مخترع هنا: بانِي الودجات الحرّة يجمّع
/// بـ`groupLabels` التي تُعيد **قائمة**، فيساهم المشروع الواحد في عدة سلال.
/// وقد أُصلح بها حين كان التجميع حسب `executorLabel` — وهو نصّ واحد يجمع كل
/// الأسماء — يصنع سلةً لكل *تركيبة* أسماء بدل سلة لكل شخص.
///
/// وترتيب المجموعات هو ترتيب [categories] المعرَّف لا ترتيب ما كُتب على
/// المشاريع، فلا يتبدّل شكل الصفحة بتبدّل بيانات مشروع واحد.
///
/// ومشروعٌ كل تصنيفاته محذوفة من الإعدادات يقع في «بلا تصنيف»: المعرّف باقٍ
/// على المستند لكنه لا يدلّ على شيء، فمعاملته كوسم صحيح تصنع مجموعةً بلا اسم.
List<ProjectGroup> groupProjects({
  required List<Project> projects,
  required ProjectSort sort,
  required List<ProjectCategory> categories,
}) {
  if (sort != ProjectSort.category) {
    final sorted = projects.toList();
    switch (sort) {
      case ProjectSort.name:
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case ProjectSort.newest:
        // «الأحدث **إضافةً**» لا بدءاً: مشروعٌ خُطّط بدؤه العام الماضي
        // وأُضيف اليوم هو أحدث ما في القائمة.
        //
        // ومشاريع الوزارة المستوردة لا تحمل `createdAt`، فتُرتَّب بتاريخ
        // بدئها. ولا يُختلق لها تاريخ: `DateTime.now()` يجعل كل مشروع قديم
        // يتصدّر الترتيب كذباً، و`DateTime(1970)` يدفنها كلها في الآخر ولو
        // أُضيفت أمس. وتُقال هذه الحقيقة في الشاشة لا تُخفى.
        sorted.sort((a, b) => (b.createdAt ?? b.startDate).compareTo(a.createdAt ?? a.startDate));
      case ProjectSort.dueDate:
        sorted.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case ProjectSort.delay:
        // الأكثر تأخيراً أولاً — وهو ما يُبحث عنه أصلاً عند الترتيب بالتأخير.
        sorted.sort((a, b) => b.delayDays.compareTo(a.delayDays));
      case ProjectSort.progress:
        // الأقل إنجازاً أولاً، للسبب نفسه.
        sorted.sort((a, b) => a.progressPercent.compareTo(b.progressPercent));
      case ProjectSort.category:
        break; // لا يقع: مستبعَد أعلاه.
    }
    return [(label: '', projects: sorted)];
  }

  final groups = <ProjectGroup>[];
  for (final category in categories) {
    final inGroup = projects.where((p) => p.categoryIds.contains(category.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (inGroup.isNotEmpty) groups.add((label: category.name, projects: inGroup));
  }

  final known = categories.map((c) => c.id).toSet();
  final untagged = projects.where((p) => !p.categoryIds.any(known.contains)).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (untagged.isNotEmpty) groups.add((label: kUncategorizedLabel, projects: untagged));

  return groups;
}
