import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vendor_provider.dart';
import '../models/order_model.dart';
import '../models/trip_segment_model.dart';
import '../models/vehicle_model.dart';
import '../models/workflow_step_model.dart';
import '../services/api_service.dart';
import '../services/order_workflow_service.dart';
import '../utils/permission_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_badge.dart';
import 'amendment_modal.dart';
import 'approval_summary_modal.dart';
import 'workflow_screen.dart';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key});

  @override
  State<OrdersDashboardScreen> createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen> {
  String _selectedFilter = 'All';
  final ApiService _apiService = ApiService();
  final OrderWorkflowService _workflowService = OrderWorkflowService();
  List<VehicleModel> _vehicles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
      _loadVehicles();
    });
  }

  Future<void> _loadOrders() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.loadOrders();
  }

  Future<void> _loadVehicles() async {
    try {
      final result = await _apiService.getVehicles();
      if (result['success'] == true) {
        setState(() {
          _vehicles = result['vehicles'] as List<VehicleModel>;
        });
      }
    } catch (e) {
      // Silently fail - vehicles data is optional
    }
  }

  // Helper to get vehicle data
  VehicleModel? _getVehicleData(String? vehicleNumber) {
    if (vehicleNumber == null || vehicleNumber.isEmpty) return null;
    try {
      return _vehicles.firstWhere(
        (v) => v.vehicleNumber == vehicleNumber,
        orElse: () => VehicleModel(
          vehicleId: '',
          vehicleNumber: vehicleNumber,
          type: 'Unknown',
          capacityKg: 0,
          vehicleType: 'Unknown',
          vendorVehicle: '',
          isBusy: false,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // Helper to get current segment status
  String _getCurrentSegmentStatus(OrderModel order) {
    if (order.tripSegments.isEmpty) return 'N/A';
    
    // Find the active segment (first non-completed segment)
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
    
    // All segments completed
    final lastSegment = order.tripSegments.last;
    return 'Completed - Segment ${order.tripSegments.length}';
  }

  // Helper to get approval workflow status
  String _getApprovalWorkflowStatus(OrderModel order) {
    if (order.orderStatus == 'Open') {
      return 'Pending Approval';
    } else if (order.orderStatus == 'In-Progress') {
      return 'Approved - In Progress';
    } else if (order.orderStatus == 'En-Route') {
      // Check workflow steps
      for (var segment in order.tripSegments) {
        if (segment.workflow.isNotEmpty) {
          // Find the last approved step
          final approvedSteps = segment.workflow.where((s) => s.status == 'APPROVED').toList();
          if (approvedSteps.isNotEmpty) {
            final lastApproved = approvedSteps.last;
            if (lastApproved.approvedBy != null && lastApproved.approvedBy!.isNotEmpty) {
              return 'Approved by ${lastApproved.approvedBy}';
            }
          }
        }
      }
      return 'En-Route';
    } else if (order.orderStatus == 'Completed') {
      return 'Completed';
    } else if (order.orderStatus == 'Cancelled') {
      return 'Cancelled';
    }
    return order.orderStatus;
  }

  // Helper to get flow status
  String _getFlowStatus(OrderModel order) {
    final effectiveStatus = _workflowService.getEffectiveOrderStatus(order);
    if (effectiveStatus == 'REJECTED') {
      return 'Rejected';
    } else if (effectiveStatus == 'COMPLETED') {
      return 'Completed';
    } else if (order.orderStatus == 'Open') {
      return 'Bid Selected';
    } else if (order.orderStatus == 'In-Progress') {
      return 'Approved';
    } else if (order.orderStatus == 'En-Route') {
      return 'In Transit';
    } else if (order.orderStatus == 'Cancelled') {
      return 'Cancelled';
    }
    return order.orderStatus;
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    if (_selectedFilter == 'All') {
      return orders;
    }
    
    // CRITICAL FIX: Use workflow completion check as source of truth
    // This ensures orders are filtered based on actual workflow state, not stale order_status
    return orders.where((order) {
      // 1. Determine effective status by checking workflow completion directly
      final bool isWorkflowDone = _workflowService.isOrderCompleted(order);
      final bool isWorkflowRejected = _workflowService.isOrderRejected(order);
      
      // 2. Use workflow completion check as primary source of truth
      String effectiveStatus;
      if (isWorkflowRejected) {
        effectiveStatus = 'REJECTED';
      } else if (isWorkflowDone) {
        effectiveStatus = 'COMPLETED'; // Use uppercase to match getEffectiveOrderStatus
      } else {
        // Fallback to order status if workflow is not complete
        effectiveStatus = order.orderStatus;
      }
      
      // 3. Normalize both the effective status and the active tab filter
      final normalizedEffectiveStatus = _normalizeStatusForFilter(effectiveStatus);
      final normalizedFilter = _normalizeStatusForFilter(_selectedFilter);
      
      // 4. Compare the normalized strings (case-insensitive matching)
      return normalizedEffectiveStatus == normalizedFilter;
    }).toList();
  }

  /// Normalizes status strings to match filter tab format (title case)
  /// Handles: 'COMPLETED' -> 'Completed', 'REJECTED' -> 'Cancelled', etc.
  /// This ensures case-insensitive matching between backend status and filter tabs
  String _normalizeStatusForFilter(String status) {
    final normalized = status.trim().toUpperCase();
    
    // Explicit mapping for terminal states (workflow-derived uppercase statuses)
    if (normalized == 'COMPLETED') {
      return 'Completed';
    }
    if (normalized == 'REJECTED' || normalized == 'CANCELLED' || normalized == 'CANCELED') {
      return 'Cancelled'; // REJECTED orders show in Cancelled tab
    }
    
    // Mapping for active states (case-insensitive)
    if (normalized == 'OPEN') return 'Open';
    if (normalized == 'IN-PROGRESS' || normalized == 'IN PROGRESS') return 'In-Progress';
    if (normalized == 'EN-ROUTE' || normalized == 'EN ROUTE') return 'En-Route';
    
    // Fallback: if already in correct format, return as-is
    final original = status.trim();
    if (original == 'Open' || original == 'In-Progress' || original == 'En-Route' || 
        original == 'Completed' || original == 'Cancelled') {
      return original;
    }
    
    // Final fallback: try case-insensitive match
    final lower = normalized.toLowerCase();
    if (lower == 'completed') return 'Completed';
    if (lower == 'cancelled' || lower == 'canceled' || lower == 'rejected') return 'Cancelled';
    if (lower == 'in-progress' || lower == 'in progress') return 'In-Progress';
    if (lower == 'en-route' || lower == 'en route') return 'En-Route';
    if (lower == 'open') return 'Open';
    
    // Return original if no match found
    return status.trim();
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status) {
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
      case 'REJECTED':
        return 'REJECTED';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showOrderDetailModal(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailModal(
        order: order,
        onStatusUpdate: () => _loadOrders(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soliflex Packaging - Orders Dashboard'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          const NotificationBadge(),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  'All',
                  'Open',
                  'In-Progress',
                  'En-Route',
                  'Completed',
                  'Cancelled'
                ].where((filter) => filter != 'Pending Approvals').map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: AppTheme.darkSurface,
                      selectedColor: AppTheme.primaryOrange,
                      checkmarkColor: AppTheme.white,
                    ),
                  );
                }).toList(),
              ),
            ),
            // Orders List
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (orderProvider.error != null && orderProvider.orders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                              const SizedBox(height: 16),
                              Text(
                                orderProvider.error!,
                                style: const TextStyle(color: AppTheme.errorRed),
                              ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadOrders(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredOrders = _getFilteredOrders(orderProvider.orders);

                  if (filteredOrders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                          Text(
                            'No orders found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadOrders,
                    color: const Color(0xFFFF6600),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Responsive grid: 4 columns on desktop (>1200px), 2 columns on mobile (≤800px)
                        int crossAxisCount = 2;
                        if (constraints.maxWidth > 1200) {
                          crossAxisCount = 4;
                        } else if (constraints.maxWidth > 800) {
                          crossAxisCount = 3;
                        } else {
                          crossAxisCount = 2;
                        }
                        
                        return GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: constraints.maxWidth > 800 ? 1.35 : 1.25, // Optimized for compact cards
                          ),
                      itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _buildOrderCard(order, constraints.maxWidth);
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/rfq/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Order'),
        backgroundColor: AppTheme.primaryOrange.withOpacity(0.9),
        foregroundColor: AppTheme.white,
        elevation: 2,
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, double screenWidth) {
    // CRITICAL FIX: Use workflow service to get effective status
    final effectiveStatus = _workflowService.getEffectiveOrderStatus(order);
    final statusColor = _getStatusColor(effectiveStatus);
    final statusDisplay = _getStatusDisplay(effectiveStatus);
    
    // Build route summary from segments
    // Build route summary from trip_segments, handling Round Trip correctly
    String routeSummary = '';
    if (order.tripSegments.length == 1) {
      // Single Trip: Simple A → B
      routeSummary = '${order.tripSegments[0].source} → ${order.tripSegments[0].destination}';
    } else if (order.tripSegments.length > 1) {
      // Multiple segments: Show full route or summary
      if (order.tripType == 'Round-Trip-Vendor' || order.originalTripType == 'Round-Trip-Vendor') {
        // Round Trip: Show A → B → A format
        final firstSegment = order.tripSegments[0];
        final lastSegment = order.tripSegments[order.tripSegments.length - 1];
        if (firstSegment.source == lastSegment.destination) {
          // Classic round trip: A → B → A
          routeSummary = '${firstSegment.source} → ${firstSegment.destination} → ${lastSegment.destination}';
        } else {
          // Complex round trip with intermediate segments
          routeSummary = '${firstSegment.source} → ${firstSegment.destination} → ... → ${lastSegment.destination}';
        }
      } else {
        // Multiple Trip: Show first → ... → last
        routeSummary = '${order.tripSegments[0].source} → ... → ${order.tripSegments[order.tripSegments.length - 1].destination}';
      }
    } else {
      // Fallback to top-level source/destination
      routeSummary = '${order.source} → ${order.destination}';
    }
    
    // Calculate totals
    int totalWeight = order.getTotalWeight();
    int totalInvoice = order.getTotalInvoiceAmount();
    int totalToll = order.getTotalTollCharges();
    
    // Format creation time
    String formattedTime = 'N/A';
    if (order.createdAt != null) {
      final date = order.createdAt!;
      formattedTime = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Get vehicle data
    final vehicle = _getVehicleData(order.vehicleNumber);
    final vehicleType = vehicle?.vehicleType ?? vehicle?.type ?? 'N/A';
    final vehicleCapacity = vehicle?.capacityKg ?? 0;
    
    // Calculate utilization percentage with proper handling for exact matches and edge cases
    double capacityPercentageValue = 0.0;
    String capacityPercentage = '0.0';
    if (vehicleCapacity > 0 && totalWeight > 0) {
      // Use double division to ensure proper calculation (avoid integer division issues)
      capacityPercentageValue = (totalWeight.toDouble() / vehicleCapacity.toDouble()) * 100.0;
      // Handle exact match: if weight equals or exceeds capacity, show 100%
      if (totalWeight >= vehicleCapacity) {
        capacityPercentageValue = 100.0;
      }
      // Cap at 100% if it exceeds due to floating point precision
      if (capacityPercentageValue > 100.0) {
        capacityPercentageValue = 100.0;
      }
      capacityPercentage = capacityPercentageValue.toStringAsFixed(1);
    } else if (vehicleCapacity > 0 && totalWeight == 0) {
      // Order has no weight, show 0%
      capacityPercentage = '0.0';
      capacityPercentageValue = 0.0;
    }
    
    // Get workflow status information
    final currentSegmentStatus = _getCurrentSegmentStatus(order);
    final approvalWorkflowStatus = _getApprovalWorkflowStatus(order);
    final flowStatus = _getFlowStatus(order);
    
    // Professional, compact card design with enhanced information density
    return Card(
      elevation: 0.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: statusColor.withOpacity(0.4), width: 0.6),
      ),
      color: AppTheme.darkCard,
      child: InkWell(
        onTap: () => _showOrderDetailModal(order),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line 1: Order ID | Status | (Amended flag)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.primaryOrange,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: statusColor, width: 0.5),
                    ),
                    child: Text(
                      statusDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (order.isAmended) ...[
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: Colors.orange, width: 0.5),
                      ),
                      child: const Text(
                        'Amended',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 2: Member Name | Department Name
              Row(
                children: [
                  Icon(Icons.person, size: 9, color: AppTheme.textSecondary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Member: ${order.creatorName ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dept: ${order.creatorDepartment ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 3: Vehicle Number | Vehicle Type | Capacity %
              Row(
                children: [
                  if (order.vehicleNumber != null && order.vehicleNumber!.isNotEmpty) ...[
                    Icon(Icons.local_shipping, size: 9, color: AppTheme.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        order.vehicleNumber!,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vehicleType,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: vehicleCapacity > 0 && capacityPercentageValue >= 80
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: vehicleCapacity > 0 && capacityPercentageValue >= 80
                              ? Colors.green
                              : Colors.orange,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '$capacityPercentage%',
                        style: TextStyle(
                          color: vehicleCapacity > 0 && capacityPercentageValue >= 80
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.warning_amber_rounded, size: 9, color: Colors.orange),
                    const SizedBox(width: 2),
                    const Text(
                      'Assignment Pending',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 4: Route: Starting Point → End Point
              Row(
                children: [
                  Icon(Icons.route, size: 9, color: AppTheme.textSecondary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      routeSummary,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 4: Current Segment Status | Flow Status
              Row(
                children: [
                  Icon(Icons.location_on, size: 9, color: AppTheme.textSecondary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      currentSegmentStatus,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.blue, width: 0.5),
                    ),
                    child: Text(
                      flowStatus,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 5: Approval Workflow Status
              Row(
                children: [
                  Icon(Icons.verified_user, size: 9, color: AppTheme.textSecondary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      approvalWorkflowStatus,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 6: Total Weight | Total Invoice | Total Toll
              Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.scale, size: 9, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        '${totalWeight} kg',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (totalInvoice > 0) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_money, size: 9, color: Colors.green.shade600),
                        const SizedBox(width: 2),
                        Text(
                          '₹$totalInvoice',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (totalToll > 0) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_atm, size: 9, color: Colors.blue.shade600),
                        const SizedBox(width: 2),
                        Text(
                          'Toll: ₹$totalToll',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Line 7: Trip Type | Creator User ID
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.tripType,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (order.creatorUserId != null && order.creatorUserId!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 8, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          'Creator: ${order.creatorUserId}',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 2),
              
              // Footer: Creation Time | Order Category
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 8, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          fontSize: 8,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: order.orderCategory == 'Internal Transfer'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: order.orderCategory == 'Internal Transfer'
                            ? Colors.green
                            : Colors.blue,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      order.orderCategory,
                      style: TextStyle(
                        color: order.orderCategory == 'Internal Transfer'
                            ? Colors.green
                            : Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 7,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailModal extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onStatusUpdate;
  final ApiService _apiService = ApiService();
  final OrderWorkflowService _workflowService = OrderWorkflowService();

  OrderDetailModal({
    super.key,
    required this.order,
    required this.onStatusUpdate,
  });

  Color _getStatusColor(String status) {
    switch (status) {
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
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplay(String status) {
    switch (status) {
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
      case 'REJECTED':
        return 'REJECTED';
      default:
        return status;
    }
  }

  Color _getSegmentStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.grey;
      case 'In-Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAuditTimestamp(DateTime? date) {
    if (date == null) return 'N/A';
    // DateTime is already in IST (parsed from backend with +05:30 offset)
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} IST';
  }

  Widget _buildTotalRow(String label, String value, IconData icon, [Color? valueColor]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.primaryOrange,
          ),
        ),
      ],
    );
  }

  void _showAmendmentModal(BuildContext context, OrderModel order) {
    Navigator.of(context).pop(); // Close detail modal first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    showDialog(
      context: context,
      builder: (context) => AmendmentModal(
        order: order,
        onAmend: (newSegments) async {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User not found. Please login again.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          final result = await orderProvider.amendOrder(
            orderId: order.orderId,
            newSegments: newSegments,
            userId: user.userId, // Pass userId for audit trail
          );
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Order amended'),
                backgroundColor: result['success'] == true ? Colors.green : Colors.red,
              ),
            );
            
            if (result['success'] == true) {
              Navigator.of(context).pop(); // Close amendment modal
              onStatusUpdate(); // Reload orders
            }
          }
        },
      ),
    );
  }

  void _showApprovalSummaryModal(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => ApprovalSummaryModal(
        order: order,
        onApprove: () => _updateOrderStatus(context, 'In-Progress'),
      ),
    );
  }

  Future<void> _updateOrderStatus(BuildContext context, String newStatus) async {
    // Check if vehicle is required and missing
    if ((newStatus == 'In-Progress' || newStatus == 'En-Route') && 
        (order.vehicleId == null || order.vehicleId!.isEmpty)) {
      // Show vehicle selection dialog
      await _showVehicleSelectionDialog(context, newStatus);
      return;
    }
    
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.userId;
    final result = await orderProvider.updateOrderStatus(
      orderId: order.orderId,
      newStatus: newStatus,
      userId: userId,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Status updated'),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );

      if (result['success'] == true) {
        onStatusUpdate();
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _showVehicleSelectionDialog(BuildContext context, String newStatus) async {
    // Get order's total weight for vehicle matching
    final totalWeight = order.getTotalWeight();
    
    // Show dialog with vehicle selection
    final selectedVehicle = await showDialog<VehicleModel?>(
      context: context,
      builder: (dialogContext) => _VehicleSelectionDialog(
        order: order,
        totalWeight: totalWeight,
        apiService: _apiService,
      ),
    );
    
    if (selectedVehicle == null || !context.mounted) {
      // User cancelled or no vehicle selected
      return;
    }
    
    // Show loading indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assigning vehicle and approving order...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    try {
      // Assign vehicle to order
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.userId;
      
      final assignResult = await _apiService.assignVehicleToOrder(
        orderId: order.orderId,
        vehicleId: selectedVehicle.vehicleId,
        vehicleNumber: selectedVehicle.vehicleNumber,
        vehicleType: selectedVehicle.vehicleType.isNotEmpty ? selectedVehicle.vehicleType : selectedVehicle.type,
        capacityKg: selectedVehicle.capacityKg,
        userId: userId,
      );
      
      if (!context.mounted) return;
      
      if (assignResult['success'] == true) {
        // Vehicle assigned successfully, now update order status directly
        // IMPORTANT: Call provider directly to avoid the vehicle check in _updateOrderStatus
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        
        final statusResult = await orderProvider.updateOrderStatus(
          orderId: order.orderId,
          newStatus: newStatus,
          userId: userId,
        );
        
        if (!context.mounted) return;
        
        if (statusResult['success'] == true) {
          // Success: Show message, refresh, then close modal
          if (context.mounted) {
            // Show success message first
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vehicle assigned and order approved successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Refresh orders list
            onStatusUpdate();
            
            // Close order detail modal
            Navigator.of(context).pop();
          }
        } else {
          // Status update failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusResult['message'] ?? 'Failed to approve order'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Vehicle assignment failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(assignResult['message'] ?? 'Failed to assign vehicle'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final isAdmin = user?.role == 'SUPER_USER' || user?.department == 'Admin' || user?.department == 'Accounts Team';
    // CRITICAL FIX: Use workflow service to get effective status
    final effectiveStatus = _workflowService.getEffectiveOrderStatus(order);
    final statusColor = _getStatusColor(effectiveStatus);
    final statusDisplay = _getStatusDisplay(effectiveStatus);

    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7, // 70vh equivalent
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Reduced from 24.0
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Divider(color: AppTheme.darkBorder),
                const SizedBox(height: 12), // Reduced from 16
                _buildDetailRow('Order ID', order.orderId),
                _buildDetailRow('Member Name', order.creatorName ?? 'N/A'),
                _buildDetailRow('Department', order.creatorDepartment ?? 'N/A'),
                // For Round Trip: Display route summary instead of simple Source → Destination
                if (order.tripType == 'Round-Trip-Vendor' || order.originalTripType == 'Round-Trip-Vendor') ...[
                  if (order.tripSegments.length >= 2) ...[
                    _buildDetailRow('Route', '${order.tripSegments[0].source} → ${order.tripSegments[0].destination} → ${order.tripSegments[order.tripSegments.length - 1].destination}'),
                  ] else ...[
                    _buildDetailRow('Source', order.source),
                    _buildDetailRow('Destination', order.destination),
                  ],
                ] else ...[
                  _buildDetailRow('Source', order.source),
                  _buildDetailRow('Destination', order.destination),
                ],
                _buildDetailRow('Trip Type', '${order.tripType}${order.isAmended ? " (Amended)" : ""}'),
                _buildDetailRow('Order Category', order.orderCategory),
                if (order.vehicleNumber != null && order.vehicleNumber!.isNotEmpty)
                  _buildDetailRow('Vehicle', order.vehicleNumber!),
                const SizedBox(height: 12), // Reduced from 16
                // Trip Segments Display
                Text(
                  'Trip Segments',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.darkBorder),
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.darkSurface,
                  ),
                  child: Column(
                    children: order.tripSegments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final segment = entry.value;
                      return Container(
                        padding: const EdgeInsets.all(10), // Reduced from 12
                        decoration: BoxDecoration(
                          border: index < order.tripSegments.length - 1
                              ? Border(bottom: BorderSide(color: AppTheme.darkBorder))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Segment #${segment.segmentId}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getSegmentStatusColor(segment.segmentStatus).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _getSegmentStatusColor(segment.segmentStatus),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    segment.statusDisplay,
                                    style: TextStyle(
                                      color: _getSegmentStatusColor(segment.segmentStatus),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4), // Reduced from 6
                            Text(
                              '${segment.source} → ${segment.destination}',
                              style: const TextStyle(
                                fontSize: 11, // Reduced from 12
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3), // Reduced from 4
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Material: ${segment.materialWeight} kg',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Type: ${segment.materialTypeList.join(", ")}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                if (segment.invoiceAmount != null || segment.tollCharges != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (segment.invoiceAmount != null)
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.green, width: 1),
                                                  ),
                                                  child: Text(
                                                    'Invoice: ₹${segment.invoiceAmount}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (segment.isManualInvoice == true) ...[
                                                const SizedBox(width: 4),
                                                Tooltip(
                                                  message: 'Manually entered amount',
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(3),
                                                      border: Border.all(color: Colors.orange, width: 0.8),
                                                    ),
                                                    child: const Text(
                                                      'M',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        color: Colors.orange,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      if (segment.tollCharges != null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.blue, width: 1),
                                            ),
                                            child: Text(
                                              'Toll: ₹${segment.tollCharges}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12), // Reduced from 20
                
                // Order Totals Section
                const Text(
                  'Order Totals',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Reduced from 16
                    color: Color(0xFFFF6600),
                  ),
                ),
                const SizedBox(height: 8), // Reduced from 12
                Container(
                  padding: const EdgeInsets.all(12), // Reduced from 16
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildTotalRow('Total Weight', '${order.getTotalWeight()} kg', Icons.scale),
                      const Divider(height: 12), // Reduced from 20
                      _buildTotalRow('Freight Charges', '₹${order.getTotalInvoiceAmount()}', Icons.attach_money, Colors.green),
                      const Divider(height: 12), // Reduced from 20
                      _buildTotalRow('Total Toll', '₹${order.getTotalTollCharges()}', Icons.local_atm, Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Order Lifecycle Audit Trail Section
                const Text(
                  'Order Lifecycle Audit Trail',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Initial Creation Section
                      _buildAuditSection(
                        'Initial Creation',
                        [
                          _buildAuditRow('Created Timestamp', _formatAuditTimestamp(order.createdAt)),
                          _buildAuditRow('Created By Member', order.creatorName ?? 'N/A'),
                          _buildAuditRow('Created By Department', order.creatorDepartment ?? 'N/A'),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.darkBorder),
                      // Approval Stage Section
                      _buildAuditSection(
                        'Approval Stage',
                        [
                          _buildAuditRow('Approved Timestamp', order.approvedTimestamp != null ? _formatAuditTimestamp(order.approvedTimestamp) : 'Not yet approved'),
                          _buildAuditRow('Approved By Member', order.approvedByMember ?? 'N/A'),
                          _buildAuditRow('Approved By Department', order.approvedByDepartment ?? 'N/A'),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.darkBorder),
                      // Vehicle/Facility Execution Section
                      _buildAuditSection(
                        'Vehicle/Facility Execution',
                        [
                          _buildAuditRow('Vehicle Started At', order.vehicleStartedAtTimestamp != null ? _formatAuditTimestamp(order.vehicleStartedAtTimestamp) : 'Not started'),
                          _buildAuditRow('Started From Location', order.vehicleStartedFromLocation ?? 'N/A'),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.darkBorder),
                      // Entry/Security Checkpoint Section
                      _buildAuditSection(
                        'Entry/Security Checkpoint',
                        [
                          _buildAuditRow('Security Entry Timestamp', order.securityEntryTimestamp != null ? _formatAuditTimestamp(order.securityEntryTimestamp) : 'Not recorded'),
                          _buildAuditRow('Security Guard Member', order.securityEntryMemberName ?? 'N/A'),
                          _buildAuditRow('Checkpoint Location', order.securityEntryCheckpointLocation ?? 'N/A'),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.darkBorder),
                      // Stores/Validation Section
                      _buildAuditSection(
                        'Stores/Validation',
                        [
                          _buildAuditRow('Stores Validation Timestamp', order.storesValidationTimestamp != null ? _formatAuditTimestamp(order.storesValidationTimestamp) : 'Not completed'),
                        ],
                      ),
                      const Divider(height: 20, color: AppTheme.darkBorder),
                      // Exit/Completion Section
                      _buildAuditSection(
                        'Exit/Completion',
                        [
                          _buildAuditRow('Vehicle Exited Timestamp', order.vehicleExitedTimestamp != null ? _formatAuditTimestamp(order.vehicleExitedTimestamp) : 'Not completed'),
                          _buildAuditRow('Exit Approved By Timestamp', order.exitApprovedByTimestamp != null ? _formatAuditTimestamp(order.exitApprovedByTimestamp) : 'N/A'),
                          _buildAuditRow('Exit Approved By Member', order.exitApprovedByMemberName ?? 'N/A'),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amendment History Section
                if (order.amendmentHistory != null && order.amendmentHistory!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Amendment History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBorder, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: order.amendmentHistory!.map((amendment) {
                        return _buildAmendmentHistoryEntry(amendment);
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10), // Reduced from 12
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: statusColor, size: 18), // Reduced from default
                      const SizedBox(width: 8),
                      Text(
                        'Status: $statusDisplay',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14, // Reduced from 16
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // Reduced from 24
                // Amend Order Button (visible for Open, In-Progress, En-Route)
                if (order.orderStatus == 'Open' || order.orderStatus == 'In-Progress' || order.orderStatus == 'En-Route')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAmendmentModal(context, order),
                        icon: const Icon(Icons.edit),
                        label: const Text('Amend Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                // Approve Amendment Button (for Admin/Accounts Team when status is Open after amendment)
                if (isAdmin && order.orderStatus == 'Open' && order.isAmended)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _updateOrderStatus(context, 'In-Progress'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve Amendment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                // Action Buttons (Role-based)
                if (isAdmin && order.orderStatus == 'Open' && !order.isAmended)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(context, 'In-Progress'),
                      icon: Icon(order.vehicleId == null || order.vehicleId!.isEmpty 
                          ? Icons.local_shipping 
                          : Icons.check),
                      label: Text(order.vehicleId == null || order.vehicleId!.isEmpty 
                          ? 'Assign Vehicle & Approve' 
                          : 'Approve Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (order.orderStatus == 'In-Progress')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateOrderStatus(context, 'En-Route'),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Start Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (order.orderStatus == 'En-Route') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close detail modal
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => WorkflowScreen(orderId: order.orderId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.work),
                      label: const Text('View Workflow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Cancel Order button - disabled if order is fully completed
                if (order.orderStatus != 'Completed' && order.orderStatus != 'Cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (context) {
                        final isCompleted = _workflowService.isOrderCompleted(order);
                        return Tooltip(
                          message: isCompleted 
                              ? 'Order cannot be cancelled after all approval stages have been completed'
                              : 'Cancel this order',
                          child: ElevatedButton.icon(
                            onPressed: isCompleted ? null : () => _updateOrderStatus(context, 'Cancelled'),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted ? Colors.grey : Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmendmentHistoryEntry(AmendmentHistoryEntry amendment) {
    final formattedDate = _formatAmendmentDate(amendment.timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Version and Timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  amendment.version,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Amended By
          Text(
            'Amended by ${amendment.amendedBy} (${amendment.amendedByDepartment})',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          // Change Log
          if (amendment.changeLog.isNotEmpty) ...[
            const Text(
              'Changes:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            ...amendment.changeLog.map((change) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12)),
                    Expanded(
                      child: Text(
                        change,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  String _formatAmendmentDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year at $hour:$minute IST';
  }

  Widget _buildAuditSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.primaryOrange,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildAuditRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), // Reduced from 12.0
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Vehicle Selection Dialog for Order Approval
class _VehicleSelectionDialog extends StatefulWidget {
  final OrderModel order;
  final int totalWeight;
  final ApiService apiService;

  const _VehicleSelectionDialog({
    required this.order,
    required this.totalWeight,
    required this.apiService,
  });

  @override
  State<_VehicleSelectionDialog> createState() => _VehicleSelectionDialogState();
}

class _VehicleSelectionDialogState extends State<_VehicleSelectionDialog> {
  List<VehicleModel> _matchedVehicles = [];
  VehicleModel? _selectedVehicle;
  bool _showManualVehicleEntry = false;
  bool _isMatchingVehicles = false;
  
  // Manual vehicle entry controllers
  final _manualVehicleNumberController = TextEditingController();
  final _manualVehicleTypeController = TextEditingController();
  final _manualCapacityController = TextEditingController();
  String? _manualVehicleType;
  
  final List<String> _vehicleTypeOptions = ['Open', 'Closed', 'Container'];

  @override
  void initState() {
    super.initState();
    _matchVehicles();
  }

  @override
  void dispose() {
    _manualVehicleNumberController.dispose();
    _manualVehicleTypeController.dispose();
    _manualCapacityController.dispose();
    super.dispose();
  }

  Future<void> _matchVehicles() async {
    setState(() {
      _isMatchingVehicles = true;
      _showManualVehicleEntry = false;
    });

    try {
      final result = await widget.apiService.matchVehicles(widget.totalWeight);
      if (result['success'] == true) {
        setState(() {
          _matchedVehicles = result['vehicles'] as List<VehicleModel>;
          _selectedVehicle = null;
          if (_matchedVehicles.isEmpty) {
            _showManualVehicleEntry = true;
          }
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isMatchingVehicles = false;
      });
    }
  }

  void _handleConfirm() {
    if (_selectedVehicle != null) {
      Navigator.of(context).pop(_selectedVehicle);
    } else if (_showManualVehicleEntry) {
      if (_manualVehicleNumberController.text.trim().isEmpty ||
          _manualVehicleType == null ||
          _manualCapacityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete all manual vehicle entry fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Create a manual vehicle entry
      final manualVehicle = VehicleModel(
        vehicleId: '',
        vehicleNumber: _manualVehicleNumberController.text.trim(),
        type: _manualVehicleType!,
        capacityKg: int.tryParse(_manualCapacityController.text.trim()) ?? 0,
        vehicleType: _manualVehicleType!,
        vendorVehicle: 'manual_entry',
        isBusy: false,
      );
      Navigator.of(context).pop(manualVehicle);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle or use manual entry'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign Vehicle to Order',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Order ${widget.order.orderId} - Total Weight: ${widget.totalWeight} kg',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (_isMatchingVehicles)
                  const Center(child: CircularProgressIndicator())
                else if (_matchedVehicles.isEmpty && !_showManualVehicleEntry)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'No suitable vehicles found',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use the "Add Manual Truck Entry" button below.',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...(_matchedVehicles.map((vehicle) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildVehicleCard(vehicle),
                  ))),
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.orange),
                    title: const Text('Add Manual Truck Entry'),
                    onTap: () {
                      setState(() {
                        _showManualVehicleEntry = !_showManualVehicleEntry;
                        if (_showManualVehicleEntry) {
                          _selectedVehicle = null;
                        }
                      });
                    },
                  ),
                ),
                if (_showManualVehicleEntry) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualVehicleNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _manualVehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _vehicleTypeOptions.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _manualVehicleType = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Assign & Continue'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    final isSelected = _selectedVehicle?.vehicleId == vehicle.vehicleId;
    final isOptimal = vehicle.utilizationPercentage != null && 
                      vehicle.utilizationPercentage! >= 80 && 
                      vehicle.utilizationPercentage! <= 100;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? AppTheme.primaryOrange 
              : (isOptimal ? Colors.green : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedVehicle = vehicle;
            _showManualVehicleEntry = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vehicle.vehicleNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppTheme.primaryOrange),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Type: ${vehicle.vehicleType.isNotEmpty ? vehicle.vehicleType : vehicle.type}'),
                  const SizedBox(width: 16),
                  Text('Capacity: ${vehicle.capacityKg} kg'),
                ],
              ),
              if (vehicle.utilizationPercentage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Utilization: ${vehicle.utilizationPercentage!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isOptimal ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

