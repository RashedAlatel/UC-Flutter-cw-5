import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';
import 'project_edit.dart';

/// معاينة بريدٍ ينتظر الاعتماد — تُقرأ من حمولة الطلب لا من وصفه.
class NotifyPreview {
  final List<String> recipientUids;
  final NotifyChannel channel;
  final String sampleSubject;
  final String sampleBody;

  /// هل تختلف نصوص الرسائل بين المستلمين؟ (تنبيه المتأخرات يخصّص لكلٍّ مشاريعه.)
  final bool varied;

  const NotifyPreview({
    required this.recipientUids,
    required this.channel,
    required this.sampleSubject,
    required this.sampleBody,
    required this.varied,
  });
}

/// طلب موافقة موحّد يمر عبر مركز القرارات التنفيذية.
/// يغطي: تسجيل عضو جديد، إضافة مشروع، تعديل موعد نهائي، وقرارات تنفيذية عامة.
/// لا يُنفَّذ أي تغيير فعلي على البيانات إلا بعد اعتماد الطلب عبر دالة خلفية (Cloud Function).
class ApprovalRequest {
  final String id;
  final ApprovalType type;
  final DecisionStatus status;
  final String title;
  final String description;
  final PriorityLevel priority;
  final int delayImpactDays;
  final String? departmentId;
  final String? projectId;
  final String requestedByUid;
  final String requestedByName;
  final DateTime requestedDate;
  final String? resolutionNote;
  final DateTime? resolvedDate;

  /// ــــ المرحلةُ التي عليها الطلب الآن ــــ
  ///
  /// لا معنى لها إلا في المسارات متعدّدة المراحل ([ApprovalType.projectEdit]
  /// اليوم). وما سواها مرحلةٌ واحدة، فتُقرأ لها `systemAdmin` ولا تُستعمل.
  ///
  /// **وهي الحَكَم لا الدور**: مسؤولُ النظام لا يبتّ في مرحلة مدير الإدارة —
  /// ولو فعل لَاختصر مساراً طُلب أن يكون مرحلتين، وسقط رأيُ صاحب الإدارة.
  /// راجع `canActAtStage` في `functions/src/approval_stage.ts`.
  final EditStage stage;

  /// أثرُ المسار: من بتّ في كل مرحلة، ومتى، وبماذا.
  ///
  /// ويُكتب من **الخادم** لا من العميل: هو سجلُّ من وافق، ولا يجوز أن يكتبه
  /// من يستفيد منه. وهو ما طلبتَه في «سجل التعديلات»: من وافق من مدير
  /// الإدارة، وتاريخُ الموافقة، ومن اعتمد من مسؤولي النظام.
  final List<StageStep> stageTrail;

  /// بيانات إضافية خاصة بنوع الطلب (تُقرأ فقط من قبل الدالة الخلفية عند الاعتماد):
  /// registration: {name, email, phone, requestedRole, requestedDepartmentId}
  /// projectCreate: {name, description, departmentId, startDate, dueDate, priority}
  /// deadlineChange: {projectId, oldDueDate, newDueDate, reason}
  final Map<String, dynamic> payload;

