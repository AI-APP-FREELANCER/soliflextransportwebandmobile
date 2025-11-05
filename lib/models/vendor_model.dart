class VendorModel {
  final String vendorId;
  final String name;
  final String? vendorName; // For admin API responses
  final String? kl;
  final String? pickUpBySolBelow3000Kgs;
  final String? droppedByVendorBelow3000Kgs;
  final String? pickUpBySolBetween3000To5999Kgs;
  final String? droppedByVendorBelow5999Kgs;
  final String? pickUpBySolAbove6000Kgs;
  final String? droppedByVendorAbove6000Kgs;
  final String? tollCharges;

  VendorModel({
    required this.vendorId,
    required this.name,
    this.vendorName,
    this.kl,
    this.pickUpBySolBelow3000Kgs,
    this.droppedByVendorBelow3000Kgs,
    this.pickUpBySolBetween3000To5999Kgs,
    this.droppedByVendorBelow5999Kgs,
    this.pickUpBySolAbove6000Kgs,
    this.droppedByVendorAbove6000Kgs,
    this.tollCharges,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    // Generate vendorId if not present (for admin API responses)
    final vendorId = json['vendorId']?.toString() ?? 
                     json['S/L']?.toString() ?? 
                     json['s/l']?.toString() ?? 
                     '';
    final vendorName = json['vendor_name'] ?? json['name'] ?? '';
    
    return VendorModel(
      vendorId: vendorId,
      name: vendorName,
      vendorName: json['vendor_name'],
      kl: json['kl']?.toString(),
      pickUpBySolBelow3000Kgs: json['pick_up_by_sol_below_3000_kgs']?.toString(),
      droppedByVendorBelow3000Kgs: json['dropped_by_vendor_below_3000_kgs']?.toString(),
      pickUpBySolBetween3000To5999Kgs: json['pick_up_by_sol_between_3000_to_5999_kgs']?.toString(),
      droppedByVendorBelow5999Kgs: json['dropped_by_vendor_below_5999_kgs']?.toString(),
      pickUpBySolAbove6000Kgs: json['pick_up_by_sol_above_6000_kgs']?.toString(),
      droppedByVendorAbove6000Kgs: json['dropped_by_vendor_above_6000_kgs']?.toString(),
      tollCharges: json['toll_charges']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'name': name,
      if (vendorName != null) 'vendor_name': vendorName,
      if (kl != null) 'kl': kl,
      if (pickUpBySolBelow3000Kgs != null) 'pick_up_by_sol_below_3000_kgs': pickUpBySolBelow3000Kgs,
      if (droppedByVendorBelow3000Kgs != null) 'dropped_by_vendor_below_3000_kgs': droppedByVendorBelow3000Kgs,
      if (pickUpBySolBetween3000To5999Kgs != null) 'pick_up_by_sol_between_3000_to_5999_kgs': pickUpBySolBetween3000To5999Kgs,
      if (droppedByVendorBelow5999Kgs != null) 'dropped_by_vendor_below_5999_kgs': droppedByVendorBelow5999Kgs,
      if (pickUpBySolAbove6000Kgs != null) 'pick_up_by_sol_above_6000_kgs': pickUpBySolAbove6000Kgs,
      if (droppedByVendorAbove6000Kgs != null) 'dropped_by_vendor_above_6000_kgs': droppedByVendorAbove6000Kgs,
      if (tollCharges != null) 'toll_charges': tollCharges,
    };
  }
}

