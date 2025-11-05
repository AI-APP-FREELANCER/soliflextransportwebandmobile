import 'dart:convert';

class WorkflowStep {
  final String stage; // SECURITY_ENTRY, STORES_VERIFICATION, SECURITY_EXIT
  final String status; // PENDING, APPROVED, REJECTED, CANCELED
  final String location; // Location where this step applies
  final String? approvedBy; // Name of user who approved/rejected
  final String? department; // Department of user who approved/rejected
  final int timestamp; // Milliseconds since epoch
  final String? comments; // Optional comments

  WorkflowStep({
    required this.stage,
    required this.status,
    required this.location,
    this.approvedBy,
    this.department,
    required this.timestamp,
    this.comments,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      stage: json['stage']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      location: json['location']?.toString() ?? '',
      approvedBy: json['approved_by']?.toString(),
      department: json['department']?.toString(),
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : int.tryParse(json['timestamp']?.toString() ?? '0') ?? 0,
      comments: json['comments']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'status': status,
      'location': location,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (department != null) 'department': department,
      'timestamp': timestamp,
      if (comments != null) 'comments': comments,
    };
  }

  WorkflowStep copyWith({
    String? stage,
    String? status,
    String? location,
    String? approvedBy,
    String? department,
    int? timestamp,
    String? comments,
  }) {
    return WorkflowStep(
      stage: stage ?? this.stage,
      status: status ?? this.status,
      location: location ?? this.location,
      approvedBy: approvedBy ?? this.approvedBy,
      department: department ?? this.department,
      timestamp: timestamp ?? this.timestamp,
      comments: comments ?? this.comments,
    );
  }

  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isPending => status == 'PENDING';
  bool get isCanceled => status == 'CANCELED';
}

