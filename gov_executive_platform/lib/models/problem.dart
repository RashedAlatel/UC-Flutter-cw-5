/// مشكلةٌ تحت بلاغاتٍ متكرّرة — **السببُ لا العَرَض**.
///
/// ــــ ما تفترق به عن البلاغ ــــ
///
/// البلاغُ يقول «الطابعةُ لا تعمل اليوم»، والمشكلةُ تقول «طابعاتُ الطابق
/// الثاني تتعطّل كلَّ أسبوعٍ منذ شهرين». فالأوّلُ يُغلق بإصلاحٍ، والثانيةُ
/// لا تُغلق حتّى يُعرف السبب — وإلّا عادت في بلاغٍ ثالثٍ ورابع.
///
/// ــــ والربطُ من جهة البلاغ ــــ
///
/// لا قائمةَ `linkedTicketIds` هنا: قائمةٌ في مستند المشكلة تحتاج كتابتين
/// متّسقتين عند كلّ ربطٍ وفكّ، وحقلٌ واحدٌ على البلاغ ([Ticket.problemId])
/// يحتاج واحدة. **وعددُ البلاغات يُحسب ولا يُخزَّن** — كما لم يُخزَّن
/// تجاوزُ المدّة، ولسببه: المخزَّنُ المشتقُّ يتناقض مع أصله.
library;

import 'enums.dart';
import 'safe_read.dart';

/// حالةُ المشكلة — **وأربعٌ منها ليست حالةَ حلّ**.
///
/// و«حلٌّ مؤقّت» حالةٌ قائمةٌ بذاتها لا خطوةٌ نحو الإغلاق: المستفيدُ يعمل،
/// والسببُ باقٍ. وجمعُها مع «حُلَّت» يُخفي دَيناً تقنيّاً سيُدفع لاحقاً.
enum ProblemStatus {
  investigating('قيد التحليل'),
  workaroundFound('حلٌّ مؤقّت'),
  rootCauseFound('عُرف السبب'),
  resolved('حُلَّت'),
  closed('مُغلقة');

  final String label;
  const ProblemStatus(this.label);

  static ProblemStatus fromName(String name) => ProblemStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ProblemStatus.investigating,
      );

  bool get isActive => this != resolved && this != closed;
}

class Problem {
  final String id;
  final String title;

  /// وصفُ النمط: ما الذي يتكرّر، وعلى مَن، ومنذ متى.
  final String statement;

  final PriorityLevel priority;
  final ProblemStatus status;

  final String ownerUid;
  final String ownerName;

  /// السببُ الجذريّ — ويبقى فارغاً حتّى يُعرف. ولا يُختلق.
  final String rootCause;

  /// ما يُعمل به ريثما يُصلَح السبب.
  final String workaround;

  final String createdByUid;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  const Problem({
    required this.id,
    required this.title,
    this.statement = '',
    required this.priority,
    required this.status,
    required this.ownerUid,
    required this.ownerName,
    this.rootCause = '',
    this.workaround = '',
    required this.createdByUid,
    required this.createdAt,
    this.resolvedAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  /// كلُّ حقلٍ هنا له نظيرُه في [toMap] — راجع تحذيرَ `project.dart`.
  Problem copyWith({
    String? title,
    String? statement,
    PriorityLevel? priority,
    ProblemStatus? status,
    String? ownerUid,
    String? ownerName,
    String? rootCause,
    String? workaround,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? resolvedAt,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      Problem(
        id: id,
        title: title ?? this.title,
        statement: statement ?? this.statement,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        ownerUid: ownerUid ?? this.ownerUid,
        ownerName: ownerName ?? this.ownerName,
        rootCause: rootCause ?? this.rootCause,
        workaround: workaround ?? this.workaround,
        createdByUid: createdByUid ?? this.createdByUid,
        createdAt: createdAt ?? this.createdAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'statement': statement,
        'priority': priority.name,
        'status': status.name,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'rootCause': rootCause,
        'workaround': workaround,
        'createdByUid': createdByUid,
        'createdAt': createdAt,
        'resolvedAt': resolvedAt,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  factory Problem.fromMap(String id, Map<String, dynamic> j) => Problem(
        id: id,
        title: readText(j['title']),
        statement: readText(j['statement']),
        priority: PriorityLevel.fromName(
            readText(j['priority']).isEmpty ? PriorityLevel.medium.name : readText(j['priority'])),
        status: ProblemStatus.fromName(readText(j['status'])),
        ownerUid: readText(j['ownerUid']),
        ownerName: readText(j['ownerName']),
        rootCause: readText(j['rootCause']),
        workaround: readText(j['workaround']),
        createdByUid: readText(j['createdByUid']),
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        resolvedAt: readDate(j['resolvedAt']),
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
