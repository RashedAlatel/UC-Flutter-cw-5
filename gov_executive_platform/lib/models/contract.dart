/// عقدٌ تقنيّ — **لما ليس له مشروع**.
///
/// ــــ ولماذا هذا القيد ــــ
///
/// `Project` يحمل عقدَه أصلاً: `contractStartDate` و`contractEndDate` و
/// `contractValue` و`durationDays`. و`AttentionEngine` ينبّه على انتهائه
/// من تلك الحقول منذ دورةٍ سابقة.
///
/// فلو نبّهت هذه المجموعةُ على عقدِ مشروعٍ لَظهر العقدُ الواحد **مرّتين**
/// في «ما يحتاج تدخّلاً» — والرقمُ الذي يُعدّ مرّتين لا يُصدَّق مرّة.
///
/// فـ[relatedProjectId] **للتصفّح لا للتنبيه**: من سجّل هنا عقدَ مشروعٍ
/// ليجده في مكانٍ واحد فله ذلك، ويتخطّاه المحرّكُ صراحةً. وعقودُ الدعم
/// والتراخيص والصيانة — وهي أكثرُ عقود التقنية — لا مشروعَ لها أصلاً،
/// وهي سببُ وجود هذه المجموعة.
library;

import 'safe_read.dart';

enum ContractKind {
  support('دعم فنّي'),
  licence('ترخيص'),
  maintenance('صيانة'),
  other('غير ذلك');

  final String label;
  const ContractKind(this.label);

  static ContractKind fromName(String name) => ContractKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => ContractKind.other,
      );
}

class Contract {
  final String id;
  final String title;
  final ContractKind kind;

  final String vendorId;
  final String vendorName;

  final DateTime? startDate;
  final DateTime? endDate;

  /// قيمةُ العقد بالدينار — و`null` تعني **غيرَ مسجّلة** لا صفراً.
  final double? value;

  /// كم يوماً قبل الانتهاء يجب أن يُبدأ التجديد.
  final int renewalNoticeDays;

  /// **للتصفّح لا للتنبيه** — راجع شرحَ الملفّ أعلاه.
  final String relatedProjectId;

  final String createdByUid;
  final DateTime createdAt;

  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  const Contract({
    required this.id,
    required this.title,
    required this.kind,
    this.vendorId = '',
    this.vendorName = '',
    this.startDate,
    this.endDate,
    this.value,
    this.renewalNoticeDays = 60,
    this.relatedProjectId = '',
    required this.createdByUid,
    required this.createdAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  Contract copyWith({
    String? title,
    ContractKind? kind,
    String? vendorId,
    String? vendorName,
    DateTime? startDate,
    DateTime? endDate,
    double? value,
    int? renewalNoticeDays,
    String? relatedProjectId,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      Contract(
        id: id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        vendorId: vendorId ?? this.vendorId,
        vendorName: vendorName ?? this.vendorName,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        value: value ?? this.value,
        renewalNoticeDays: renewalNoticeDays ?? this.renewalNoticeDays,
        relatedProjectId: relatedProjectId ?? this.relatedProjectId,
        createdByUid: createdByUid ?? this.createdByUid,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'kind': kind.name,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'startDate': startDate,
        'endDate': endDate,
        'value': value,
        'renewalNoticeDays': renewalNoticeDays,
        'relatedProjectId': relatedProjectId,
        'createdByUid': createdByUid,
        'createdAt': createdAt,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  factory Contract.fromMap(String id, Map<String, dynamic> j) => Contract(
        id: id,
        title: readText(j['title']),
        kind: ContractKind.fromName(readText(j['kind'])),
        vendorId: readText(j['vendorId']),
        vendorName: readText(j['vendorName']),
        startDate: readDate(j['startDate']),
        endDate: readDate(j['endDate']),
        value: readNum(j['value'])?.toDouble(),
        renewalNoticeDays: (readNum(j['renewalNoticeDays']) ?? 60).round(),
        relatedProjectId: readText(j['relatedProjectId']),
        createdByUid: readText(j['createdByUid']),
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
