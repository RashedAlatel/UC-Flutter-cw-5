import 'enums.dart';
import 'project.dart';

/// ترتيب صفحة المشاريع.
///
/// ــــ لماذا زال «التصنيف» من هنا؟ ــــ
///
/// كان هذا المنتقي يحمل خياراً اسمه «التصنيف» يُجمّع المشاريع تحت وسومها.
/// وهو خلطٌ بين أمرين: الوسم **صفةٌ** على المشروع تُصفّى بها القائمة، والترتيب
/// **طريقة عرض**. فمن يفتح «ترتيب حسب» لا يريد تغيير فئة المشروع، بل يريد أن
/// يقرّر ما الذي يظهر أولاً.
///
/// والوسوم باقية حيث تنفع: منتقي «تصفية حسب التصنيف» في الصفحة نفسها،
/// وشرائح الوسوم على كل بطاقة. زال التجميعُ لا التصنيف.
enum ProjectSort {
  /// الترتيب المبدئي: المتأخر أولاً، ثم الأقرب استحقاقاً، ثم الأعلى أولوية.
  ///
  /// وهو مبدئيٌّ لأنه يجيب عن السؤال الذي تُفتح الصفحة لأجله: **ما الذي
  /// يحتاجني الآن؟** أما الترتيب بالاسم — وكان المبدئي — فلا يجيب عن شيء:
  /// أول القائمة فيه مشروعٌ اسمه يبدأ بألف، لا مشروعٌ متأخر ثلاثين يوماً.
  smart('الأهم أولاً'),

  dueSoon('الأقرب للاستحقاق'),
  dueLate('الأبعد استحقاقاً'),
  mostDelayed('الأكثر تأخيراً'),
  priority('الأولوية: الأعلى أولاً'),
  progressLow('نسبة الإنجاز: الأقل أولاً'),
  progressHigh('نسبة الإنجاز: الأعلى أولاً'),
  lastUpdated('آخر تحديث: الأحدث'),
  newest('الأحدث إضافةً'),
  oldest('الأقدم إضافةً'),
  name('الاسم أبجدياً');

  final String label;
  const ProjectSort(this.label);

  /// هل يعتمد هذا الترتيب على تاريخ الإضافة؟ (يُنبَّه عندها إلى المشاريع
  /// المستوردة التي لا تحمله.)
  bool get usesCreatedAt => this == ProjectSort.newest || this == ProjectSort.oldest;
}

/// رتبة الأولوية للفرز: الأعلى أولاً.
int _priorityRank(PriorityLevel p) {
  switch (p) {
    case PriorityLevel.critical:
      return 0;
    case PriorityLevel.high:
      return 1;
    case PriorityLevel.medium:
      return 2;
    case PriorityLevel.low:
      return 3;
  }
}

