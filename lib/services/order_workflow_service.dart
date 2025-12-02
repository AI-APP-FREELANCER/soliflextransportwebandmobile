import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/trip_segment_model.dart';
import '../models/workflow_step_model.dart';
import 'api_service.dart';
import '../utils/permission_utils.dart';

// Department constants for workflow
const securityDepartments = [
  'Security-Factory 1',
  'Security-Factory 2',
  'Security-Factory 3',
  'Security-Factory 4'
];

const storesDepartments = [
  'Stores IAF UNit-I/ Soliflex unit-I',
  'Stores Unit-IV/ Soliflex unit-II',
  'Soliflex Unit-III',
  'Fabric IAF unit-1 / Soliflex unit-1',
  'Fabric Soliflex unit-III',
  'Fabric Unit-IV/ Soliflex unit-II'
];

class OrderWorkflowService {
  final ApiService _apiService = ApiService();
  
  // CRITICAL FIX: Temporary test mode - set to true to always show buttons for debugging
  // Set to false in production
  static const bool _testModeAlwaysAllow = false; // Set to true for testing

  // Initialize workflow for an order
  Future<Map<String, dynamic>> initializeWorkflow(String orderId) async {
    try {
      return await _apiService.initializeWorkflow(orderId);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error initializing workflow: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Perform workflow action (approve/reject/revoke/cancel)
  Future<Map<String, dynamic>> performWorkflowAction({
    required String orderId,
    required int segmentId,
    required String stage,
    required String action,
    required String userId,
    String? comments,
    String? location,
  }) async {
    try {
      return await _apiService.performWorkflowAction(
        orderId: orderId,
        segmentId: segmentId,
        stage: stage,
        action: action,
        userId: userId,
        comments: comments,
        location: location,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Error performing workflow action: ${e.toString()}',
        'order': null,
      };
    }
  }

  // Get order with workflow
  Future<OrderModel?> getOrderWithWorkflow(String orderId) async {
    try {
      final result = await _apiService.getOrderById(orderId);
      if (result['success'] == true && result['order'] != null) {
        return result['order'] as OrderModel;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if user can perform action (client-side role check)
  // CRITICAL FIX: Add explicit logging, flexible department matching, and Admin/Account privileged override
  bool canPerformAction(String userDepartment, String userRole, String stage, String action) {
    // CRITICAL FIX: Log all inputs for debugging
    print('[canPerformAction] ========================================');
    print('[canPerformAction] Checking permissions:');
    print('  Stage: "$stage"');
    print('  Action: "$action"');
    print('  User Department: "$userDepartment"');
    print('  User Role: "$userRole"');
    
    // CRITICAL FIX: Normalize strings for robust comparison
    final normalizedDepartment = userDepartment.trim().toLowerCase();
    final normalizedRole = userRole.trim().toUpperCase();
    final normalizedAction = action.trim().toUpperCase();
    
    // --- CRITICAL FIX: SUPER_USER ABSOLUTE OVERRIDE (FIRST CHECK) ---
    // SUPER_USER can perform ANY action on ANY stage - complete override
    if (normalizedRole == 'SUPER_USER') {
      print('  [SUPER_USER ABSOLUTE OVERRIDE] Result: true');
      print('    - SUPER_USER has full access to all actions on all stages');
      print('    - Action: $normalizedAction');
      print('    - Stage: $stage');
      print('[canPerformAction] ========================================');
      return true;
    }
    
    // CRITICAL FIX: Temporary test mode - always allow for debugging
    if (_testModeAlwaysAllow && (normalizedAction == 'APPROVE' || normalizedAction == 'REJECT')) {
      print('  [TEST MODE] Always allowing action for testing');
      print('[canPerformAction] ========================================');
      return true;
    }
    
    // --- CRITICAL FIX: ADMIN/ACCOUNT TEAM PRIVILEGED OVERRIDE ---
    // Allow Admin or Account Team to perform APPROVE/REJECT on ANY stage.
    if (normalizedAction == 'APPROVE' || normalizedAction == 'REJECT') {
      if (normalizedDepartment == 'admin' || 
          normalizedDepartment.contains('admin') ||
          normalizedDepartment == 'accounts team' ||
          normalizedDepartment.contains('accounts') ||
          normalizedDepartment.contains('account')) {
        print('  [PRIVILEGED OVERRIDE (Admin/Account)] Result: true');
        print('    - User Role: $userRole');
        print('    - User Department: "$userDepartment"');
        print('[canPerformAction] ========================================');
        return true;
      }
    }
    
    if (normalizedAction == 'CANCEL') {
      // Only Admin/Accounts can cancel
      final canCancel = normalizedRole == 'SUPER_USER' || 
                        normalizedRole == 'APPROVAL_MANAGER' ||
                        normalizedDepartment == 'admin' ||
                        normalizedDepartment.contains('admin') ||
                        normalizedDepartment == 'accounts team' ||
                        normalizedDepartment.contains('accounts') ||
                        normalizedDepartment.contains('account');
      print('  [CANCEL] Result: $canCancel (Role: $userRole, Dept: "$userDepartment")');
      print('[canPerformAction] ========================================');
      return canCancel;
    }

    if (normalizedAction == 'REVOKE') {
      // Admin/Accounts can revoke any rejection
      final canRevoke = normalizedRole == 'SUPER_USER' || 
                        normalizedRole == 'APPROVAL_MANAGER' ||
                        normalizedDepartment == 'admin' ||
                        normalizedDepartment.contains('admin') ||
                        normalizedDepartment == 'accounts team' ||
                        normalizedDepartment.contains('accounts') ||
                        normalizedDepartment.contains('account');
      print('  [REVOKE] Result: $canRevoke (Role: $userRole, Dept: "$userDepartment")');
      print('[canPerformAction] ========================================');
      return canRevoke;
    }

    // CRITICAL FIX: Normalize stage string for comparison (case-insensitive, trim whitespace)
    // Note: normalizedDepartment is already declared above
    final normalizedStage = stage.trim().toUpperCase();
    final isStoresStage = normalizedStage == 'STORES_VERIFICATION';
    
    print('  [Stage Normalization] Original: "$stage" -> Normalized: "$normalizedStage"');
    print('  [Department Normalization] Original: "$userDepartment" -> Normalized: "$normalizedDepartment"');
    
    // Check Security departments (case-insensitive, partial match)
    bool isSecurityRole = false;
    for (final dept in securityDepartments) {
      if (normalizedDepartment.contains(dept.toLowerCase()) || 
          dept.toLowerCase().contains(normalizedDepartment)) {
        isSecurityRole = true;
        print('  [Security] Matched department: "$userDepartment" with "$dept"');
        break;
      }
    }
    
    // Check Stores departments (case-insensitive, partial match)
    bool isStoresRole = false;
    for (final dept in storesDepartments) {
      if (normalizedDepartment.contains(dept.toLowerCase()) || 
          dept.toLowerCase().contains(normalizedDepartment)) {
        isStoresRole = true;
        print('  [Stores] Matched department: "$userDepartment" with "$dept"');
        break;
      }
    }
    
    // CRITICAL FIX: Also check for simple "Security" or "Stores" keywords
    if (!isSecurityRole && normalizedDepartment.contains('security')) {
      isSecurityRole = true;
      print('  [Security] Matched by keyword: "security"');
    }
    
    if (!isStoresRole && (normalizedDepartment.contains('stores') || 
                          normalizedDepartment.contains('fabric') ||
                          normalizedDepartment.contains('soliflex'))) {
      isStoresRole = true;
      print('  [Stores] Matched by keyword: stores/fabric/soliflex');
    }

    print('  [Role Check] isSecurityRole: $isSecurityRole, isStoresRole: $isStoresRole');

    if (isStoresStage) {
      // Only Stores/Fabric can interact with Verification stage
      final result = isStoresRole;
      print('  [STORES_VERIFICATION] Result: $result (isStoresRole: $isStoresRole)');
      return result;
    } else {
      // Only Security can interact with Entry/Exit stages
      final result = isSecurityRole;
      print('  [SECURITY_ENTRY/EXIT] Result: $result (isSecurityRole: $isSecurityRole)');
      print('[canPerformAction] ========================================');
      return result;
    }
  }

  // Check if a workflow stage is currently active (client-side sequential activation check)
  // CRITICAL FIX: Updated to handle 6 stages (3 origin + 3 destination) by position/index
  bool isStageActive(TripSegment segment, String stage, String orderStatus, {String? location}) {
    // CRITICAL FIX: Add explicit logging for stage activation
    print('[isStageActive] ========================================');
    print('[isStageActive] Checking stage activation:');
    print('  Stage: "$stage"');
    print('  Location: "$location"');
    print('  Order Status: "$orderStatus"');
    print('  Segment ID: ${segment.segmentId}');
    
    // Order must be En-Route
    if (orderStatus != 'En-Route') {
      print('  [FAIL] Order status is not En-Route: "$orderStatus"');
      print('[isStageActive] ========================================');
      return false;
    }

    // Parse workflow steps
    final workflowSteps = segment.workflow;
    print('  Workflow Steps Count: ${workflowSteps.length}');

    // Sort workflow steps by stage_index to ensure correct order
    final sortedSteps = List<WorkflowStep>.from(workflowSteps);
    sortedSteps.sort((a, b) {
      final indexA = a.stageIndex ?? 999;
      final indexB = b.stageIndex ?? 999;
      return indexA.compareTo(indexB);
    });

    // Find the current stage by both stage name AND location
    WorkflowStep? currentStage;
    if (location != null && location.isNotEmpty) {
      currentStage = sortedSteps.firstWhere(
        (ws) => ws.stage == stage && ws.location == location,
        orElse: () => sortedSteps.firstWhere(
          (ws) => ws.stage == stage,
          orElse: () => sortedSteps.first,
        ),
      );
    } else {
      final matchingSteps = sortedSteps.where((ws) => ws.stage == stage);
      currentStage = matchingSteps.isNotEmpty ? matchingSteps.first : null;
    }

    if (currentStage == null) {
      print('  [FAIL] Current stage not found in workflow steps');
      print('  Available stages: ${sortedSteps.map((ws) => '${ws.stage}@${ws.location}').join(', ')}');
      print('[isStageActive] ========================================');
      return false;
    }
    
    print('  Current Stage Found: ${currentStage.stage}@${currentStage.location}, Status: ${currentStage.status}, Index: ${currentStage.stageIndex}');
    
    if (currentStage.status != 'PENDING') {
      print('  [FAIL] Current stage status is not PENDING: ${currentStage.status}');
      print('[isStageActive] ========================================');
      return false;
    }

    // Get current stage index (0-5 for 6 stages)
    final currentStageIndex = currentStage.stageIndex ?? sortedSteps.indexOf(currentStage);
    
    print('  Current Stage Index: $currentStageIndex');

    // First stage (index 0): Active if order is En-Route, stage is PENDING, and no prior rejections
    if (currentStageIndex == 0) {
      print('  [FIRST STAGE] Origin SECURITY_ENTRY - always active if PENDING (no prior stages)');
      print('[isStageActive] ========================================');
      return true;
    }

    // Check if any prior stage is REJECTED (blocking condition)
    for (int i = 0; i < currentStageIndex; i++) {
      if (i < sortedSteps.length) {
        final priorStage = sortedSteps[i];
        print('  Checking prior stage $i: ${priorStage.stage}@${priorStage.location} - Status: ${priorStage.status}');
        
        if (priorStage.status == 'REJECTED') {
          print('  [FAIL] Prior stage ${priorStage.stage}@${priorStage.location} is REJECTED - blocking activation');
          print('[isStageActive] ========================================');
          return false;
        }
      }
    }
    
    print('  [PASS] No prior stages are REJECTED');
    
    // Sequential activation: Stage N is active only if Stage N-1 is APPROVED
    if (currentStageIndex > 0 && currentStageIndex - 1 < sortedSteps.length) {
      final precedingStage = sortedSteps[currentStageIndex - 1];
      
      print('  Checking preceding stage: ${precedingStage.stage}@${precedingStage.location}');
      print('  Preceding stage status: "${precedingStage.status}"');
      
      // Current stage is active ONLY if preceding stage is APPROVED or COMPLETED
      final precedingStatus = precedingStage.status.trim().toUpperCase();
      final isPrecedingApproved = precedingStatus == 'APPROVED' || precedingStatus == 'COMPLETED';
      final currentStatus = currentStage.status.trim().toUpperCase();
      final isCurrentPending = currentStatus == 'PENDING';
      final isActive = isPrecedingApproved && isCurrentPending;
      
      print('  Preceding stage status (normalized): "$precedingStatus"');
      print('  Preceding stage is APPROVED/COMPLETED: $isPrecedingApproved');
      print('  Current stage status (normalized): "$currentStatus"');
      print('  Current stage is PENDING: $isCurrentPending');
      print('  [${currentStage.stage}@${currentStage.location}] Final Result: $isActive');
      print('[isStageActive] ========================================');
      return isActive;
    }
    
    print('  [FAIL] Preceding stage not found');
    print('[isStageActive] ========================================');
    return false;
  }

  // ====================================================================
  // STATUS MANAGEMENT UTILITIES
  // ====================================================================
  
  /// Checks if the entire order is rejected (at least one stage in any segment is REJECTED)
  bool isOrderRejected(OrderModel order) {
    // Check if order status is already REJECTED or CANCELLED
    final normalizedStatus = order.orderStatus.trim().toUpperCase();
    if (normalizedStatus == 'REJECTED' || normalizedStatus == 'CANCELLED' || normalizedStatus == 'CANCELED') {
      return true;
    }
    
    // Check all segments and all steps for a REJECTED status
    final isRejected = order.tripSegments.any((segment) {
      return segment.workflow.any((step) {
        final stepStatus = step.status.trim().toUpperCase();
        return stepStatus == 'REJECTED' || stepStatus == 'CANCELLED' || stepStatus == 'CANCELED';
      });
    });
    
    return isRejected;
  }
  
  /// Checks if the entire order is fully completed (all stages in all segments are APPROVED/COMPLETED)
  bool isOrderCompleted(OrderModel order) {
    // If the entire order has already been marked as REJECTED, it cannot be completed.
    if (isOrderRejected(order)) {
      return false;
    }
    
    // If order has no segments, consider it incomplete
    if (order.tripSegments.isEmpty) {
      return false;
    }
    
    // Order is completed only if every single workflow step across all segments 
    // has a status of 'APPROVED' or 'COMPLETED'.
    final allStepsComplete = order.tripSegments.every((segment) {
      if (segment.workflow.isEmpty) {
        // If a segment has no workflow, check if order is in a terminal state
        // For orders that were created before workflow was implemented
        final normalizedStatus = order.orderStatus.trim().toUpperCase();
        return normalizedStatus == 'COMPLETED';
      }
      return segment.workflow.every((step) {
        final status = step.status.trim().toUpperCase();
        return status == 'APPROVED' || status == 'COMPLETED';
      });
    });
    
    return allStepsComplete;
  }

  /// Gets the effective display status for an order based on workflow state
  /// Returns: 'REJECTED', 'COMPLETED', or the original order status
  String getEffectiveOrderStatus(OrderModel order) {
    if (isOrderRejected(order)) {
      return 'REJECTED';
    }
    if (isOrderCompleted(order)) {
      return 'COMPLETED';
    }
    return order.orderStatus;
  }

  // ====================================================================
  // PUBLIC PERMISSION METHODS FOR UI ACCESS CONTROL
  // ====================================================================
  
  /// Helper to check for privileged roles/departments (private)
  bool _isPrivilegedUser(String userDepartment, String userRole) {
    final normalizedDepartment = userDepartment.trim().toLowerCase();
    final normalizedRole = userRole.trim().toUpperCase();
    return normalizedRole == 'SUPER_USER' || 
           normalizedDepartment == 'admin' || 
           normalizedDepartment.contains('admin') ||
           normalizedDepartment == 'accounts team' || 
           normalizedDepartment.contains('accounts') ||
           normalizedDepartment.contains('account');
  }

  /// Public method to check if user is privileged (Admin, Accounts Team, or SUPER_USER)
  /// Used by UI components to determine visibility of Admin tab and features
  bool isPrivilegedUser(String userDepartment, String userRole) {
    return _isPrivilegedUser(userDepartment, userRole);
  }

  /// Checks if user belongs to Admin department
  /// Used for Manage Users and full administrative access
  bool isAdminDept(String userDepartment) {
    final normalized = userDepartment.trim().toLowerCase();
    return normalized == 'admin' || normalized.contains('admin');
  }

  /// Checks if user can manage Vendors and Vehicles
  /// Returns true if user is Admin OR Accounts Team
  bool isVendorVehicleManager(String userDepartment, String userRole) {
    final normalizedDepartment = userDepartment.trim().toLowerCase();
    final normalizedRole = userRole.trim().toUpperCase();
    
    // Admin users can always manage vendors/vehicles
    if (isAdminDept(userDepartment) || normalizedRole == 'SUPER_USER') {
      return true;
    }
    
    // Accounts Team can also manage vendors/vehicles
    return normalizedDepartment == 'accounts team' || 
           normalizedDepartment.contains('accounts') ||
           normalizedDepartment.contains('account');
  }
}

