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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'departmentId': departmentId,
        'name': name,
        'description': description,
        'startDate': startDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'priority': priority.name,
        'progressPercent': progressPercent,
        'delayDays': delayDays,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        departmentId: json['departmentId'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: ProjectStatus.fromName(json['status'] as String),
        priority: PriorityLevel.fromName(json['priority'] as String),
        progressPercent: (json['progressPercent'] as num).toDouble(),
        delayDays: json['delayDays'] as int,
      );
}
