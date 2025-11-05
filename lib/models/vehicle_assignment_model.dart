class VehicleAssignment {
  final String vehicleId;
  final String vehicleNumber;
  final int capacityKg;
  final String vehicleType;
  // List of segment IDs this specific truck will transport
  final List<int> segmentIds;
  // The total weight this truck is carrying (for audit)
  final int assignedWeightKg;

  VehicleAssignment({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.capacityKg,
    required this.vehicleType,
    required this.segmentIds,
    required this.assignedWeightKg,
  });

  factory VehicleAssignment.fromJson(Map<String, dynamic> json) {
    return VehicleAssignment(
      vehicleId: json['vehicle_id']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      capacityKg: int.tryParse(json['capacity_kg']?.toString() ?? '0') ?? 0,
      vehicleType: json['vehicle_type']?.toString() ?? '',
      segmentIds: (json['segment_ids'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [],
      assignedWeightKg: int.tryParse(json['assigned_weight_kg']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'vehicle_number': vehicleNumber,
      'capacity_kg': capacityKg,
      'vehicle_type': vehicleType,
      'segment_ids': segmentIds,
      'assigned_weight_kg': assignedWeightKg,
    };
  }
}

