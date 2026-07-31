import 'enums.dart';

class ProjectTask {
  final String id;
  final String projectId;
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
      title: title ?? this.title,
      assigneeName: assigneeName ?? this.assigneeName,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'title': title,
        'assigneeName': assigneeName,
        'status': status.name,
        'progressPercent': progressPercent,
        'lastUpdated': lastUpdated.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'priority': priority.name,
      };

  factory ProjectTask.fromJson(Map<String, dynamic> json) => ProjectTask(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        title: json['title'] as String,
        assigneeName: json['assigneeName'] as String,
        status: TaskStatus.fromName(json['status'] as String),
        progressPercent: (json['progressPercent'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        dueDate: DateTime.parse(json['dueDate'] as String),
        priority: PriorityLevel.fromName(json['priority'] as String),
      );
}
