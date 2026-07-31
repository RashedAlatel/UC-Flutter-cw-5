import 'enums.dart';

class ProjectRisk {
  final String id;
  final String projectId;
  final String description;
  final RiskLevel level;
  final ItemStatus status;
  final DateTime dateRaised;

  const ProjectRisk({
    required this.id,
    required this.projectId,
    required this.description,
    required this.level,
    required this.status,
    required this.dateRaised,
  });

  ProjectRisk copyWith({ItemStatus? status}) => ProjectRisk(
        id: id,
        projectId: projectId,
        description: description,
        level: level,
        status: status ?? this.status,
        dateRaised: dateRaised,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'description': description,
        'level': level.name,
        'status': status.name,
        'dateRaised': dateRaised.toIso8601String(),
      };

  factory ProjectRisk.fromJson(Map<String, dynamic> json) => ProjectRisk(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        description: json['description'] as String,
        level: RiskLevel.fromName(json['level'] as String),
        status: ItemStatus.fromName(json['status'] as String),
        dateRaised: DateTime.parse(json['dateRaised'] as String),
      );
}
