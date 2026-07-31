class AuditLogEntry {
  final String id;
  final String userName;
  final String action;
  final String details;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.id,
    required this.userName,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userName': userName,
        'action': action,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        userName: json['userName'] as String,
        action: json['action'] as String,
        details: json['details'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
