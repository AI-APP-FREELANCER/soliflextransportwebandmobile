import '../models/order_model.dart';
import '../models/vehicle_model.dart';
import '../services/order_workflow_service.dart';

/// The per-order information shown on an Orders Dashboard card, derived with
/// the same rules the card uses, so other views (the Home dashboard's All
/// Orders table and its CSV export) can show exactly what the card shows.
///
/// Mirrors the helpers in `_OrdersDashboardScreenState` / `_buildOrderCard`
/// (orders_dashboard_screen.dart). If the card's rules change, change them
/// here too.
class OrderCardInfo {
  OrderCardInfo._();

  /// Status as the card's status chip shows it (workflow-aware).
  static String statusDisplay(OrderModel order, OrderWorkflowService workflow) {
    final status = workflow.getEffectiveOrderStatus(order);
    final normalized = status.trim().toUpperCase();
    if (normalized == 'COMPLETED') return 'Completed';
    if (normalized == 'REJECTED') return 'Rejected';
    if (normalized == 'CANCELLED' || normalized == 'CANCELED') return 'Cancelled';
    switch (status) {
      case 'Open':
        return 'Open';
      case 'In-Progress':
        return 'In Progress';
      case 'En-Route':
        return 'En Route';
      default:
        return status;
    }
  }

  /// "A → B", "A → B → A", "A → ... → C" -- the card's route line.
  static String routeSummary(OrderModel order) {
    final segments = order.tripSegments;
    if (segments.length == 1) {
      return '${segments[0].source} → ${segments[0].destination}';
    } else if (segments.length > 1) {
      final isRoundTrip = order.tripType == 'Round-Trip-Vendor' ||
          order.originalTripType == 'Round-Trip-Vendor';
      if (isRoundTrip) {
        final first = segments.first;
        final last = segments.last;
        if (first.source == last.destination) {
          return '${first.source} → ${first.destination} → ${last.destination}';
        }
        return '${first.source} → ${first.destination} → ... → ${last.destination}';
      }
      return '${segments.first.source} → ... → ${segments.last.destination}';
    }
    return '${order.source} → ${order.destination}';
  }

  /// "Loading - Segment 1", "Transit - Segment 2", ...
  static String currentStage(OrderModel order) {
    if (order.tripSegments.isEmpty) return 'N/A';
    for (var segment in order.tripSegments) {
      if (segment.segmentStatus != 'Completed') {
        final segmentNum = order.tripSegments.indexOf(segment) + 1;
        if (segment.segmentStatus == 'Pending') {
          return 'Loading - Segment $segmentNum';
        } else if (segment.segmentStatus.contains('In-Progress') ||
            segment.segmentStatus.contains('Transit')) {
          return 'Transit - Segment $segmentNum';
        } else {
          return '${segment.segmentStatus} - Segment $segmentNum';
        }
      }
    }
    return 'Completed - Segment ${order.tripSegments.length}';
  }

  /// "Pending Approval", "Approved - In Progress", "Approved by <name>", ...
  static String approvalStatus(OrderModel order) {
    final normalizedStatus = order.orderStatus.trim().toUpperCase();
    if (normalizedStatus == 'COMPLETED') {
      return 'Completed';
    } else if (normalizedStatus == 'REJECTED') {
      return 'Rejected';
    } else if (normalizedStatus == 'CANCELLED' || normalizedStatus == 'CANCELED') {
      return 'Cancelled';
    } else if (order.orderStatus == 'Open') {
      return 'Pending Approval';
    } else if (order.orderStatus == 'In-Progress') {
      return 'Approved - In Progress';
    } else if (order.orderStatus == 'En-Route') {
      for (var segment in order.tripSegments) {
        if (segment.workflow.isNotEmpty) {
          final approvedSteps =
              segment.workflow.where((s) => s.status == 'APPROVED').toList();
          if (approvedSteps.isNotEmpty) {
            final lastApproved = approvedSteps.last;
            if (lastApproved.approvedBy != null &&
                lastApproved.approvedBy!.isNotEmpty) {
              return 'Approved by ${lastApproved.approvedBy}';
            }
          }
        }
      }
      return 'En-Route';
    }
    return order.orderStatus;
  }

  /// "Bid Selected", "Approved", "In Transit", "Completed", ...
  static String flowStatus(OrderModel order, OrderWorkflowService workflow) {
    final effectiveStatus = workflow.getEffectiveOrderStatus(order);
    final normalizedOrderStatus = order.orderStatus.trim().toUpperCase();
    if (effectiveStatus == 'REJECTED') {
      return 'Rejected';
    } else if (effectiveStatus == 'COMPLETED') {
      return 'Completed';
    } else if (normalizedOrderStatus == 'CANCELLED' ||
        normalizedOrderStatus == 'CANCELED') {
      return 'Cancelled';
    } else if (order.orderStatus == 'Open') {
      return 'Bid Selected';
    } else if (order.orderStatus == 'In-Progress') {
      return 'Approved';
    } else if (order.orderStatus == 'En-Route') {
      return 'In Transit';
    }
    return order.orderStatus;
  }

  /// The vehicle record the card uses for type/capacity (null when no
  /// vehicle is assigned; a placeholder when the number isn't in the list).
  static VehicleModel? vehicleFor(List<VehicleModel> vehicles, String? vehicleNumber) {
    if (vehicleNumber == null || vehicleNumber.isEmpty) return null;
    for (final v in vehicles) {
      if (v.vehicleNumber == vehicleNumber) return v;
    }
    return VehicleModel(
      vehicleId: '',
      vehicleNumber: vehicleNumber,
      type: 'Unknown',
      capacityKg: 0,
      vehicleType: 'Unknown',
      vendorVehicle: '',
      isBusy: false,
    );
  }

  /// Vehicle type as the card prints it next to the vehicle number.
  static String vehicleType(VehicleModel? vehicle) {
    return vehicle?.vehicleType ?? vehicle?.type ?? 'N/A';
  }

  /// Capacity utilisation as the card's coloured badge shows it, e.g. "93.3".
  static String utilizationPercent(OrderModel order, VehicleModel? vehicle) {
    final capacity = vehicle?.capacityKg ?? 0;
    final weight = order.getTotalWeight();
    if (capacity <= 0 || weight <= 0) return '0.0';
    var pct = (weight.toDouble() / capacity.toDouble()) * 100.0;
    if (weight >= capacity || pct > 100.0) pct = 100.0;
    return pct.toStringAsFixed(1);
  }

  /// "d/m/yyyy HH:mm", the card's footer timestamp.
  static String createdLabel(OrderModel order) {
    final d = order.createdAt;
    if (d == null) return 'N/A';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }
}
