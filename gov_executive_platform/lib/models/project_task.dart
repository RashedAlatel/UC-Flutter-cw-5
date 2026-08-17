import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class ProjectTask {
  final String id;
  final String projectId;
  final String departmentId;
  final String title;
  final String assigneeName;
  final TaskStatus status;
  final double progressPercent; // 0-100
  final DateTime lastUpdated;
  final DateTime dueDate;
  final PriorityLevel priority;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.title,
    required this.assigneeName,
    required this.status,
    required this.progressPercent,
    required this.lastUpdated,
    required this.dueDate,
    required this.priority,
  });

  ProjectTask copyWith({
    String? title,
    String? assigneeName,
    TaskStatus? status,
    double? progressPercent,
    DateTime? lastUpdated,
    DateTime? dueDate,
    PriorityLevel? priority,
  }) {
    return ProjectTask(
      id: id,
      projectId: projectId,
      departmentId: departmentId,
      title: title ?? this.title,
      assigneeName: assigneeName ?? this.assigneeName,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'departmentId': departmentId,
        'title': title,
        'assigneeName': assigneeName,
        'status': status.name,
        'progressPercent': progressPercent,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
        'dueDate': Timestamp.fromDate(dueDate),
        'priority': priority.name,
      };

  factory ProjectTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return ProjectTask(
      id: doc.id,
      projectId: json['projectId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assigneeName: json['assigneeName'] as String? ?? '',
      status: TaskStatus.fromName(json['status'] as String? ?? TaskStatus.todo.name),
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priority: PriorityLevel.fromName(json['priority'] as String? ?? PriorityLevel.medium.name),
    );
  }
}
