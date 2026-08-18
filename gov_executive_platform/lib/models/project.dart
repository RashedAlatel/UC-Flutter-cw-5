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
  final int delayDays; // أيام التأخير عن الخطة (0 = لا يوجد تأخير)
  final String executorName; // الشخص المنفذ/المسؤول عن المشروع
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
    required this.delayDays,
    this.executorName = '',
    this.createdByUid = '',
    this.managerUid,
  });

  Project copyWith({
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    ProjectStatus? status,
    PriorityLevel? priority,
    double? progressPercent,
    int? delayDays,
    String? executorName,
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
      delayDays: delayDays ?? this.delayDays,
      executorName: executorName ?? this.executorName,
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
        'delayDays': delayDays,
        'executorName': executorName,
        'createdByUid': createdByUid,
        'managerUid': managerUid,
      };

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
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
      delayDays: (json['delayDays'] as num?)?.toInt() ?? 0,
      executorName: json['executorName'] as String? ?? '',
      createdByUid: json['createdByUid'] as String? ?? '',
      managerUid: json['managerUid'] as String?,
    );
  }
}
