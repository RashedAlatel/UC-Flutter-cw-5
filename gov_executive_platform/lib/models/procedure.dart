/// دليلُ الإجراءات: إجراءٌ، وخطواتُه، والنسخُ التي سبقته.
///
/// ــــ ما هو، وما ليس هو ــــ
///
/// **مرجعٌ يُقرأ ويُحدَّث**: كيف يسير عملٌ في الوزارة، خطوةً خطوة، لكلٍّ
/// صاحبُها وإدارتُها ومدّتُها. وليس خطّةَ مشروع: لا يُسنَد إلى أحد، ولا
/// يُتابَع إنجازُه، ولا يولّد مهامّ. من احتاج ذلك فله المشاريعُ والأعمال.
///
/// ــــ ولماذا تُحفظ النسخُ كاملةً ــــ
///
/// لأنّ سؤالَ من يقرأ الدليلَ بعد سنةٍ ليس «ما الذي تغيّر؟» بل **«كيف كان
/// الإجراءُ يومَ سار عليه فلان؟»**. وسجلُّ التدقيق يجيب الأوّل ولا يجيب
/// الثاني: هو فروقٌ لا صور. فلكل تعديلٍ صورةٌ كاملةٌ في `procedureVersions`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'attachment.dart';
import 'safe_read.dart';

/// خطوةٌ في إجراء — **مضمَّنةٌ في مستنده، وترتيبُها ترتيبُ القائمة**.
///
/// ولا حقلَ `order`: الترتيبُ في مصفوفةٍ واحدةٍ لا يحتاج رقماً يُصان،
/// وإعادةُ الترتيب في الشاشة إعادةُ ترتيبِ قائمة. وحقلٌ رقميٌّ منفصل يفتح
/// حالةَ رقمين متساويين — وهي حالةٌ لا معنى لها هنا.
class ProcedureStep {
  final String title;
  final String description;

  /// **مسمّىً وظيفيّ نصّاً** لا مستخدمٌ بعينه: «مدير إدارة العقود».
  ///
  /// والإجراءاتُ تعمر أطولَ من شاغليها. ولو رُبطت الخطوةُ بحسابٍ لَبطل
  /// الدليلُ كلَّما انتقل موظّفٌ أو ترك، ولَاحتاج تحديثاً لا يخصّ العملَ
  /// نفسَه في شيء.
  final String ownerTitle;

  /// وإدارةٌ تُختار من إدارات الوزارة — فتُعرف الجهةُ مع الصفة.
  final String? departmentId;

  /// مدّةُ الخطوة بالأيام — أو `null` إن لم تُسجَّل.
  ///
  /// ولا يُختلق صفر: «يوم صفر» دعوى بأنّ الخطوة تقع في حينها، وهي غير
  /// «لم تُحدَّد مدّتُها».
  final int? durationDays;

  final String notes;
  final List<Attachment> attachments;

  const ProcedureStep({
    required this.title,
    this.description = '',
    this.ownerTitle = '',
    this.departmentId,
    this.durationDays,
    this.notes = '',
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'ownerTitle': ownerTitle,
        'departmentId': departmentId,
        'durationDays': durationDays,
        'notes': notes,
        'attachments': [for (final a in attachments) a.toMap()],
      };

  /// يقرأ خطوةً — و**يردّ `null`** لما ليس خطوة.
  ///
  /// وهو نمطُ `StageStep.fromMap`: عنصرٌ فاسدٌ في المصفوفة يسقط وحدَه ولا
  /// يُسقط الإجراءَ كلَّه معه. وخطوةٌ بلا عنوان لا تُقرأ خطوة — لأنّ
  /// العنوانَ هو كلُّ ما يظهر في القائمة، فسطرٌ فارغٌ عطلٌ لا بيان.
  static ProcedureStep? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final title = readText(json['title']);
    if (title.isEmpty) return null;
    final days = readNum(json['durationDays']);
    return ProcedureStep(
      title: title,
      description: readText(json['description']),
      ownerTitle: readText(json['ownerTitle']),
      departmentId: () {
        final id = readText(json['departmentId']);
        return id.isEmpty ? null : id;
      }(),
      durationDays: days?.round(),
      notes: readText(json['notes']),
      attachments: Attachment.listFrom(json['attachments']),
    );
  }

