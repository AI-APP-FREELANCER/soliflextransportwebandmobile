class VehicleModel {
  final String vehicleId;
  final String vehicleNumber;
  final String type;
  final int capacityKg;
  final String vehicleType;
  final String vendorVehicle;
  final bool isBusy;
  final double? utilizationPercentage;
  final bool? isOptimal;

  VehicleModel({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.type,
    required this.capacityKg,
    required this.vehicleType,
    required this.vendorVehicle,
    required this.isBusy,
    this.utilizationPercentage,
    this.isOptimal,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // Handle status field - 'Booked' means isBusy = true, 'Free' means isBusy = false
    bool isBusy = false;
    if (json['status'] != null) {
      final status = json['status'].toString().toLowerCase();
      isBusy = status == 'booked';
    } else if (json['is_busy'] != null) {
      isBusy = json['is_busy'].toString().toLowerCase() == 'true' || json['isBusy'] == true;
    } else if (json['isBusy'] != null) {
      isBusy = json['isBusy'] == true;
    }
    
    return VehicleModel(
      vehicleId: json['vehicleId']?.toString() ?? '',
      vehicleNumber: json['vehicle_number'] ?? json['vehicleNumber'] ?? '',
      type: json['type'] ?? '',
      capacityKg: int.tryParse(json['capacity_kg']?.toString() ?? '0') ?? 0,
      vehicleType: json['vehicle_type'] ?? json['vehicleType'] ?? '',
      vendorVehicle: json['vendor_vehicle'] ?? json['vendorVehicle'] ?? '',
      isBusy: isBusy,
      utilizationPercentage: json['utilizationPercentage'] != null 
          ? double.tryParse(json['utilizationPercentage'].toString()) 
          : null,
      isOptimal: json['isOptimal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'vehicle_number': vehicleNumber,
      'type': type,
      'capacity_kg': capacityKg,
      'vehicle_type': vehicleType,
      'vendor_vehicle': vendorVehicle,
      'is_busy': isBusy.toString(),
      'utilizationPercentage': utilizationPercentage,
      'isOptimal': isOptimal,
    };
  }
}

