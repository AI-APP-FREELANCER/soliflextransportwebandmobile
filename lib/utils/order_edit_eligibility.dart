import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/order_workflow_service.dart';

/// Shared rules for vehicle and segment-pricing edits (order detail, workflow, etc.).
class OrderEditEligibility {
  OrderEditEligibility._();

  /// Fully inactive: completed, rejected, cancelled, or closed — no vehicle/pricing edits.
  static bool isInactive(OrderModel order, OrderWorkflowService workflow) {
    if (workflow.isOrderCompleted(order) || workflow.isOrderRejected(order)) {
      return true;
    }
    final s = order.orderStatus.trim().toUpperCase();
    return s == 'COMPLETED' ||
        s == 'REJECTED' ||
        s == 'CANCELLED' ||
        s == 'CANCELED' ||
        s == 'CLOSED';
  }

  /// Admin / Accounts / SUPER_USER, or order creator (matches orders dashboard).
  static bool canChangeVehicle(
    OrderModel order,
    OrderWorkflowService workflow,
    UserModel? user,
  ) {
    if (isInactive(order, workflow)) return false;
    if (user == null) return false;
    final privileged = user.role == 'SUPER_USER' ||
        user.department == 'Admin' ||
        user.department == 'Accounts Team';
    if (privileged) return true;
    final cid = order.creatorUserId ?? '';
    return cid.isNotEmpty && cid == user.userId;
  }

  /// Admin / Accounts / SUPER_USER only; until inactive (matches segment-pricing API).
  static bool canEditSegmentPricing(
    OrderModel order,
    OrderWorkflowService workflow,
    UserModel? user,
  ) {
    if (isInactive(order, workflow)) return false;
    if (user == null) return false;
    return user.role == 'SUPER_USER' ||
        user.department == 'Admin' ||
        user.department == 'Accounts Team';
  }

  /// Revenue summaries, order-card invoice/toll, and related dashboard money UI.
  static bool canViewOrderFinancials(UserModel? user) {
    if (user == null) return false;
    return user.role == 'SUPER_USER' ||
        user.department == 'Admin' ||
        user.department == 'Accounts Team';
  }
}
