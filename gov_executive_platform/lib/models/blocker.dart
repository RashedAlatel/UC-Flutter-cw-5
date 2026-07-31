import 'enums.dart';

class ProjectBlocker {
  final String id;
  final String projectId;
  final String description;
  final ItemStatus status;
  final DateTime dateRaised;

  const ProjectBlocker({
    required this.id,
    required this.projectId,
    required this.description,
    required this.status,
    required this.dateRaised,
  });

  ProjectBlocker copyWith({ItemStatus? status}) => ProjectBlocker(
        id: id,
        projectId: projectId,
        description: description,
        status: status ?? this.status,
        dateRaised: dateRaised,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'description': description,
        'status': status.name,
        'dateRaised': dateRaised.toIso8601String(),
      };

  factory ProjectBlocker.fromJson(Map<String, dynamic> json) => ProjectBlocker(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        description: json['description'] as String,
        status: ItemStatus.fromName(json['status'] as String),
        dateRaised: DateTime.parse(json['dateRaised'] as String),
      );
}
