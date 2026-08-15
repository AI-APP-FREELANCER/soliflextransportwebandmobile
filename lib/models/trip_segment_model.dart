import 'dart:convert';
import 'workflow_step_model.dart';

class TripSegment {
  final int segmentId;
  final String source;
  final String destination;
  final int materialWeight;
  final String materialType; // Stored as JSON array string or plain string
  final String segmentStatus; // Pending, In-Progress, Completed
  final int? invoiceAmount;
  final int? tollCharges;
  final int? otherCharges;
  final String? otherChargesDescription;
  final bool? isManualInvoice; // Flag to indicate if invoice/toll was manually overridden
  final List<WorkflowStep> workflow; // Workflow steps for this segment
  final int? originalMaterialWeight; // Weight as first placed, only set once this segment has been weight-amended
  final bool weightAmended; // True once this segment's weight has been corrected via amendment

  TripSegment({
    required this.segmentId,
    required this.source,
    required this.destination,
    required this.materialWeight,
    required this.materialType,
    required this.segmentStatus,
    this.invoiceAmount,
    this.tollCharges,
    this.otherCharges,
    this.otherChargesDescription,
    this.isManualInvoice,
    List<WorkflowStep>? workflow,
    this.originalMaterialWeight,
    this.weightAmended = false,
  }) : workflow = workflow ?? [];

  factory TripSegment.fromJson(Map<String, dynamic> json) {
    // Parse material_type - could be JSON array string or plain string
    String materialType = '';
    if (json['material_type'] != null) {
      final materialTypeValue = json['material_type'].toString();
      if (materialTypeValue.startsWith('[') && materialTypeValue.endsWith(']')) {
        // It's a JSON array string
        try {
          final parsed = jsonDecode(materialTypeValue);
          if (parsed is List) {
            materialType = materialTypeValue; // Keep as JSON string for storage
          } else {
            materialType = materialTypeValue; // Fallback to original
          }
        } catch (e) {
          materialType = materialTypeValue; // If parsing fails, use original
        }
      } else {
        materialType = materialTypeValue; // Plain string
      }
    }

    // Parse workflow steps
    List<WorkflowStep> workflowSteps = [];
    if (json['workflow'] != null) {
      if (json['workflow'] is List) {
        workflowSteps = (json['workflow'] as List)
            .map((w) => WorkflowStep.fromJson(w as Map<String, dynamic>))
            .toList();
      } else if (json['workflow'] is String) {
        try {
          final parsed = jsonDecode(json['workflow']);
          if (parsed is List) {
            workflowSteps = parsed
                .map((w) => WorkflowStep.fromJson(w as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          // If parsing fails, workflowSteps remains empty
        }
      }
    }

    return TripSegment(
      segmentId: json['segment_id'] is int ? json['segment_id'] : int.tryParse(json['segment_id'].toString()) ?? 0,
      source: json['source'] ?? '',
      destination: json['destination'] ?? '',
      materialWeight: json['material_weight'] is int 
          ? json['material_weight'] 
          : int.tryParse(json['material_weight'].toString()) ?? 0,
      materialType: materialType,
      segmentStatus: json['segment_status'] ?? 'Pending',
      invoiceAmount: json['invoice_amount'] != null 
          ? (json['invoice_amount'] is int 
              ? json['invoice_amount'] 
              : int.tryParse(json['invoice_amount'].toString()))
          : null,
      tollCharges: json['toll_charges'] != null
          ? (json['toll_charges'] is int
              ? json['toll_charges']
              : int.tryParse(json['toll_charges'].toString()))
          : null,
      otherCharges: json['other_charges'] != null
          ? (json['other_charges'] is int
              ? json['other_charges']
              : int.tryParse(json['other_charges'].toString()))
          : null,
      otherChargesDescription: json['other_charges_description']?.toString(),
      isManualInvoice: json['is_manual_invoice'] != null
          ? (json['is_manual_invoice'] is bool
              ? json['is_manual_invoice']
              : json['is_manual_invoice'].toString().toLowerCase() == 'yes')
          : false,
      workflow: workflowSteps,
      // Absent on segments that have never been weight-amended -- both
      // parse to their defaults (null / false) rather than failing.
      originalMaterialWeight: json['original_material_weight'] != null
          ? (json['original_material_weight'] is int
              ? json['original_material_weight']
              : int.tryParse(json['original_material_weight'].toString()))
          : null,
      weightAmended: json['weight_amended'] == true || json['weight_amended']?.toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segment_id': segmentId,
      'source': source,
      'destination': destination,
      'material_weight': materialWeight,
      'material_type': materialType,
      'segment_status': segmentStatus,
      if (invoiceAmount != null) 'invoice_amount': invoiceAmount,
      if (tollCharges != null) 'toll_charges': tollCharges,
      if (otherCharges != null) 'other_charges': otherCharges,
      if (otherChargesDescription != null) 'other_charges_description': otherChargesDescription,
      'is_manual_invoice': (isManualInvoice ?? false) ? 'Yes' : 'No',
      'workflow': workflow.map((w) => w.toJson()).toList(),
      if (originalMaterialWeight != null) 'original_material_weight': originalMaterialWeight,
      if (weightAmended) 'weight_amended': weightAmended,
    };
  }

  // Helper to get material type as list for display
  List<String> get materialTypeList {
    if (materialType.isEmpty) return [];
    if (materialType.startsWith('[') && materialType.endsWith(']')) {
      try {
        final parsed = jsonDecode(materialType);
        if (parsed is List) {
          return parsed.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // If parsing fails, return as single item list
        return [materialType];
      }
    }
    // Plain string - return as single item list
    return [materialType];
  }

  String get statusDisplay {
    switch (segmentStatus) {
      case 'Pending':
        return 'Pending';
      case 'In-Progress':
        return 'In Progress';
      case 'Completed':
        return 'Completed';
      default:
        return segmentStatus;
    }
  }
}

