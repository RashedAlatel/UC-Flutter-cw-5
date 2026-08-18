import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class Project {
  final String id;
  final String departmentId;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime dueDate;
  final ProjectStatus status;
  final PriorityLevel priority;
  final double progressPercent; // 0-100
  final List<String> executorNames; // الأشخاص المنفذون/المسؤولون عن المشروع (يمكن أن يكون أكثر من شخص)
  final String createdByUid;
  final String? managerUid; // حساب "مدير المشروع" المُسنَد إليه (يرى هذا المشروع فقط)

  const Project({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.dueDate,
    required this.status,
    required this.priority,
    required this.progressPercent,
    this.executorNames = const [],
    this.createdByUid = '',
    this.managerUid,
  });

  /// نص واحد يجمع كل أسماء المنفذين مفصولة بفاصلة، للاستخدام في الأماكن
  /// التي تعرض نصاً واحداً بدل قائمة (جداول، تصدير التقارير...).
  String get executorLabel => executorNames.join('، ');

  /// أيام التأخير عن الخطة، محسوبة ديناميكياً في كل مرة (الفرق بين اليوم
  /// الحالي وتاريخ الاستحقاق) بدل قيمة ثابتة تُخزَّن وتتجمّد عند الإدخال —
  /// 0 لأي مشروع مكتمل أو لم يتجاوز موعده النهائي بعد.
  int get delayDays {
    if (status == ProjectStatus.completed) return 0;
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    return now.isAfter(due) ? now.difference(due).inDays : 0;
  }

  Project copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    ProjectStatus? status,
    PriorityLevel? priority,
    double? progressPercent,
    List<String>? executorNames,
    String? managerUid,
  }) {
    return Project(
      id: id,
      departmentId: departmentId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      progressPercent: progressPercent ?? this.progressPercent,
      executorNames: executorNames ?? this.executorNames,
      createdByUid: createdByUid,
      managerUid: managerUid ?? this.managerUid,
    );
  }

  Map<String, dynamic> toMap() => {
        'departmentId': departmentId,
        'name': name,
        'description': description,
        'startDate': Timestamp.fromDate(startDate),
        'dueDate': Timestamp.fromDate(dueDate),
        'status': status.name,
        'priority': priority.name,
        'progressPercent': progressPercent,
        'executorNames': executorNames,
        'createdByUid': createdByUid,
        'managerUid': managerUid,
      };

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    // توافق مع مستندات قديمة كانت تخزّن "executorName" كنص واحد فقط.
    final namesList = json['executorNames'] as List?;
    final legacyName = json['executorName'] as String?;
    return Project(
      id: doc.id,
      departmentId: json['departmentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startDate: (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ProjectStatus.fromName(json['status'] as String? ?? ProjectStatus.onTrack.name),
      priority: PriorityLevel.fromName(json['priority'] as String? ?? PriorityLevel.medium.name),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      executorNames: namesList != null
          ? namesList.map((e) => e.toString()).toList()
          : (legacyName != null && legacyName.isNotEmpty ? [legacyName] : const []),
      createdByUid: json['createdByUid'] as String? ?? '',
      managerUid: json['managerUid'] as String?,
    );
  }
}
