import 'project.dart';
import 'work_item.dart';
import '../utils/formatters.dart';

/// بيانات الكيان (مشروع أو عمل) التي تُعبَّأ بها قوالب الرسائل الجاهزة.
///
/// يُبنى من [Project] أو [WorkItem] فتعمل القوالب نفسها مع الاثنين دون تكرار.
class NotifyContext {
  /// "المشروع" أو "العمل" — تُستخدم داخل نص الرسالة.
  final String kind;
  final String name;
  final DateTime dueDate;
  final double progressPercent;
  final int delayDays;

  const NotifyContext({
    required this.kind,
    required this.name,
    required this.dueDate,
    required this.progressPercent,
    required this.delayDays,
  });

  factory NotifyContext.fromProject(Project p) => NotifyContext(
        kind: 'المشروع',
        name: p.name,
        dueDate: p.dueDate,
        progressPercent: p.progressPercent,
        delayDays: p.delayDays,
      );

  factory NotifyContext.fromWork(WorkItem w) => NotifyContext(
        kind: 'العمل',
        name: w.title,
        dueDate: w.dueDate,
        progressPercent: w.progressPercent,
        delayDays: w.delayDays,
      );
}

/// قالب رسالة جاهز يُعبَّأ تلقائياً من [NotifyContext].
enum NotifyTemplate {
  deadlineReminder('تذكير بالموعد النهائي'),
  statusUpdate('طلب تحديث الحالة'),
  delayAlert('تنبيه تأخير'),
  completionThanks('شكر على الإنجاز'),
  free('رسالة حرة');

  final String label;
  const NotifyTemplate(this.label);

  /// عنوان الرسالة. فارغ لـ[free] ليكتبه المستخدم بنفسه.
  String subjectFor(NotifyContext? c) {
    if (this == NotifyTemplate.free || c == null) return '';
    final suffix = ' — ${c.name}';
    switch (this) {
      case NotifyTemplate.deadlineReminder:
        return 'تذكير بالموعد النهائي$suffix';
      case NotifyTemplate.statusUpdate:
        return 'طلب تحديث الحالة$suffix';
      case NotifyTemplate.delayAlert:
        return 'تنبيه تأخير$suffix';
      case NotifyTemplate.completionThanks:
        return 'شكر وتقدير$suffix';
      case NotifyTemplate.free:
        return '';
    }
  }

  /// نص الرسالة معبّأً ببيانات الكيان. يبقى قابلاً للتحرير قبل الإرسال.
  String bodyFor(NotifyContext? c) {
    if (this == NotifyTemplate.free || c == null) return '';
    final pct = Formatters.percent(c.progressPercent);
    final due = Formatters.date(c.dueDate);
    switch (this) {
      case NotifyTemplate.deadlineReminder:
        return 'نذكّركم بأن الموعد النهائي لـ${c.kind} "${c.name}" هو $due، '
            'ونسبة الإنجاز الحالية $pct. نرجو استكمال المتبقّي قبل الموعد.';
      case NotifyTemplate.statusUpdate:
        return 'نرجو تحديث حالة ${c.kind} "${c.name}" ونسبة إنجازه على المنصة '
            'في أقرب وقت، لتكون المؤشرات معبّرة عن الوضع الفعلي.';
      case NotifyTemplate.delayAlert:
        return 'نفيدكم بأن ${c.kind} "${c.name}" متأخر ${c.delayDays} يوماً عن الخطة '
            '(نسبة الإنجاز $pct، والموعد النهائي كان $due). نأمل معالجة الأمر '
            'وموافاتنا بأسباب التأخير وخطة الاستدراك.';
      case NotifyTemplate.completionThanks:
        return 'نشكر لكم جهودكم في إنجاز ${c.kind} "${c.name}"، '
            'ونقدّر التزامكم ومستوى الأداء المبذول.';
      case NotifyTemplate.free:
        return '';
    }
  }
}
