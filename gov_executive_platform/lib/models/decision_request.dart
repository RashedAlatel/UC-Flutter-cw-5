import 'enums.dart';

class DecisionRequest {
  final String id;
  final String projectId;
  final String departmentId;
  final String title;
  final String description;
  final PriorityLevel priority;
  final int delayImpactDays; // أثر التأخير بالأيام إذا لم يُتخذ القرار
  final DecisionStatus status;
  final String requestedBy;
  final DateTime requestedDate;
  final String? resolutionNote;

  const DecisionRequest({
    required this.id,
    required this.projectId,
    required this.departmentId,
    required this.title,
    required this.description,
    required this.priority,
    required this.delayImpactDays,
    required this.status,
    required this.requestedBy,
    required this.requestedDate,
    this.resolutionNote,
  });

  DecisionRequest copyWith({DecisionStatus? status, String? resolutionNote}) => DecisionRequest(
        id: id,
        projectId: projectId,
        departmentId: departmentId,
        title: title,
        description: description,
        priority: priority,
        delayImpactDays: delayImpactDays,
        status: status ?? this.status,
        requestedBy: requestedBy,
        requestedDate: requestedDate,
        resolutionNote: resolutionNote ?? this.resolutionNote,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'departmentId': departmentId,
        'title': title,
        'description': description,
        'priority': priority.name,
        'delayImpactDays': delayImpactDays,
        'status': status.name,
        'requestedBy': requestedBy,
        'requestedDate': requestedDate.toIso8601String(),
        'resolutionNote': resolutionNote,
      };

  factory DecisionRequest.fromJson(Map<String, dynamic> json) => DecisionRequest(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        departmentId: json['departmentId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        priority: PriorityLevel.fromName(json['priority'] as String),
        delayImpactDays: json['delayImpactDays'] as int,
        status: DecisionStatus.fromName(json['status'] as String),
        requestedBy: json['requestedBy'] as String,
        requestedDate: DateTime.parse(json['requestedDate'] as String),
        resolutionNote: json['resolutionNote'] as String?,
      );
}