  static List<ProcedureStep> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [for (final item in raw) ?ProcedureStep.fromMap(item)];
  }

  ProcedureStep copyWith({
    String? title,
    String? description,
    String? ownerTitle,
    String? departmentId,
    bool clearDepartment = false,
    int? durationDays,
    bool clearDuration = false,
    String? notes,
    List<Attachment>? attachments,
  }) =>
      ProcedureStep(
        title: title ?? this.title,
        description: description ?? this.description,
        ownerTitle: ownerTitle ?? this.ownerTitle,
        departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
        durationDays: clearDuration ? null : (durationDays ?? this.durationDays),
        notes: notes ?? this.notes,
        attachments: attachments ?? this.attachments,
      );
}

/// إجراءٌ في الدليل — النسخةُ السارية منه.
class Procedure {
  final String id;
  final String title;
  final String summary;

  /// الإدارةُ صاحبةُ الإجراء — أو `null` لإجراءٍ عامّ في الوزارة.
  ///
  /// **وهي وصفٌ لا نطاقُ قراءة**: من يقرأ الدليلَ يقرؤه كلَّه، والقراءةُ
  /// بابُها صلاحيةُ `vpc` وحدَها. ولو صارت نطاقاً لَاحتاج كلُّ إجراءٍ عامّ
  /// حيلةً تُخرجه من الحصر.
  final String? departmentId;

  /// إجراءٌ مؤرشف: لم يعد سارياً، **ويبقى مقروءاً**.
  ///
  /// ولا حذف: من وعد بحفظ النسخ لا يمحو أصلَها. وما سار عليه الناسُ سنةً
  /// يبقى مما يُرجع إليه.
  final bool isActive;

  /// رقمُ النسخة السارية — يبدأ من ١ ويزيد واحداً مع كل حفظ.
  final int version;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String updatedByUid;
  final String updatedByName;
  final List<ProcedureStep> steps;

  const Procedure({
    required this.id,
    required this.title,
    this.summary = '',
    this.departmentId,
    this.isActive = true,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.updatedByUid = '',
    this.updatedByName = '',
    this.steps = const [],
  });

  /// مجموعُ مُدد الخطوات — و`null` إن لم تُسجَّل مدّةٌ واحدة.
  ///
  /// وما لم يُسجَّل لا يُحسب صفراً: مجموعٌ مبنيٌّ على أصفارٍ مفترضة يُقرأ
  /// وعداً بمدّةٍ لم يقلها أحد.
  int? get totalDurationDays {
    final known = [for (final s in steps) if (s.durationDays != null) s.durationDays!];
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a + b);
  }

  /// هل سُجّلت مدّةُ كلِّ خطوة؟ — فيُقال للقارئ إن كان المجموع ناقصاً.
  bool get hasCompleteDurations =>
      steps.isNotEmpty && steps.every((s) => s.durationDays != null);

  Map<String, dynamic> toMap() => {
        'title': title,
        'summary': summary,
        'departmentId': departmentId,
        'isActive': isActive,
        'version': version,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
        'updatedByUid': updatedByUid,
        'updatedByName': updatedByName,
        'steps': [for (final s in steps) s.toMap()],
      };

  factory Procedure.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Procedure._fromMap(doc.id, doc.data() ?? const {});

  /// بناءٌ من خريطةٍ مباشرةً — للاختبارات وللصورة المحفوظة في النسخة.
  /// يستدعي **نفس** منطق القراءة لا نسخةً منه.
  @visibleForTesting
  static Procedure fromMapForTest(String id, Map<String, dynamic> json) =>
      Procedure._fromMap(id, json);

  factory Procedure._fromMap(String id, Map<String, dynamic> json) {
    final version = readNum(json['version']);
    return Procedure(
      id: id,
      title: readText(json['title']),
      summary: readText(json['summary']),
      departmentId: () {
        final dept = readText(json['departmentId']);
        return dept.isEmpty ? null : dept;
      }(),
      // وغيابُ العلم يُقرأ «سارٍ»: مستنداتٌ كُتبت قبل إضافة الحقل ليست
      // مؤرشفة، وقراءتُها كذلك تُخفي الدليلَ كلَّه بلا سبب.
      isActive: json['isActive'] != false,
      version: version == null ? 1 : version.round(),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      updatedByUid: readText(json['updatedByUid']),
      updatedByName: readText(json['updatedByName']),
      steps: ProcedureStep.listFrom(json['steps']),
    );
  }

  Procedure copyWith({
    String? title,
    String? summary,
    String? departmentId,
    bool clearDepartment = false,
    bool? isActive,
    int? version,
    DateTime? updatedAt,
    String? updatedByUid,
    String? updatedByName,
    List<ProcedureStep>? steps,
  }) =>
      Procedure(
        id: id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
        isActive: isActive ?? this.isActive,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedByUid: updatedByUid ?? this.updatedByUid,
        updatedByName: updatedByName ?? this.updatedByName,
        steps: steps ?? this.steps,
      );
}

