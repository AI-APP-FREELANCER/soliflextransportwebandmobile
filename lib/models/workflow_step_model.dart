import 'dart:convert';

class WorkflowStep {
  final String stage; // SECURITY_ENTRY, STORES_VERIFICATION, SECURITY_EXIT
  final String status; // PENDING, APPROVED, REJECTED, CANCELED
  final String location; // Location where this step applies
  final String? approvedBy; // Name of user who approved/rejected
  final String? department; // Department of user who approved/rejected
  final int timestamp; // Milliseconds since epoch
  final String? comments; // Optional comments
  final int? stageIndex; // Position in workflow sequence (0-5 for 6 stages)

  WorkflowStep({
    required this.stage,
    required this.status,
    required this.location,
    this.approvedBy,
    this.department,
    required this.timestamp,
    this.comments,
    this.stageIndex,
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
      stageIndex: json['stage_index'] != null
          ? (json['stage_index'] is int
              ? json['stage_index']
              : int.tryParse(json['stage_index'].toString()) ?? null)
          : null,
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
      if (stageIndex != null) 'stage_index': stageIndex,
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
    int? stageIndex,
  }) {
    return WorkflowStep(
      stage: stage ?? this.stage,
      status: status ?? this.status,
      location: location ?? this.location,
      approvedBy: approvedBy ?? this.approvedBy,
      department: department ?? this.department,
      timestamp: timestamp ?? this.timestamp,
      comments: comments ?? this.comments,
      stageIndex: stageIndex ?? this.stageIndex,
    );
  }

  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isPending => status == 'PENDING';
  bool get isCanceled => status == 'CANCELED';
}