/// يرتّب المشاريع حسب [sort].
///
/// [lastUpdateOf] تاريخ آخر تحديث يومي لكل مشروع — يُبنى من `dailyUpdates`
/// في المتجر، ولا يُخزَّن على المشروع نفسه كي لا يوجد مصدران للحقيقة
/// يفترقان.
///
/// والترتيب **ثابت**: كل مقياس يُذيَّل بمقارنة بالاسم عند التساوي. وبغير ذلك
/// تتبدّل مواضع المشاريع المتساوية بين كل بناءٍ وآخر، فتقفز القائمة تحت يد
/// المستخدم بلا سبب ظاهر.
List<Project> sortProjects({
  required List<Project> projects,
  required ProjectSort sort,
  Map<String, DateTime> lastUpdateOf = const {},
}) {
  final sorted = projects.toList();
  int byName(Project a, Project b) => a.name.compareTo(b.name);

  /// يجمع مقارناتٍ بالترتيب: أول فرقٍ يفوز.
  int chain(List<int> comparisons) {
    for (final c in comparisons) {
      if (c != 0) return c;
    }
    return 0;
  }

  switch (sort) {
    case ProjectSort.smart:
      // الترتيب المطلوب: المتأخر أولاً، ثم الأقرب استحقاقاً، ثم الأعلى أولوية.
      //
      // ــ ولماذا لا طبقةَ «تأخير» مستقلة؟ ــ
      //
      // كتبتُها أولاً `b.delayDays.compareTo(a.delayDays)` قبل تاريخ
      // الاستحقاق، ثم أسقطتها الطفرةُ من الشيفرة **ولم يسقط اختبار واحد**.
      // والسبب أنها لا تفعل شيئاً: `delayDays` مشتقٌّ من تاريخ الاستحقاق
      // نفسه (اليوم ناقص الموعد)، فترتيبُ «الأكثر تأخيراً أولاً» هو بعينه
      // ترتيب «الأقدم استحقاقاً أولاً». طبقةٌ تُوهم القارئ بأنها تحكم شيئاً
      // وهي لا تحكم — فحُذفت، وبقي الشرح.
      //
      // والمكتمل ينزل إلى الآخر مهما كان تاريخه: هو لا «يحتاج أحداً الآن»،
      // ووجوده في الصدارة يزاحم ما يحتاج. وهذه الطبقة **ليست** زائدة:
      // المكتمل قد يكون أقدم الجميع استحقاقاً فيتصدّر بغيرها.
      sorted.sort((a, b) => chain([
            (a.effectiveStatus == ProjectStatus.completed ? 1 : 0)
                .compareTo(b.effectiveStatus == ProjectStatus.completed ? 1 : 0),
            a.dueDate.compareTo(b.dueDate),
            _priorityRank(a.priority).compareTo(_priorityRank(b.priority)),
            byName(a, b),
          ]));
    case ProjectSort.dueSoon:
      // «الأيام المتبقية: الأقل أولاً» هو هذا الترتيب نفسه لا ترتيبٌ آخر:
      // المتبقي = تاريخ الاستحقاق ناقص اليوم، وطرحُ عددٍ واحد من الجميع لا
      // يبدّل ترتيبهم. فخيارٌ ثانٍ بالاسم نفسه يُطيل القائمة ولا يضيف.
      sorted.sort((a, b) => chain([a.dueDate.compareTo(b.dueDate), byName(a, b)]));
    case ProjectSort.dueLate:
      sorted.sort((a, b) => chain([b.dueDate.compareTo(a.dueDate), byName(a, b)]));
    case ProjectSort.mostDelayed:
      sorted.sort((a, b) => chain([b.delayDays.compareTo(a.delayDays), byName(a, b)]));
    case ProjectSort.priority:
      sorted.sort((a, b) => chain([
            _priorityRank(a.priority).compareTo(_priorityRank(b.priority)),
            a.dueDate.compareTo(b.dueDate),
            byName(a, b),
          ]));
    case ProjectSort.progressLow:
      sorted.sort((a, b) => chain([a.progressPercent.compareTo(b.progressPercent), byName(a, b)]));
    case ProjectSort.progressHigh:
      sorted.sort((a, b) => chain([b.progressPercent.compareTo(a.progressPercent), byName(a, b)]));
    case ProjectSort.lastUpdated:
      // من لا تحديث له يقع في الآخر بلا استثناء — لا يُختلق له تاريخ. وهو
      // ترتيبٌ صحيح بذاته: «لم يُحدَّث قطّ» أقدم من أي تحديث مهما قدُم.
      sorted.sort((a, b) {
        final ua = lastUpdateOf[a.id];
        final ub = lastUpdateOf[b.id];
        if ((ua == null) != (ub == null)) return ua == null ? 1 : -1;
        if (ua == null || ub == null) return byName(a, b);
        return chain([ub.compareTo(ua), byName(a, b)]);
      });
    case ProjectSort.newest:
    case ProjectSort.oldest:
      // «الأحدث **إضافةً**» لا بدءاً: مشروعٌ خُطّط بدؤه العام الماضي وأُضيف
      // اليوم هو أحدث ما في القائمة.
      //
      // ــــ ولمَ مرحلتان لا مقارنة واحدة؟ ــــ
      //
      // كانت المقارنة `(b.createdAt ?? b.startDate)` — أي أنها تقارن **تاريخ
      // إضافة** مشروع بـ**تاريخ بدء** آخر. وهذه مقارنة بلا معنى، وأثرها كان
      // قاتلاً: مشاريع الوزارة المستوردة تحمل `startDate` في المستقبل، فكان
      // كل مشروع مستورد يعلو على كل مشروع أضافه المستخدم اليوم.
      //
      // فمن يُعرف تاريخ إضافته يسبق من لا يُعرف بلا استثناء، في الاتجاهين
      // معاً: غياب التاريخ يعني أنه أُضيف قبل أن تبدأ المنصة بتسجيله أصلاً،
      // فلا يجوز أن يتصدّر «الأحدث» ولا أن يتصدّر «الأقدم» بتاريخٍ مختلق.
      final newestFirst = sort == ProjectSort.newest;
      sorted.sort((a, b) {
        final ca = a.createdAt;
        final cb = b.createdAt;
        if ((ca == null) != (cb == null)) return ca == null ? 1 : -1;
        // وبين المجهولة يبقى تاريخ **البدء** فيصلاً: هو كل ما يُعرف عنها،
        // وترتيبها بالاسم يُهدر الإشارة الوحيدة الباقية.
        final ka = ca ?? a.startDate;
        final kb = cb ?? b.startDate;
        return chain([newestFirst ? kb.compareTo(ka) : ka.compareTo(kb), byName(a, b)]);
      });
    case ProjectSort.name:
      sorted.sort(byName);
  }
  return sorted;
}