/// صورةُ إجراءٍ كما كان **قبل** تعديلٍ بعينه.
///
/// وتُكتب على الخادم وحدَه، في المعاملة نفسِها التي تكتب النسخةَ الجديدة —
/// فلا يقع حفظٌ بلا صورة. راجع `saveProcedure` و`procedure_scope.ts`.
class ProcedureVersion {
  final String id;
  final String procedureId;

  /// رقمُ النسخة التي تحملها هذه الصورة — أي رقمُ الإجراء قبل التعديل.
  final int versionNumber;

  final DateTime? savedAt;
  final String savedByUid;
  final String savedByName;

  /// ما كتبه المحرّر عن سبب التعديل — يُقرأ في قائمة النسخ.
  final String note;

  /// الإجراءُ كما كان. ومعرّفُه معرّفُ الإجراء لا معرّفُ هذه الصورة.
  final Procedure snapshot;

  const ProcedureVersion({
    required this.id,
    required this.procedureId,
    required this.versionNumber,
    required this.snapshot,
    this.savedAt,
    this.savedByUid = '',
    this.savedByName = '',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'procedureId': procedureId,
        'versionNumber': versionNumber,
        'savedAt': savedAt == null ? null : Timestamp.fromDate(savedAt!),
        'savedByUid': savedByUid,
        'savedByName': savedByName,
        'note': note,
        'snapshot': snapshot.toMap(),
      };

  factory ProcedureVersion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ProcedureVersion._fromMap(doc.id, doc.data() ?? const {});

  @visibleForTesting
  static ProcedureVersion fromMapForTest(String id, Map<String, dynamic> json) =>
      ProcedureVersion._fromMap(id, json);

  factory ProcedureVersion._fromMap(String id, Map<String, dynamic> json) {
    final procedureId = readText(json['procedureId']);
    final number = readNum(json['versionNumber']);
    final raw = json['snapshot'];
    return ProcedureVersion(
      id: id,
      procedureId: procedureId,
      versionNumber: number == null ? 0 : number.round(),
      savedAt: readDate(json['savedAt']),
      savedByUid: readText(json['savedByUid']),
      savedByName: readText(json['savedByName']),
      note: readText(json['note']),
      // وصورةٌ غائبةٌ تُقرأ إجراءً فارغاً باسمه لا رمياً: نسخةٌ لا تُفتح
      // خيرٌ من دليلٍ لا يُفتح.
      snapshot: Procedure._fromMap(
        procedureId,
        raw is Map ? Map<String, dynamic>.from(raw) : const {},
      ),
    );
  }
}
