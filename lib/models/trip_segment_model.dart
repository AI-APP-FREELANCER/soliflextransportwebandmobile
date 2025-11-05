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
  final bool? isManualInvoice; // Flag to indicate if invoice/toll was manually overridden
  final List<WorkflowStep> workflow; // Workflow steps for this segment

  TripSegment({
    required this.segmentId,
    required this.source,
    required this.destination,
    required this.materialWeight,
    required this.materialType,
    required this.segmentStatus,
    this.invoiceAmount,
    this.tollCharges,
    this.isManualInvoice,
    List<WorkflowStep>? workflow,
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
      isManualInvoice: json['is_manual_invoice'] != null
          ? (json['is_manual_invoice'] is bool
              ? json['is_manual_invoice']
              : json['is_manual_invoice'].toString().toLowerCase() == 'yes')
          : false,
      workflow: workflowSteps,
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
      'is_manual_invoice': (isManualInvoice ?? false) ? 'Yes' : 'No',
      'workflow': workflow.map((w) => w.toJson()).toList(),
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