  const ApprovalRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.priority,
    required this.delayImpactDays,
    this.departmentId,
    this.projectId,
    required this.requestedByUid,
    required this.requestedByName,
    required this.requestedDate,
    this.resolutionNote,
    this.resolvedDate,
    this.stage = EditStage.systemAdmin,
    this.stageTrail = const [],
    this.payload = const {},
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'status': status.name,
        'title': title,
        'description': description,
        'priority': priority.name,
        'delayImpactDays': delayImpactDays,
        'departmentId': departmentId,
        'projectId': projectId,
        'requestedByUid': requestedByUid,
        'requestedByName': requestedByName,
        'requestedDate': Timestamp.fromDate(requestedDate),
        'resolutionNote': resolutionNote,
        'resolvedDate': resolvedDate == null ? null : Timestamp.fromDate(resolvedDate!),
        'stage': stage.name,
        // ويُكتب فارغاً من العميل دائماً: الخادمُ وحده يُلحق به.
        'stageTrail': [for (final s in stageTrail) s.toMap()],
        'payload': payload,
      };

  factory ApprovalRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ApprovalRequest(
      id: doc.id,
      type: ApprovalType.fromName(json['type'] as String? ?? ApprovalType.decision.name),
      status: DecisionStatus.fromName(json['status'] as String? ?? DecisionStatus.pending.name),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priority: PriorityLevel.fromName(json['priority'] as String? ?? PriorityLevel.medium.name),
      delayImpactDays: (json['delayImpactDays'] as num?)?.toInt() ?? 0,
      departmentId: json['departmentId'] as String?,
      projectId: json['projectId'] as String?,
      requestedByUid: json['requestedByUid'] as String? ?? '',
      requestedByName: json['requestedByName'] as String? ?? '',
      requestedDate: (json['requestedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolutionNote: json['resolutionNote'] as String?,
      resolvedDate: (json['resolvedDate'] as Timestamp?)?.toDate(),
      // طلبٌ كُتب قبل المراحل يُقرأ `systemAdmin`: مرحلةٌ واحدةٌ كما كان.
      stage: EditStage.fromName(json['stage'] as String?),
      stageTrail: [
        for (final raw in (json['stageTrail'] as List? ?? const []))
          ?StageStep.fromMap(raw),
      ],
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  /// ما سيُرسل فعلاً عند اعتماد طلب [ApprovalType.notifySend]، من **الحمولة**.
  ///
  /// للسبب نفسه المشروح في [grantedRoleLabel]: العنوان والوصف نصّان يكتبهما
  /// الطالب، والحمولة هي ما تُنفّذه الدالة الخلفية. ولا يجوز أن يعتمد مسؤول
  /// النظام بريداً يخرج باسم الوزارة دون أن يقرأ نصّه هو لا وصفَه.
  ///
  /// يعيد null لغير هذا النوع أو لحمولة لا رسائل صالحة فيها — وحينها لا يُعرض
  /// شيء، ولا تُخترع معاينة من عدم.
  NotifyPreview? get notifyPreview {
    if (type != ApprovalType.notifySend) return null;
    final raw = payload['messages'];
    if (raw is! List || raw.isEmpty) return null;

    final uids = <String>[];
    final bodies = <String>{};
    final subjects = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final uid = (item['uid'] as String?)?.trim() ?? '';
      final body = (item['body'] as String?)?.trim() ?? '';
      if (uid.isEmpty || body.isEmpty) continue;
      uids.add(uid);
      bodies.add(body);
      subjects.add((item['subject'] as String?)?.trim() ?? '');
    }
    if (uids.isEmpty) return null;

    final channelName = payload['channel'] as String? ?? NotifyChannel.email.name;
    return NotifyPreview(
      recipientUids: uids,
      channel: NotifyChannel.values.firstWhere(
        (c) => c.name == channelName,
        orElse: () => NotifyChannel.email,
      ),
      sampleSubject: subjects.isEmpty ? '' : subjects.first,
      sampleBody: bodies.first,
      // تنبيه المشاريع المتأخرة يسرد لكل مسؤول مشاريعَه هو، فالنصوص تختلف.
      // وعرضُ نصٍّ واحد حينها يوهم أن الجميع يتلقّى ما يُعرض.
      varied: bodies.length > 1,
    );
  }

  /// الدور الذي سيُمنح فعلاً عند اعتماد طلب التسجيل، مقروءاً من **الحمولة**.
  ///
  /// `title` و`description` نصّان يكتبهما العميل، والحمولة هي ما تقرأه الدالة
  /// الخلفية وتكتبه في بطاقة الدخول. فلو تناقضا لَظهر لمسؤول النظام طلبٌ
  /// بريء الوصف يمنح دوراً آخر. لذلك يُعرض هذا السطر في بطاقة الطلب مأخوذاً
  /// من الحمولة لا من الوصف.
  ///
  /// واسمٌ غير معروف يُعاد **كما هو** لا مترجماً: `UserRole.fromName` ترجع
  /// `projectOfficer` لكل مجهول، فترجمته هنا تُخفي الشذوذ بدل أن تكشفه.
  String? get grantedRoleLabel {
    if (type != ApprovalType.registration) return null;
    final raw = payload['requestedRole'];
    if (raw is! String || raw.trim().isEmpty) return null;
    final name = raw.trim();
    final known = UserRole.values.where((r) => r.name == name);
    return known.isEmpty ? name : known.first.label;
  }
}

/// خطوةٌ في مسار الطلب — من بتّ، ومتى، وبماذا.
class StageStep {
  final EditStage stage;
  final String byUid;
  final String byName;
  final DateTime at;

  /// `approved` · `rejected` · `returned` — ما فُعل في هذه المرحلة.
  final String action;

  const StageStep({
    required this.stage,
    required this.byUid,
    required this.byName,
    required this.at,
    required this.action,
  });

  String get actionLabel => switch (action) {
        'approved' => 'وافق',
        'rejected' => 'رفض',
        'returned' => 'أعاد للتعديل',
        _ => action,
      };

  Map<String, dynamic> toMap() => {
        'stage': stage.name,
        'byUid': byUid,
        'byName': byName,
        'at': Timestamp.fromDate(at),
        'action': action,
      };

  /// خطوةٌ مشوّهة تُسقَط ولا تنهار: سجلُّ المسار يُعرض، ولا يجوز أن يُسقط
  /// سطرٌ فاسدٌ فيه بطاقةَ الطلب كلَّها.
  static StageStep? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final at = raw['at'];
    return StageStep(
      stage: EditStage.fromName(raw['stage'] as String?),
      byUid: raw['byUid'] as String? ?? '',
      byName: raw['byName'] as String? ?? '',
      at: at is Timestamp ? at.toDate() : DateTime.now(),
      action: raw['action'] as String? ?? '',
    );
  }
}

extension ProjectEditRequest on ApprovalRequest {
  /// التغييراتُ المطلوبة، مقروءةً من **الحمولة** لا من الوصف.
  ///
  /// للسبب نفسه المشروح في `grantedRoleLabel`: الوصفُ نصٌّ يكتبه الطالب،
  /// والحمولةُ هي ما يُنفَّذ. ولا يجوز أن يعتمد مسؤولُ النظام تغييراً يقرأ
  /// وصفَه لا حقيقتَه.
  List<FieldChange> get editChanges {
    if (type != ApprovalType.projectEdit) return const [];
    final raw = payload['changes'];
    if (raw is! Map) return const [];
    final out = <FieldChange>[];
    for (final entry in raw.entries) {
      final change = FieldChange.fromMap(entry.key.toString(), entry.value);
      if (change != null) out.add(change);
    }
    // الجوهريُّ أوّلاً: هو ما يجب أن تقع عليه العينُ قبل أن تتعب.
    out.sort((a, b) {
      if (a.isSensitive != b.isSensitive) return a.isSensitive ? -1 : 1;
      return a.label.compareTo(b.label);
    });
    return out;
  }

  bool get hasSensitiveEdit => hasSensitiveChange(editChanges);
}
