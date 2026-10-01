/// مورّدٌ — السجلُّ الذي كان `Project.vendorName` ينتظره.
///
/// وتعليقُ ذلك الحقل يقول حرفيّاً: «المورّدُ المنفّذ — ويُربط لاحقاً بسجلّ
/// المورّدين». فهذا هو. **والحقلُ النصّيُّ يبقى** اسماً منسوخاً للعرض:
/// مشاريعُ الوزارة المستوردة تحمل الاسمَ نصّاً بلا معرّفٍ يقابله، ومحوُه
/// يُفقد ما كُتب.
library;

import 'safe_read.dart';

class Vendor {
  final String id;
  final String name;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final String notes;

  /// **ولا يُحذف المورّدُ المنتهي تعاملُه، بل يُوقَف**: عقودٌ قديمةٌ تحمل
  /// اسمَه، وسجلٌّ محذوفٌ يجعلها تشير إلى فراغ.
  final bool isActive;

  final String createdByUid;
  final DateTime createdAt;

  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedReason;

  bool get isDeleted => deletedAt != null;

  const Vendor({
    required this.id,
    required this.name,
    this.contactName = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.notes = '',
    this.isActive = true,
    required this.createdByUid,
    required this.createdAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedReason,
  });

  Vendor copyWith({
    String? name,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    bool? isActive,
    String? createdByUid,
    DateTime? createdAt,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletedReason,
  }) =>
      Vendor(
        id: id,
        name: name ?? this.name,
        contactName: contactName ?? this.contactName,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        notes: notes ?? this.notes,
        isActive: isActive ?? this.isActive,
        createdByUid: createdByUid ?? this.createdByUid,
        createdAt: createdAt ?? this.createdAt,
        deletedAt: deletedAt ?? this.deletedAt,
        deletedBy: deletedBy ?? this.deletedBy,
        deletedReason: deletedReason ?? this.deletedReason,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'contactName': contactName,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'notes': notes,
        'isActive': isActive,
        'createdByUid': createdByUid,
        'createdAt': createdAt,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'deletedReason': deletedReason,
      };

  factory Vendor.fromMap(String id, Map<String, dynamic> j) => Vendor(
        id: id,
        name: readText(j['name']),
        contactName: readText(j['contactName']),
        contactEmail: readText(j['contactEmail']),
        contactPhone: readText(j['contactPhone']),
        notes: readText(j['notes']),
        // وغيابُ العلَم يُقرأ «نشط»: سجلٌّ كُتب قبل هذا الحقل ليس موقوفاً.
        isActive: j['isActive'] != false,
        createdByUid: readText(j['createdByUid']),
        createdAt: readDate(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        deletedAt: readDate(j['deletedAt']),
        deletedBy: j['deletedBy'] as String?,
        deletedReason: j['deletedReason'] as String?,
      );
}
