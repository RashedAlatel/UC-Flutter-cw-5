///  التقرير التنفيذي اليومي — **قراءةً فقط**.
///
/// ــــ لماذا لا يُحسب هنا؟ ــــ
///
/// لأن التقرير يُقرأ على الشاشة **ويُرسل بالبريد**. وكتابة سبعة أبوابٍ ودرجةِ
/// خطورةٍ مرّتين — مرة في Dart للشاشة ومرة في TypeScript للبريد — تعني أن
/// يفترق النصّان عند أول تعديل يُنسى في أحدهما، فيقرأ المدير على الشاشة غير
/// ما وصله في بريده، ولا يصيح شيء: كلاهما صحيحٌ في نفسه.
///
/// فالحساب في `functions/src/daily_report.ts` مرةً واحدة، ويُكتب ناتجه في
/// `dailyReports/{yyyy-MM-dd}/recipients/{uid}`، وهذا الملفّ يقرؤه ويعرضه.
/// فما تراه على الشاشة هو نصّ ما وصل بالبريد حرفاً.
///
/// ولهذا لا **منطق** هنا إطلاقاً: لا تصنيف، ولا ترتيب، ولا اشتقاق. أي سطرٍ
/// يحسب شيئاً في هذا الملف هو بداية الافتراق نفسه الذي بُني هذا كلّه لمنعه.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// درجة الخطورة كما حسبها الخادم.
enum ReportSeverity {
  critical('critical', 'حرج'),
  needsAttention('needsAttention', 'يحتاج انتباه'),
  normal('normal', 'طبيعي');

  final String key;
  final String label;
  const ReportSeverity(this.key, this.label);

  /// ودرجةٌ مجهولة تُقرأ **أدناها** لا أعلاها: مستندٌ من نسخةِ خادمٍ أحدث
  /// يجب ألّا يصبغ الشاشة بالأحمر لمجرد أن اسم درجته لم يُعرف بعد.
  static ReportSeverity fromKey(String? key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => ReportSeverity.normal,
      );
}

class ReportField {
  final String label;
  final String value;
  const ReportField({required this.label, required this.value});

  factory ReportField.fromMap(Map<String, dynamic> m) => ReportField(
        label: m['label'] as String? ?? '',
        value: m['value'] as String? ?? '',
      );
}

/// سطرٌ في التقرير — ومعه وجهةُ الضغط عليه.
class ReportRow {
  final String key;
  final String title;
  final ReportSeverity severity;
  final String reason;
  final List<ReportField> fields;

  /// معرّف المشروع الذي يفتحه الضغط، أو null.
  final String? linkProjectId;

  /// معرّف العمل الذي يفتحه الضغط، أو null.
  final String? linkWorkId;

  const ReportRow({
    required this.key,
    required this.title,
    required this.severity,
    required this.reason,
    required this.fields,
    this.linkProjectId,
    this.linkWorkId,
  });

  /// هل لهذا السطر وجهة؟ التقرير أداةُ تصرّفٍ لا نصُّ قراءة، فما لا يُفتح
  /// يُعرض بلا إيحاءٍ بأنه يُضغط.
  bool get hasTarget => linkProjectId != null || linkWorkId != null;

  factory ReportRow.fromMap(Map<String, dynamic> m) => ReportRow(
        key: m['key'] as String? ?? '',
        title: m['title'] as String? ?? '',
        severity: ReportSeverity.fromKey(m['severity'] as String?),
        reason: m['reason'] as String? ?? '',
        fields: [
          for (final f in (m['fields'] as List? ?? const []))
            ReportField.fromMap(Map<String, dynamic>.from(f as Map)),
        ],
        linkProjectId: m['linkProjectId'] as String?,
        linkWorkId: m['linkWorkId'] as String?,
      );
}

class ReportSection {
  final String key;
  final String title;

  /// ما يُقال حين لا سطر فيه — وهو خبرٌ جيّد لا فراغ.
  final String emptyNote;
  final List<ReportRow> rows;

  const ReportSection({
    required this.key,
    required this.title,
    required this.emptyNote,
    required this.rows,
  });

  factory ReportSection.fromMap(Map<String, dynamic> m) => ReportSection(
        key: m['key'] as String? ?? '',
        title: m['title'] as String? ?? '',
        emptyNote: m['emptyNote'] as String? ?? 'لا يوجد.',
        rows: [
          for (final r in (m['rows'] as List? ?? const []))
            ReportRow.fromMap(Map<String, dynamic>.from(r as Map)),
        ],
      );
}

class DailyReport {
  final String date;
  final String recipientUid;
  final String recipientName;

  /// ما يغطّيه هذا التقرير — «كل الإدارات» أو «إدارتك» أو ما يقوده.
  final String scopeLabel;

  final int criticalCount;
  final int attentionCount;
  final String headline;

  /// أهم الحالات، مرتَّبةً بالخطورة ثم بأيام التأخير.
  final List<ReportRow> top;
  final List<ReportSection> sections;
  final String generatedAt;

  const DailyReport({
    required this.date,
    required this.recipientUid,
    required this.recipientName,
    required this.scopeLabel,
    required this.criticalCount,
    required this.attentionCount,
    required this.headline,
    required this.top,
    required this.sections,
    required this.generatedAt,
  });

  /// عدد كل ما ظهر في التقرير — يُعرض بجانب اسم كل باب.
  int get rowCount => sections.fold(0, (total, s) => total + s.rows.length);

  factory DailyReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      DailyReport.fromMap(doc.data() ?? const {});

  factory DailyReport.fromMap(Map<String, dynamic> m) => DailyReport(
        date: m['date'] as String? ?? '',
        recipientUid: m['recipientUid'] as String? ?? '',
        recipientName: m['recipientName'] as String? ?? '',
        scopeLabel: m['scopeLabel'] as String? ?? '',
        criticalCount: (m['criticalCount'] as num?)?.toInt() ?? 0,
        attentionCount: (m['attentionCount'] as num?)?.toInt() ?? 0,
        headline: m['headline'] as String? ?? '',
        top: [
          for (final r in (m['top'] as List? ?? const []))
            ReportRow.fromMap(Map<String, dynamic>.from(r as Map)),
        ],
        sections: [
          for (final s in (m['sections'] as List? ?? const []))
            ReportSection.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
        generatedAt: m['generatedAt'] as String? ?? '',
      );
}
