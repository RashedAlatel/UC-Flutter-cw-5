import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شكوى أو اقتراح يرفعه موظف إلى مسؤول النظام.
enum FeedbackKind {
  complaint,
  suggestion;

  String get label => this == FeedbackKind.complaint ? 'شكوى' : 'اقتراح';

  IconData get icon =>
      this == FeedbackKind.complaint ? Icons.report_problem_outlined : Icons.lightbulb_outline_rounded;

  static FeedbackKind fromName(String name) =>
      FeedbackKind.values.firstWhere((e) => e.name == name, orElse: () => FeedbackKind.suggestion);
}

/// حالة البتّ في الشكوى أو الاقتراح.
enum FeedbackStatus {
  submitted,
  inReview,
  resolved,
  dismissed;

  String get label {
    switch (this) {
      case FeedbackStatus.submitted:
        return 'مُستلمة';
      case FeedbackStatus.inReview:
        return 'قيد الدراسة';
      case FeedbackStatus.resolved:
        return 'تمّت معالجتها';
      case FeedbackStatus.dismissed:
        return 'حُفظت بلا إجراء';
    }
  }

  Color get color {
    switch (this) {
      case FeedbackStatus.submitted:
        return AppColors.info;
      case FeedbackStatus.inReview:
        return AppColors.warning;
      case FeedbackStatus.resolved:
        return AppColors.success;
      case FeedbackStatus.dismissed:
        return AppColors.textSecondary;
    }
  }

  static FeedbackStatus fromName(String name) =>
      FeedbackStatus.values.firstWhere((e) => e.name == name, orElse: () => FeedbackStatus.submitted);
}

class FeedbackItem {
  final String id;
  final FeedbackKind kind;
  final String title;
  final String body;

  /// صاحب الشكوى — يُكتب من معرّف المتصل نفسه، والقاعدة تشترط تطابقهما فلا
  /// يُنسب أحدٌ شكوى إلى غيره.
  final String submittedByUid;
  final String submittedByName;
  final String? departmentId;

  final FeedbackStatus status;

  /// ردّ مسؤول النظام أو من يتابع الشكاوى. يراه صاحب الشكوى.
  final String? responseNote;
  final String? handledByName;
  final DateTime? handledAt;

  final DateTime createdAt;

  const FeedbackItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.submittedByUid,
    required this.submittedByName,
    this.departmentId,
    this.status = FeedbackStatus.submitted,
    this.responseNote,
    this.handledByName,
    this.handledAt,
    required this.createdAt,
  });

  bool get isOpen => status == FeedbackStatus.submitted || status == FeedbackStatus.inReview;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'title': title,
        'body': body,
        'submittedByUid': submittedByUid,
        'submittedByName': submittedByName,
        'departmentId': departmentId,
        'status': status.name,
        'responseNote': responseNote,
        'handledByName': handledByName,
        'handledAt': handledAt == null ? null : Timestamp.fromDate(handledAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory FeedbackItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = doc.data() ?? {};
    return FeedbackItem(
      id: doc.id,
      kind: FeedbackKind.fromName(json['kind'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      submittedByUid: json['submittedByUid'] as String? ?? '',
      submittedByName: json['submittedByName'] as String? ?? '',
      departmentId: json['departmentId'] as String?,
      status: FeedbackStatus.fromName(json['status'] as String? ?? ''),
      responseNote: json['responseNote'] as String?,
      handledByName: json['handledByName'] as String?,
      handledAt: (json['handledAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
