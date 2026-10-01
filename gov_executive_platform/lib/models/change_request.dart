/// طلبُ تغييرٍ تقنيّ — **وما يُعتمد لا يكتبه طالبُه**.
///
/// ــــ أينَ يقع القرار ــــ
///
/// [status] ينتقل إلى [ChangeStatus.approved] أو [ChangeStatus.rejected]
/// **من الدالّة الخلفيّة وحدَها**، بعد أن تفحص بطاقةَ المعتمِد. والقاعدةُ
/// تمنع العميلَ من كتابة هاتين الحالتين مهما كان صاحبُه — وإلّا اعتمد
/// كلُّ طالبٍ تغييرَ نفسِه بضغطة.
///
/// وهذا ليس احتياطاً زائداً: التغييرُ التقنيّ يطفئ خادماً ويبدّل إعدادَ
/// شبكة. ولجنةٌ لا تُفرَض على الخادم ليست لجنة.
library;

import 'safe_read.dart';

/// صنفُ التغيير — **وثلاثةٌ لأنّ مسارَها ثلاثة**.
enum ChangeKind {
  /// متكرّرٌ معروفُ الأثر، مُوافَقٌ عليه سلفاً كنوع.
  standard('قياسيّ'),

  /// يحتاج بتّاً قبل التنفيذ.
  normal('عاديّ'),

  /// **يُنفَّذ ثمّ يُراجَع** — عطلٌ يوقف العمل الآن.
  emergency('طارئ');

  final String label;
  const ChangeKind(this.label);

  static ChangeKind fromName(String name) => ChangeKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => ChangeKind.normal,
      );
}

enum ChangeRisk {
  low('منخفض'),
  medium('متوسّط'),
  high('مرتفع');

  final String label;
  const ChangeRisk(this.label);

  static ChangeRisk fromName(String name) => ChangeRisk.values.firstWhere(
        (r) => r.name == name,
        orElse: () => ChangeRisk.medium,
      );
}

enum ChangeStatus {
  draft('مسوّدة'),
  awaitingApproval('بانتظار الاعتماد'),
  approved('مُعتمَد'),
  rejected('مرفوض'),
  implemented('نُفِّذ'),
  rolledBack('أُرجِع'),
  closed('مُغلق');

  final String label;
  const ChangeStatus(this.label);

  static ChangeStatus fromName(String name) => ChangeStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ChangeStatus.draft,
      );

  /// هل ما زال يشغل أحداً؟ — والمرفوضُ والمُرجَعُ والمُغلقُ خرجوا.
  bool get isActive =>
      this == draft || this == awaitingApproval || this == approved || this == implemented;
}

class ChangeRequest {
  final String id;
  final String title;
  final String description;
  final ChangeKind kind;
  final ChangeRisk risk;
  final ChangeStatus status;

  final DateTime? plannedStart;
  final DateTime? plannedEnd;

  /// ــ خطّةُ التراجع ــ
  ///
  /// «ماذا نفعل إن ساء الأمر» يُكتب **قبل** التنفيذ لا بعده: من يكتبها
  /// وهو يرى الشاشةَ حمراء يكتب أوّلَ ما يخطر له.
  final String backoutPlan;

  final String implementerUid;
  final String implementerName;

  final String relatedProblemId;

  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;

  /// ــ المعتمِدُ ووقتُه: تكتبهما الدالّةُ الخلفيّة ــ
  final String approvedByUid;
  final String approvedByName;
  final DateTime? approvedAt;
  final String decisionNote;

  final DateTime? implementedAt;

  /// ــ نُفِّذ طارئاً ولم يُراجَع بعد ــ
  ///
  /// وهو **الحقلُ الذي يمنع أن يصير الاستثناءُ عادة**: تغييرٌ في الإنتاج
  /// بلا اعتمادٍ يبقى ظاهراً في «ما يحتاج تدخّلاً» حتّى يبتّ فيه أحد.
  final bool awaitingReview;

  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  const ChangeRequest({
    required this.id,
    required this.title,
    this.description = '',
    required this.kind,
    required this.risk,
    required this.status,
    this.plannedStart,
    this.plannedEnd,
    this.backoutPlan = '',
    this.implementerUid = '',
    this.implementerName = '',
    this.relatedProblemId = '',
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.approvedByUid = '',
    this.approvedByName = '',
    this.approvedAt,
    this.decisionNote = '',
    this.implementedAt,
    this.awaitingReview = false,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  ChangeRequest copyWith({
    String? title,
    String? description,
    ChangeKind? kind,
    ChangeRisk? risk,
    ChangeStatus? status,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    String? backoutPlan,
    String? implementerUid,
    String? implementerName,
    String? relatedProblemId,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    String? approvedByUid,
    String? approvedByName,
    DateTime? approvedAt,
    String? decisionNote,
    DateTime? implementedAt,
    bool? awaitingReview,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      ChangeRequest(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        kind: kind ?? this.kind,
        risk: risk ?? this.risk,
        status: status ?? this.status,
        plannedStart: plannedStart ?? this.plannedStart,
        plannedEnd: plannedEnd ?? this.plannedEnd,
        backoutPlan: backoutPlan ?? this.backoutPlan,
        implementerUid: implementerUid ?? this.implementerUid,
        implementerName: implementerName ?? this.implementerName,
        relatedProblemId: relatedProblemId ?? this.relatedProblemId,
        createdByUid: createdByUid ?? this.createdByUid,
        createdByName: createdByName ?? this.createdByName,
        createdAt: createdAt ?? this.createdAt,
        approvedByUid: approvedByUid ?? this.approvedByUid,
        approvedByName: approvedByName ?? this.approvedByName,
        approvedAt: approvedAt ?? this.approvedAt,
        decisionNote: decisionNote ?? this.decisionNote,
        implementedAt: implementedAt ?? this.implementedAt,
        awaitingReview: awaitingReview ?? this.awaitingReview,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'kind': kind.name,
        'risk': risk.name,
        'status': status.name,
        'plannedStart': plannedStart,
        'plannedEnd': plannedEnd,
        'backoutPlan': backoutPlan,
        'implementerUid': implementerUid,
        'implementerName': implementerName,
        'relatedProblemId': relatedProblemId,
        'createdByUid': createdByUid,
        'createdByName': createdByName,
        'createdAt': createdAt,
        'approvedByUid': approvedByUid,
        'approvedByName': approvedByName,
        'approvedAt': approvedAt,
        'decisionNote': decisionNote,
        'implementedAt': implementedAt,
        'awaitingReview': awaitingReview,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  factory ChangeRequest.fromMap(String id, Map<String, dynamic> j) => ChangeRequest(
        id: id,
        title: readText(j['title']),
        description: readText(j['description']),
        kind: ChangeKind.fromName(readText(j['kind'])),
        risk: ChangeRisk.fromName(readText(j['risk'])),
        status: ChangeStatus.fromName(readText(j['status'])),
        plannedStart: readDate(j['plannedStart']),
        plannedEnd: readDate(j['plannedEnd']),
        backoutPlan: readText(j['backoutPlan']),
        implementerUid: readText(j['implementerUid']),
        implementerName: readText(j['implementerName']),
        relatedProblemId: readText(j['relatedProblemId']),
        createdByUid: readText(j['createdByUid']),
        createdByName: readText(j['createdByName']),
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        approvedByUid: readText(j['approvedByUid']),
        approvedByName: readText(j['approvedByName']),
        approvedAt: readDate(j['approvedAt']),
        decisionNote: readText(j['decisionNote']),
        implementedAt: readDate(j['implementedAt']),
        awaitingReview: j['awaitingReview'] == true,
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
