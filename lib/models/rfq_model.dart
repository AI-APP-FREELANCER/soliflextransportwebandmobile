class RFQModel {
  final String rfqId;
  final String userId;
  final String source;
  final String destination;
  final int materialWeight;
  final String materialType;
  final String? vehicleId;
  final String? vehicleNumber;
  final String status;
  final double totalCost;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  RFQModel({
    required this.rfqId,
    required this.userId,
    required this.source,
    required this.destination,
    required this.materialWeight,
    required this.materialType,
    this.vehicleId,
    this.vehicleNumber,
    required this.status,
    required this.totalCost,
    this.rejectionReason,
    this.approvedBy,
    this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.startedAt,
    this.completedAt,
  });

  factory RFQModel.fromJson(Map<String, dynamic> json) {
    return RFQModel(
      rfqId: json['rfqId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      source: json['source'] ?? '',
      destination: json['destination'] ?? '',
      materialWeight: int.tryParse(json['materialWeight']?.toString() ?? '0') ?? 0,
      materialType: json['materialType'] ?? '',
      vehicleId: json['vehicleId']?.toString(),
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'],
      status: json['status'] ?? 'PENDING_APPROVAL',
      totalCost: double.tryParse(json['totalCost']?.toString() ?? '0') ?? 0.0,
      rejectionReason: json['rejectionReason'],
      approvedBy: json['approvedBy'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      approvedAt: json['approvedAt'] != null ? DateTime.tryParse(json['approvedAt']) : null,
      rejectedAt: json['rejectedAt'] != null ? DateTime.tryParse(json['rejectedAt']) : null,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rfqId': rfqId,
      'userId': userId,
      'source': source,
      'destination': destination,
      'materialWeight': materialWeight,
      'materialType': materialType,
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'status': status,
      'totalCost': totalCost,
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'createdAt': createdAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'PENDING_APPROVAL':
        return 'Pending Approval';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'MODIFICATION_PENDING':
        return 'Modification Pending';
      default:
        return status;
    }
  }
}

