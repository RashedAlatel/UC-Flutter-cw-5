import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// "عمل" تشغيلي مستقل لا يرتبط بمشروع.
///
/// هذه هي بنود العمل الإدارية والتشغيلية الدورية التي تنجزها الإدارة خارج
/// إطار المشاريع (معاملات، صيانة دورية، تقارير شهرية...). تُسنَد لموظف بعينه،
/// ويراها هو ومدير إدارته، وتظهر عند إنجازها في سجل الإنجازات وفي التقارير.
///
/// يُعاد استخدام [TaskStatus] و[PriorityLevel] القائمَين بدل تعدادات جديدة
/// حتى تبقى مفردات الحالة موحّدة عبر المنصة كلها.
class WorkItem {
  final String id;
  final String title;
  final String description;
  final String departmentId;

  /// معرّف حساب الموظف المسؤول — يُستخدم لتصفية "أعمالي" ولقواعد الأمان.
  final String assigneeUid;

  /// اسم الموظف المسؤول، منسوخ للعرض دون قراءة إضافية لمستند المستخدم.
  final String assigneeName;

  final TaskStatus status;
  final PriorityLevel priority;
  final double progressPercent; // 0-100
  final DateTime dueDate;

  /// تاريخ الإنجاز الفعلي — يُملأ تلقائياً عند تحويل الحالة إلى "منجزة"،
  /// وهو ما يُرتَّب به سجل الإنجازات.
  final DateTime? completedDate;

  /// عمل متكرر دورياً (شهري/أسبوعي) بخلاف العمل الذي يُنجز مرة واحدة.
  final bool isRecurring;

  final String createdByUid;
  final DateTime createdAt;

  const WorkItem({
    required this.id,
    required this.title,
    required this.description,
    required this.departmentId,
    required this.assigneeUid,
    required this.assigneeName,
    required this.status,
    required this.priority,
    required this.progressPercent,
    required this.dueDate,
    this.completedDate,
    this.isRecurring = false,
    required this.createdByUid,
    required this.createdAt,
  });

  bool get isDone => status == TaskStatus.done;

  /// أيام التأخير عن الموعد، محسوبة حيّة. صفر للعمل المنجَز أو الذي لم يحن موعده.
  int get delayDays {
    if (isDone) return 0;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : 0;
  }

  WorkItem copyWith({
    String? title,
    String? description,
    String? departmentId,
    String? assigneeUid,
    String? assigneeName,
    TaskStatus? status,
    PriorityLevel? priority,
    double? progressPercent,
    DateTime? dueDate,
    DateTime? completedDate,
    bool? isRecurring,
  }) {
    final nextStatus = status ?? this.status;
    return WorkItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      departmentId: departmentId ?? this.departmentId,
      assigneeUid: assigneeUid ?? this.assigneeUid,
      assigneeName: assigneeName ?? this.assigneeName,
      status: nextStatus,
      priority: priority ?? this.priority,
      progressPercent: progressPercent ?? this.progressPercent,
      dueDate: dueDate ?? this.dueDate,
      // تاريخ الإنجاز يُضبط تلقائياً مع تغيّر الحالة: يُملأ عند الإنجاز ويُمسح
      // إن أُعيد العمل إلى قيد التنفيذ، فلا يبقى تاريخ إنجاز لعمل غير منجَز.
      completedDate: completedDate ??
          (nextStatus == TaskStatus.done ? (this.completedDate ?? DateTime.now()) : null),
      isRecurring: isRecurring ?? this.isRecurring,
      createdByUid: createdByUid,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'departmentId': departmentId,
        'assigneeUid': assigneeUid,
        'assigneeName': assigneeName,
        'status': status.name,
        'priority': priority.name,
        'progressPercent': progressPercent,
        'dueDate': Timestamp.fromDate(dueDate),
        'completedDate': completedDate == null ? null : Timestamp.fromDate(completedDate!),
        'isRecurring': isRecurring,
        'createdByUid': createdByUid,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory WorkItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? {};
    return WorkItem(
      id: doc.id,
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      departmentId: j['departmentId'] as String? ?? '',
      assigneeUid: j['assigneeUid'] as String? ?? '',
      assigneeName: j['assigneeName'] as String? ?? '',
      status: TaskStatus.fromName(j['status'] as String? ?? TaskStatus.todo.name),
      priority: PriorityLevel.fromName(j['priority'] as String? ?? PriorityLevel.medium.name),
      progressPercent: (j['progressPercent'] as num?)?.toDouble() ?? 0,
      dueDate: (j['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedDate: (j['completedDate'] as Timestamp?)?.toDate(),
      isRecurring: j['isRecurring'] as bool? ?? false,
      createdByUid: j['createdByUid'] as String? ?? '',
      createdAt: (j['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
