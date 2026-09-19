/// حدثٌ على تقويم القطاع — **مُشتقٌّ لا مُخزَّن**.
///
/// ــــ ولماذا لا مجموعةَ أحداث ــــ
///
/// كلُّ ما يُعرض على هذا التقويم مكتوبٌ في المنصّة أصلاً: موعدُ استحقاق
/// المشروع، وبدايتُه، ونهايةُ عقده، وموعدُ فاتورته، ومواعيدُ المهامّ
/// والأعمال، والعطلُ الرسميّة.
///
/// ومجموعةٌ ثانيةٌ تحمل نسخةً من هذه التواريخ كانت ستنحرف عنها بأوّل تعديل:
/// يُؤجَّل موعدُ المشروع فيبقى الحدثُ على تاريخه القديم، ولا شيء يقول
/// لماذا. وهو بعينه العطلُ الذي وقع في هذه المنصّة بين حالة المشروع
/// المخزَّنة وحالته الفعليّة.
///
/// **فالتقويمُ يُشتقّ عند العرض**، ولا يُخزَّن حرفٌ منه.
library;

/// بابُ الحدث — وبه تقع التصفية والصبغ.
enum EventKind {
  projectStart('بداية مشروع'),
  projectDue('استحقاق مشروع'),
  contractEnd('انتهاء عقد'),
  invoiceDue('استحقاق فاتورة'),
  taskDue('استحقاق مهمّة'),
  workDue('استحقاق عمل'),
  nextAction('خطوة تالية'),
  holiday('عطلة رسميّة');

  final String label;
  const EventKind(this.label);
}

class CalendarEvent {
  final DateTime day;
  final EventKind kind;
  final String title;

  /// الإدارةُ — وبها تقع التصفية. وفارغةٌ للعطل: هي للوزارة كلِّها.
  final String departmentId;

  /// معرّفُ السجلّ الذي اشتُقّ منه — لتُفتح تفاصيلُه.
  final String recordId;

  /// أمضى موعدُه ولم يتمّ؟ — يُصبغ به اليوم.
  final bool isOverdue;

  const CalendarEvent({
    required this.day,
    required this.kind,
    required this.title,
    this.departmentId = '',
    this.recordId = '',
    this.isOverdue = false,
  });

  /// يومٌ بلا وقت — مفتاحُ التجميع في التقويم.
  DateTime get dayOnly => DateTime(day.year, day.month, day.day);
}
