import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

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
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
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
