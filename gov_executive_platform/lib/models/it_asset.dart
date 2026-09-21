/// أصلٌ تقنيّ — **سجلٌّ واحدٌ لنظامٍ وخادمٍ وترخيص**.
///
/// ــــ ولماذا مجموعةٌ واحدة ــــ
///
/// «سجلُّ الأنظمة» و«البنية التحتية» في المواصفة بابان، وهما في الحقيقة
/// شيءٌ واحدٌ بشكلين: بندٌ له مالكٌ وحَرِجيّةٌ وحالةٌ ودورةُ حياة. ونظامُ
/// الدوام وخادمُه وترخيصُه تُسأل عنها الأسئلةُ نفسُها: من يملكها؟ وماذا
/// يقع إن تعطّلت؟ ومتى ينتهي عقدُها؟
///
/// فمجموعتان تعنيان قاعدتين ومستمعَين وشاشتين تنحرف إحداها عن أختها في
/// أوّل تعديل — وحقلُ [kind] يفرّق بينهما حيث يجب أن يفترقا.
library;

import 'safe_read.dart';

enum AssetKind {
  system('نظام أو تطبيق'),
  server('خادم'),
  network('جهاز شبكة'),
  database('قاعدة بيانات'),
  licence('ترخيص');

  final String label;
  const AssetKind(this.label);

  static AssetKind fromName(String name) => AssetKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => AssetKind.system,
      );
}

/// حالةُ الأصل.
///
/// و«متعثّر» ليست «متقاعد»: الأوّلُ يعمل بعُرجٍ ويحتاج تدخّلاً، والثاني
/// خرج من الخدمة وانتهى أمرُه. وجمعُهما يُخفي ما يحتاج عملاً.
enum AssetStatus {
  live('في الخدمة'),
  pilot('تجريبيّ'),
  degraded('متعثّر'),
  retired('خارج الخدمة');

  final String label;
  const AssetStatus(this.label);

  static AssetStatus fromName(String name) => AssetStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AssetStatus.live,
      );

  /// هل هو في الخدمة فيُحاسَب على سعته؟ — والمتقاعدُ لا يُنبَّه عليه.
  bool get isInService => this == live || this == degraded;
}

class ITAsset {
  final String id;
  final AssetKind kind;
  final String name;
  final String description;

  /// ما بُني به — «Oracle 19c» أو «Windows Server 2022».
  final String technology;

  /// أين يقع — «غرفة الخوادم، الدور الأول» أو «سحابة المورّد».
  final String location;

  final AssetStatus status;

  /// ــ الحَرِجيّة ــ
  ///
  /// **بمفردات `Project.criticality` نفسِها** (`tier1`/`tier2`/`tier3`):
  /// مفرداتان لمعنىً واحدٍ في منصّةٍ واحدة أوّلُ ما يُوقع في الخطأ. وفارغٌ
  /// يعني غيرَ مصنَّف.
  final String criticality;

  /// **مالكُ العمل لا الفنّيّ**: من يقرّر مصيرَ النظام — هل يُجدَّد عقدُه،
  /// وهل يُستبدل. والفنّيُّ يشغّله ولا يقرّر فيه.
  final String ownerUid;
  final String ownerName;

  /// الإدارةُ المستفيدة — وقد تكون غيرَ إدارة التقنية.
  final String departmentServed;

  final String vendorId;
  final String vendorName;
  final String contractId;

  /// ــ السعةُ المستهلَكة بالمئة — و`null` تعني **غيرَ مقيسة** ــ
  ///
  /// ولا تُقرأ صفراً: صفرٌ يُقرأ «فارغٌ تماماً» وهو ادّعاءُ رقمٍ لا نقصُ
  /// بيان — وهي القاعدةُ نفسُها التي حكمت `contractValue` في `project.dart`.
  /// والأصلُ غيرُ المقيس **لا يُنبَّه عليه**: لا يُقال «تجاوز» عمّا لم يُقَس.
  final num? capacityUsedPercent;

  /// الحدُّ الذي يُنبَّه عند تجاوزه.
  final int capacityThreshold;

  final String createdByUid;
  final DateTime createdAt;

  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  /// هل تجاوز سعتَه؟ — **وغيرُ المقيس ليس متجاوزاً**.
  bool get isOverCapacity {
    final used = capacityUsedPercent;
    if (used == null || !status.isInService) return false;
    return used > capacityThreshold;
  }

  const ITAsset({
    required this.id,
    required this.kind,
    required this.name,
    this.description = '',
    this.technology = '',
    this.location = '',
    required this.status,
    this.criticality = '',
    this.ownerUid = '',
    this.ownerName = '',
    this.departmentServed = '',
    this.vendorId = '',
    this.vendorName = '',
    this.contractId = '',
    this.capacityUsedPercent,
    this.capacityThreshold = 85,
    required this.createdByUid,
    required this.createdAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  /// كلُّ حقلٍ هنا له نظيرُه في [toMap] — راجع تحذيرَ `project.dart`.
  ITAsset copyWith({
    AssetKind? kind,
    String? name,
    String? description,
    String? technology,
    String? location,
    AssetStatus? status,
    String? criticality,
    String? ownerUid,
    String? ownerName,
    String? departmentServed,
    String? vendorId,
    String? vendorName,
    String? contractId,
    num? capacityUsedPercent,
    int? capacityThreshold,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      ITAsset(
        id: id,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        description: description ?? this.description,
        technology: technology ?? this.technology,
        location: location ?? this.location,
        status: status ?? this.status,
        criticality: criticality ?? this.criticality,
        ownerUid: ownerUid ?? this.ownerUid,
        ownerName: ownerName ?? this.ownerName,
        departmentServed: departmentServed ?? this.departmentServed,
        vendorId: vendorId ?? this.vendorId,
        vendorName: vendorName ?? this.vendorName,
        contractId: contractId ?? this.contractId,
        capacityUsedPercent: capacityUsedPercent ?? this.capacityUsedPercent,
        capacityThreshold: capacityThreshold ?? this.capacityThreshold,
        createdByUid: createdByUid ?? this.createdByUid,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'name': name,
        'description': description,
        'technology': technology,
        'location': location,
        'status': status.name,
        'criticality': criticality,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'departmentServed': departmentServed,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'contractId': contractId,
        'capacityUsedPercent': capacityUsedPercent,
        'capacityThreshold': capacityThreshold,
        'createdByUid': createdByUid,
        'createdAt': createdAt,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  factory ITAsset.fromMap(String id, Map<String, dynamic> j) => ITAsset(
        id: id,
        kind: AssetKind.fromName(readText(j['kind'])),
        name: readText(j['name']),
        description: readText(j['description']),
        technology: readText(j['technology']),
        location: readText(j['location']),
        status: AssetStatus.fromName(readText(j['status'])),
        criticality: readText(j['criticality']),
        ownerUid: readText(j['ownerUid']),
        ownerName: readText(j['ownerName']),
        departmentServed: readText(j['departmentServed']),
        vendorId: readText(j['vendorId']),
        vendorName: readText(j['vendorName']),
        contractId: readText(j['contractId']),
        // و`readNum` تُعيد `null` لما لا يُقرأ — وهو المقصود هنا بالضبط.
        capacityUsedPercent: readNum(j['capacityUsedPercent']),
        capacityThreshold: (readNum(j['capacityThreshold']) ?? 85).round(),
        createdByUid: readText(j['createdByUid']),
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
