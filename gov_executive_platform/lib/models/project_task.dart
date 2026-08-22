import 'package:cloud_firestore/cloud_firestore.dart';

import 'closure_trail.dart';
import 'enums.dart';

class ProjectTask {
  final String id;
  final String projectId;
  final String departmentId;
  final String title;

  /// حساب المُسنَد إليه — **فارغ في كل مهمة كُتبت قبل هذه الدورة**.
  ///
  /// ــــ لماذا لم يكن موجوداً، ولماذا لزم الآن؟ ــــ
  ///
  /// كانت المهمة تحمل اسماً نصياً وحده. وذلك يكفي للعرض ولا يكفي للحوكمة:
  /// دورةُ إغلاقٍ من مرحلتين تحتاج أن تعرف **من** أعلن الإتمام و**من** اعتمد
  /// بهويةٍ لا بحروفٍ مكتوبة يمكن أن تتشابه أو تُكتب خطأً.
  ///
  /// والمهام القديمة تبقى تعمل كما هي: بلا حساب ⇒ بلا اعتماد ⇒ إغلاق مباشر.
  final String assigneeUid;
  final String assigneeName;
  final TaskStatus status;
  final double progressPercent; // 0-100
  final DateTime lastUpdated;
  final DateTime dueDate;
  final PriorityLevel priority;

  /// من أنشأ المهمة — طرفُ الطلب في دورة الإغلاق.
  final String createdByUid;

  /// سجلّ الإغلاق نفسه الذي على العمل — راجع [ClosureTrail].
  final ClosureTrail closure;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.title,
    this.assigneeUid = '',
    required this.assigneeName,
    required this.status,
    required this.progressPercent,
    required this.lastUpdated,
    required this.dueDate,
    required this.priority,
    this.createdByUid = '',
    this.closure = ClosureTrail.none,
  });

  bool get isDone => status == TaskStatus.done;
  bool get isAwaitingApproval => status == TaskStatus.awaitingApproval;

  ProjectTask copyWith({
    String? title,
    String? assigneeUid,
    String? assigneeName,
    TaskStatus? status,
    double? progressPercent,
    DateTime? lastUpdated,
    DateTime? dueDate,
    PriorityLevel? priority,
    ClosureTrail? closure,
  }) {
    return ProjectTask(
      id: id,
      projectId: projectId,
      departmentId: departmentId,
      title: title ?? this.title,
      assigneeUid: assigneeUid ?? this.assigneeUid,
      assigneeName: assigneeName ?? this.assigneeName,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      createdByUid: createdByUid,
      closure: closure ?? this.closure,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'title': title,
        'assigneeUid': assigneeUid,
        'assigneeName': assigneeName,
        'status': status.name,
        'progressPercent': progressPercent,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
        'dueDate': Timestamp.fromDate(dueDate),
        'priority': priority.name,
        'createdByUid': createdByUid,
        'closure': closure.toMap(),
      };

  factory ProjectTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ProjectTask(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assigneeUid: json['assigneeUid'] as String? ?? '',
      assigneeName: json['assigneeName'] as String? ?? '',
      status: TaskStatus.fromName(json['status'] as String? ?? TaskStatus.todo.name),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priority: PriorityLevel.fromName(json['priority'] as String? ?? PriorityLevel.medium.name),
      createdByUid: json['createdByUid'] as String? ?? '',
      closure: ClosureTrail.fromMap(json['closure']),
    );
  }
}
