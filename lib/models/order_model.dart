import 'dart:convert';
import 'package:flutter/material.dart';
import 'trip_segment_model.dart';

/// Represents a single entry in the amendment history
class AmendmentHistoryEntry {
  final String version; // e.g., "V1", "V2"
  final DateTime timestamp;
  final String amendedBy;
  final String amendedByDepartment;
  final String amendedByUserId;
  final List<String> changeLog;
  final int segmentsBefore;
  final int segmentsAfter;
  final int totalWeightBefore;
  final int totalWeightAfter;
  final int totalInvoiceBefore;
  final int totalInvoiceAfter;

  AmendmentHistoryEntry({
    required this.version,
    required this.timestamp,
    required this.amendedBy,
    required this.amendedByDepartment,
    required this.amendedByUserId,
    required this.changeLog,
    required this.segmentsBefore,
    required this.segmentsAfter,
    required this.totalWeightBefore,
    required this.totalWeightAfter,
    required this.totalInvoiceBefore,
    required this.totalInvoiceAfter,
  });

  factory AmendmentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AmendmentHistoryEntry(
      version: json['version']?.toString() ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      amendedBy: json['amendedBy']?.toString() ?? 'Unknown',
      amendedByDepartment: json['amendedByDepartment']?.toString() ?? 'Unknown',
      amendedByUserId: json['amendedByUserId']?.toString() ?? '',
      changeLog: json['changeLog'] != null && json['changeLog'] is List
          ? (json['changeLog'] as List).map((e) => e.toString()).toList()
          : [],
      segmentsBefore: json['segmentsBefore'] != null 
          ? (json['segmentsBefore'] is int ? json['segmentsBefore'] : int.tryParse(json['segmentsBefore'].toString()) ?? 0)
          : 0,
      segmentsAfter: json['segmentsAfter'] != null 
          ? (json['segmentsAfter'] is int ? json['segmentsAfter'] : int.tryParse(json['segmentsAfter'].toString()) ?? 0)
          : 0,
      totalWeightBefore: json['totalWeightBefore'] != null 
          ? (json['totalWeightBefore'] is int ? json['totalWeightBefore'] : int.tryParse(json['totalWeightBefore'].toString()) ?? 0)
          : 0,
      totalWeightAfter: json['totalWeightAfter'] != null 
          ? (json['totalWeightAfter'] is int ? json['totalWeightAfter'] : int.tryParse(json['totalWeightAfter'].toString()) ?? 0)
          : 0,
      totalInvoiceBefore: json['totalInvoiceBefore'] != null 
          ? (json['totalInvoiceBefore'] is int ? json['totalInvoiceBefore'] : int.tryParse(json['totalInvoiceBefore'].toString()) ?? 0)
          : 0,
      totalInvoiceAfter: json['totalInvoiceAfter'] != null 
          ? (json['totalInvoiceAfter'] is int ? json['totalInvoiceAfter'] : int.tryParse(json['totalInvoiceAfter'].toString()) ?? 0)
          : 0,
    );
  }
}

class OrderModel {
  final String orderId;
  final String userId;
  final String source;
  final String destination;
  final int materialWeight;
  final String materialType;
  final String tripType;
  final String? vehicleId;
  final String? vehicleNumber;
  final String orderStatus;
  final DateTime? createdAt;
  final List<TripSegment> tripSegments;
  final bool isAmended;
  final String originalTripType;
  final String orderCategory;
  final int? totalWeight; // Cumulative sum of all segment weights
  final int? totalInvoiceAmount; // Cumulative sum of all segment invoice amounts
  final int? totalTollCharges; // Cumulative sum of all segment toll charges
  final String? creatorDepartment; // Department of the user who created the order
  final String? creatorUserId; // ID of the user who created the order
  final String? creatorName; // Full name of the user who created the order
  // Amendment audit trail fields
  final String? amendmentRequestedBy; // Name of user who requested amendment
  final String? amendmentRequestedDepartment; // Department of user who requested amendment
  final DateTime? amendmentRequestedAt; // Timestamp of amendment request
  final String? lastAmendedByUserId; // ID of the last user who amended the order
  final DateTime? lastAmendedTimestamp; // Timestamp of last amendment
  final List<AmendmentHistoryEntry>? amendmentHistory; // Complete amendment history
  // Original totals before amendment (for approval summary comparison)
  final int? originalTotalWeight; // Total weight before amendment
  final int? originalTotalInvoiceAmount; // Total invoice before amendment
  final int? originalTotalTollCharges; // Total toll before amendment
  final int? originalSegmentCount; // Number of segments before amendment
  // Order lifecycle auditing fields
  final DateTime? approvedTimestamp; // When order was approved
  final String? approvedByMember; // Member who approved the order
  final String? approvedByDepartment; // Department of approver
  final DateTime? vehicleStartedAtTimestamp; // When vehicle/process execution began
  final String? vehicleStartedFromLocation; // Location where movement began
  final DateTime? securityEntryTimestamp; // When security entry was recorded
  final String? securityEntryMemberName; // Security guard who recorded entry
  final String? securityEntryCheckpointLocation; // Checkpoint location
  final DateTime? storesValidationTimestamp; // When stores validation was completed
  final DateTime? vehicleExitedTimestamp; // When vehicle exited
  final DateTime? exitApprovedByTimestamp; // When exit was approved
  final String? exitApprovedByMemberName; // Security member who approved exit

