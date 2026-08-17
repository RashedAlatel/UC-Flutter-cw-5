import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap() => {
        'userName': userName,
        'action': action,
        'details': details,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  factory AuditLogEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      userName: json['userName'] as String? ?? '',
      action: json['action'] as String? ?? '',
      details: json['details'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