  OrderModel({
    required this.orderId,
    required this.userId,
    required this.source,
    required this.destination,
    required this.materialWeight,
    required this.materialType,
    this.tripType = 'Single-Trip-Vendor',
    this.vehicleId,
    this.vehicleNumber,
    required this.orderStatus,
    this.createdAt,
    required this.tripSegments,
    this.isAmended = false,
    this.originalTripType = 'Single-Trip-Vendor',
    this.orderCategory = 'Client/Vendor Order',
    this.totalWeight,
    this.totalInvoiceAmount,
    this.totalTollCharges,
    this.creatorDepartment,
    this.creatorUserId,
    this.creatorName,
    this.amendmentRequestedBy,
    this.amendmentRequestedDepartment,
    this.amendmentRequestedAt,
    this.lastAmendedByUserId,
    this.lastAmendedTimestamp,
    this.amendmentHistory,
    this.originalTotalWeight,
    this.originalTotalInvoiceAmount,
    this.originalTotalTollCharges,
    this.originalSegmentCount,
    this.approvedTimestamp,
    this.approvedByMember,
    this.approvedByDepartment,
    this.vehicleStartedAtTimestamp,
    this.vehicleStartedFromLocation,
    this.securityEntryTimestamp,
    this.securityEntryMemberName,
    this.securityEntryCheckpointLocation,
    this.storesValidationTimestamp,
    this.vehicleExitedTimestamp,
    this.exitApprovedByTimestamp,
    this.exitApprovedByMemberName,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parse trip_segments - can be array or JSON string
    List<TripSegment> segments = [];
    if (json['trip_segments'] != null) {
      if (json['trip_segments'] is List) {
        segments = (json['trip_segments'] as List)
            .map((s) => TripSegment.fromJson(s))
            .toList();
      } else if (json['trip_segments'] is String) {
        try {
          final parsed = jsonDecode(json['trip_segments']);
          if (parsed is List) {
            segments = parsed.map((s) => TripSegment.fromJson(s)).toList();
          }
        } catch (e) {
          // If parsing fails, create segment from source/destination for backward compatibility
          segments = [
            TripSegment(
              segmentId: 1,
              source: json['source'] ?? '',
              destination: json['destination'] ?? '',
              materialWeight: int.tryParse(json['material_weight']?.toString() ?? '0') ?? 0,
              materialType: json['material_type'] ?? '',
              segmentStatus: json['order_status'] ?? 'Open',
            )
          ];
        }
      }
    }
    
    // If no segments found, create from source/destination for backward compatibility
    if (segments.isEmpty && json['source'] != null && json['destination'] != null) {
      segments = [
        TripSegment(
          segmentId: 1,
          source: json['source'] ?? '',
          destination: json['destination'] ?? '',
          materialWeight: int.tryParse(json['material_weight']?.toString() ?? '0') ?? 0,
          materialType: json['material_type'] ?? '',
          segmentStatus: json['order_status'] ?? 'Open',
        )
      ];
    }
    
    return OrderModel(
      orderId: json['order_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      source: json['source'] ?? '',
      destination: json['destination'] ?? '',
      materialWeight: int.tryParse(json['material_weight']?.toString() ?? '0') ?? 0,
      materialType: json['material_type'] ?? '',
      tripType: json['trip_type'] ?? 'Single-Trip-Vendor',
      vehicleId: json['vehicle_id']?.toString(),
      vehicleNumber: json['vehicle_number']?.toString(),
      orderStatus: json['order_status'] ?? 'Open',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      tripSegments: segments,
      isAmended: json['is_amended']?.toString().toLowerCase() == 'yes' || json['is_amended'] == true,
      originalTripType: json['original_trip_type'] ?? json['trip_type'] ?? 'Single-Trip-Vendor',
      orderCategory: json['order_category'] ?? 'Client/Vendor Order',
      totalWeight: json['total_weight'] != null 
          ? (json['total_weight'] is int 
              ? json['total_weight'] 
              : int.tryParse(json['total_weight'].toString()))
          : null,
      totalInvoiceAmount: json['total_invoice_amount'] != null
          ? (json['total_invoice_amount'] is int
              ? json['total_invoice_amount']
              : int.tryParse(json['total_invoice_amount'].toString()))
          : null,
      totalTollCharges: json['total_toll_charges'] != null
          ? (json['total_toll_charges'] is int
              ? json['total_toll_charges']
              : int.tryParse(json['total_toll_charges'].toString()))
          : null,
      creatorDepartment: json['creator_department']?.toString(),
      creatorUserId: json['creator_user_id']?.toString(),
      creatorName: json['creator_name']?.toString(),
      // Amendment audit trail fields
      amendmentRequestedBy: json['amendment_requested_by']?.toString(),
      amendmentRequestedDepartment: json['amendment_requested_department']?.toString(),
      amendmentRequestedAt: json['amendment_requested_at'] != null 
          ? DateTime.tryParse(json['amendment_requested_at'].toString()) 
          : null,
      lastAmendedByUserId: json['last_amended_by_user_id']?.toString(),
      lastAmendedTimestamp: json['last_amended_timestamp'] != null 
          ? DateTime.tryParse(json['last_amended_timestamp'].toString()) 
          : null,
      amendmentHistory: _parseAmendmentHistory(json['amendment_history']),
      // Original totals before amendment
      originalTotalWeight: json['original_total_weight'] != null
          ? (json['original_total_weight'] is int
              ? json['original_total_weight']
              : int.tryParse(json['original_total_weight'].toString()))
          : null,
      originalTotalInvoiceAmount: json['original_total_invoice_amount'] != null
          ? (json['original_total_invoice_amount'] is int
              ? json['original_total_invoice_amount']
              : int.tryParse(json['original_total_invoice_amount'].toString()))
          : null,
      originalTotalTollCharges: json['original_total_toll_charges'] != null
          ? (json['original_total_toll_charges'] is int
              ? json['original_total_toll_charges']
              : int.tryParse(json['original_total_toll_charges'].toString()))
          : null,
      originalSegmentCount: json['original_segment_count'] != null
          ? (json['original_segment_count'] is int
              ? json['original_segment_count']
              : int.tryParse(json['original_segment_count'].toString()))
          : null,
      // Order lifecycle auditing fields
      approvedTimestamp: json['approved_timestamp'] != null 
          ? DateTime.tryParse(json['approved_timestamp'].toString())
          : null,
      approvedByMember: json['approved_by_member']?.toString(),
      approvedByDepartment: json['approved_by_department']?.toString(),
      vehicleStartedAtTimestamp: json['vehicle_started_at_timestamp'] != null
          ? DateTime.tryParse(json['vehicle_started_at_timestamp'].toString())
          : null,
      vehicleStartedFromLocation: json['vehicle_started_from_location']?.toString(),
      securityEntryTimestamp: json['security_entry_timestamp'] != null
          ? DateTime.tryParse(json['security_entry_timestamp'].toString())
          : null,
      securityEntryMemberName: json['security_entry_member_name']?.toString(),
      securityEntryCheckpointLocation: json['security_entry_checkpoint_location']?.toString(),
      storesValidationTimestamp: json['stores_validation_timestamp'] != null
          ? DateTime.tryParse(json['stores_validation_timestamp'].toString())
          : null,
      vehicleExitedTimestamp: json['vehicle_exited_timestamp'] != null
          ? DateTime.tryParse(json['vehicle_exited_timestamp'].toString())
          : null,
      exitApprovedByTimestamp: json['exit_approved_by_timestamp'] != null
          ? DateTime.tryParse(json['exit_approved_by_timestamp'].toString())
          : null,
      exitApprovedByMemberName: json['exit_approved_by_member_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'user_id': userId,
      'source': source,
      'destination': destination,
      'material_weight': materialWeight,
      'material_type': materialType,
      'trip_type': tripType,
      'vehicle_id': vehicleId,
      'vehicle_number': vehicleNumber,
      'order_status': orderStatus,
      'created_at': createdAt?.toIso8601String(),
      'trip_segments': tripSegments.map((s) => s.toJson()).toList(),
      'is_amended': isAmended ? 'Yes' : 'No',
      'original_trip_type': originalTripType,
      'order_category': orderCategory,
      if (totalWeight != null) 'total_weight': totalWeight,
      if (totalInvoiceAmount != null) 'total_invoice_amount': totalInvoiceAmount,
      if (totalTollCharges != null) 'total_toll_charges': totalTollCharges,
      if (creatorDepartment != null) 'creator_department': creatorDepartment,
      if (creatorUserId != null) 'creator_user_id': creatorUserId,
      if (creatorName != null) 'creator_name': creatorName,
      if (amendmentRequestedBy != null) 'amendment_requested_by': amendmentRequestedBy,
      if (amendmentRequestedDepartment != null) 'amendment_requested_department': amendmentRequestedDepartment,
      if (amendmentRequestedAt != null) 'amendment_requested_at': amendmentRequestedAt?.toIso8601String(),
      if (lastAmendedByUserId != null) 'last_amended_by_user_id': lastAmendedByUserId,
      if (lastAmendedTimestamp != null) 'last_amended_timestamp': lastAmendedTimestamp?.toIso8601String(),
      if (originalTotalWeight != null) 'original_total_weight': originalTotalWeight,
      if (originalTotalInvoiceAmount != null) 'original_total_invoice_amount': originalTotalInvoiceAmount,
      if (originalTotalTollCharges != null) 'original_total_toll_charges': originalTotalTollCharges,
      if (originalSegmentCount != null) 'original_segment_count': originalSegmentCount,
      // Order lifecycle auditing fields
      if (approvedTimestamp != null) 'approved_timestamp': approvedTimestamp?.toIso8601String(),
      if (approvedByMember != null) 'approved_by_member': approvedByMember,
      if (approvedByDepartment != null) 'approved_by_department': approvedByDepartment,
      if (vehicleStartedAtTimestamp != null) 'vehicle_started_at_timestamp': vehicleStartedAtTimestamp?.toIso8601String(),
      if (vehicleStartedFromLocation != null) 'vehicle_started_from_location': vehicleStartedFromLocation,
      if (securityEntryTimestamp != null) 'security_entry_timestamp': securityEntryTimestamp?.toIso8601String(),
      if (securityEntryMemberName != null) 'security_entry_member_name': securityEntryMemberName,
      if (securityEntryCheckpointLocation != null) 'security_entry_checkpoint_location': securityEntryCheckpointLocation,
      if (storesValidationTimestamp != null) 'stores_validation_timestamp': storesValidationTimestamp?.toIso8601String(),
      if (vehicleExitedTimestamp != null) 'vehicle_exited_timestamp': vehicleExitedTimestamp?.toIso8601String(),
      if (exitApprovedByTimestamp != null) 'exit_approved_by_timestamp': exitApprovedByTimestamp?.toIso8601String(),
      if (exitApprovedByMemberName != null) 'exit_approved_by_member_name': exitApprovedByMemberName,
    };
  }

  // Getter methods to calculate totals from segments if not stored
  int getTotalWeight() {
    if (totalWeight != null) return totalWeight!;
    return tripSegments.fold(0, (sum, segment) => sum + segment.materialWeight);
  }

  int getTotalInvoiceAmount() {
    if (totalInvoiceAmount != null) return totalInvoiceAmount!;
    return tripSegments.fold(0, (sum, segment) => sum + (segment.invoiceAmount ?? 0));
  }

  int getTotalTollCharges() {
    if (totalTollCharges != null) return totalTollCharges!;
    return tripSegments.fold(0, (sum, segment) => sum + (segment.tollCharges ?? 0));
  }

  /// Parse amendment history from JSON string or array
  static List<AmendmentHistoryEntry>? _parseAmendmentHistory(dynamic jsonValue) {
    if (jsonValue == null) return null;
    
    try {
      List<dynamic> historyList;
      if (jsonValue is String) {
        // Parse JSON string
        if (jsonValue.trim().isEmpty) return null;
        final decoded = jsonDecode(jsonValue);
        historyList = decoded is List ? decoded : [];
      } else if (jsonValue is List) {
        historyList = jsonValue;
      } else {
        return null;
      }
      
      if (historyList.isEmpty) return null;
      
      return historyList.map((entry) {
        if (entry is Map<String, dynamic>) {
          return AmendmentHistoryEntry.fromJson(entry);
        }
        return null;
      }).whereType<AmendmentHistoryEntry>().toList();
    } catch (e) {
      // Silently return null on parse error - amendment history is optional
      return null;
    }
  }

  List<String> getAllMaterialTypes() {
    Set<String> allMaterials = {};
    for (var segment in tripSegments) {
      for (var materialType in segment.materialTypeList) {
        if (materialType.isNotEmpty) {
          allMaterials.add(materialType);
        }
      }
    }
    return allMaterials.toList();
  }

  String get statusDisplay {
    switch (orderStatus) {
      case 'Open':
        return 'Open';
      case 'In-Progress':
        return 'In Progress';
      case 'En-Route':
        return 'En Route';
      case 'Completed':
        return 'Completed';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }

  Color get statusColor {
    switch (orderStatus) {
      case 'Open':
        return Colors.green;
      case 'In-Progress':
        return Colors.blue;
      case 'En-Route':
        return Colors.orange;
      case 'Completed':
        return Colors.grey;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}


