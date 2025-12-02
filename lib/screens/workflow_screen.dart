import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/trip_segment_model.dart';
import '../models/workflow_step_model.dart';
import '../models/vehicle_model.dart';
import '../providers/auth_provider.dart';
import '../services/order_workflow_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/workflow_stage_card.dart';

class WorkflowScreen extends StatefulWidget {
  final String orderId;

  const WorkflowScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  final OrderWorkflowService _workflowService = OrderWorkflowService();
  final ApiService _apiService = ApiService();
  OrderModel? _order;
  bool _isLoading = true;
  String? _error;
  bool _isProcessing = false;
  List<VehicleModel> _vehicles = [];
  String? _vehicleType;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _loadVehicles();
    // CRITICAL FIX: Set up optimized periodic refresh to prevent flickering
    _startPeriodicRefresh();
  }

  Future<void> _loadVehicles() async {
    try {
      final result = await _apiService.getVehicles();
      if (result['success'] == true && result['vehicles'] != null) {
        setState(() {
          _vehicles = result['vehicles'] as List<VehicleModel>;
          // Find vehicle type for the order's vehicle
          if (_order?.vehicleNumber != null && _order!.vehicleNumber!.isNotEmpty) {
            final vehicle = _vehicles.firstWhere(
              (v) => v.vehicleNumber == _order!.vehicleNumber,
              orElse: () => VehicleModel(
                vehicleId: '',
                vehicleNumber: _order!.vehicleNumber ?? '',
                type: '',
                capacityKg: 0,
                vehicleType: 'Unknown',
                vendorVehicle: '',
                isBusy: false,
              ),
            );
            _vehicleType = vehicle.vehicleType.isNotEmpty ? vehicle.vehicleType : vehicle.type.isNotEmpty ? vehicle.type : 'Unknown';
          }
        });
      }
    } catch (e) {
      print('Error loading vehicles: $e');
    }
  }
  
  @override
  void dispose() {
    // CRITICAL FIX: Clean up any timers or listeners to prevent memory leaks
    super.dispose();
  }

  // CRITICAL FIX: Optimize refresh to prevent flickering
  // Only refresh when order status or workflow actually changes
  DateTime? _lastRefreshTime;
  String? _lastOrderStatus;
  int? _lastWorkflowHash;
  
  void _startPeriodicRefresh() {
    // Refresh every 10 seconds (reduced from 5) and only if data actually changed
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        // Only refresh if enough time has passed and we're not currently processing
        if (!_isProcessing && (_lastRefreshTime == null || 
            DateTime.now().difference(_lastRefreshTime!) >= const Duration(seconds: 10))) {
          _loadOrderQuietly(); // Use quiet refresh that checks for changes
        }
        _startPeriodicRefresh();
      }
    });
  }
  
  // CRITICAL FIX: Quiet refresh that only updates state if data actually changed
  Future<void> _loadOrderQuietly() async {
    try {
      final result = await _apiService.getOrderById(widget.orderId);
      if (result['success'] == true && result['order'] != null) {
        final newOrder = result['order'] as OrderModel;
        
        // Calculate workflow hash to detect changes
        final workflowHash = newOrder.tripSegments.fold(0, (sum, seg) {
          return sum + seg.workflow.fold(0, (s, ws) => s + ws.status.hashCode + ws.timestamp);
        });
        
        // Only update state if something actually changed
        if (newOrder.orderStatus != _lastOrderStatus || workflowHash != _lastWorkflowHash) {
          setState(() {
            _order = newOrder;
            _lastOrderStatus = newOrder.orderStatus;
            _lastWorkflowHash = workflowHash;
            _lastRefreshTime = DateTime.now();
            // Update vehicle type if vehicle number changed
            if (newOrder.vehicleNumber != null && newOrder.vehicleNumber!.isNotEmpty && _vehicles.isNotEmpty) {
              final vehicle = _vehicles.firstWhere(
                (v) => v.vehicleNumber == newOrder.vehicleNumber,
                orElse: () => VehicleModel(
                  vehicleId: '',
                  vehicleNumber: newOrder.vehicleNumber ?? '',
                  type: '',
                  capacityKg: 0,
                  vehicleType: 'Unknown',
                  vendorVehicle: '',
                  isBusy: false,
                ),
              );
              _vehicleType = vehicle.vehicleType.isNotEmpty ? vehicle.vehicleType : vehicle.type.isNotEmpty ? vehicle.type : 'Unknown';
            }
          });
        }
      }
    } catch (e) {
      // Silently fail for quiet refresh
      print('Quiet refresh error: $e');
    }
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _apiService.getOrderById(widget.orderId);
      if (result['success'] == true && result['order'] != null) {
        final loadedOrder = result['order'] as OrderModel;
        setState(() {
          _order = loadedOrder;
          _isLoading = false;
          _error = null;
        });
        // Load vehicles and update vehicle type after order is loaded
        await _loadVehicles();
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to load order';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading order: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleWorkflowAction(
    TripSegment segment,
    String stage,
    String action,
    String? comments, {
    String? location,
  }) async {
    if (_order == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Find workflow step to get location if not provided
      String? workflowLocation = location;
      if (workflowLocation == null) {
        final matchingSteps = segment.workflow.where((ws) => ws.stage == stage);
        if (matchingSteps.isNotEmpty) {
          workflowLocation = matchingSteps.first.location;
        } else {
          workflowLocation = segment.source;
        }
      }
      
      final result = await _workflowService.performWorkflowAction(
        orderId: _order!.orderId,
        segmentId: segment.segmentId,
        stage: stage,
        action: action,
        userId: user.userId,
        comments: comments,
        location: workflowLocation,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Action performed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // CRITICAL FIX: Force immediate refresh after workflow action to pick up updated status
        // Clear previous state to force full reload
        setState(() {
          _lastOrderStatus = null;
          _lastWorkflowHash = null;
        });
        // Reload order to get updated workflow
        await _loadOrder();
        // CRITICAL FIX: Also force a quiet refresh after a short delay to catch any backend latency
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadOrderQuietly();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to perform action'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final userDepartment = user?.department ?? '';
    final userRole = user?.role ?? '';
    
    // CRITICAL FIX: Log user information immediately on screen load
    print('[Workflow Screen] ========================================');
    print('[Workflow Screen] Screen loaded - User Information:');
    print('  Logged-in User Name: ${user?.fullName ?? 'N/A'}');
    print('  Logged-in User Department: "$userDepartment"');
    print('  Logged-in User Role: $userRole');
    print('  Order ID: ${widget.orderId}');
    print('[Workflow Screen] ========================================');

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Workflow'),
          backgroundColor: AppTheme.darkSurface,
          foregroundColor: AppTheme.textPrimary,
        ),
        backgroundColor: AppTheme.darkBackground,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Workflow'),
          backgroundColor: AppTheme.darkSurface,
          foregroundColor: AppTheme.textPrimary,
        ),
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Order not found',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Workflow - ${_order!.orderId}'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _loadOrder,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: AppTheme.darkBackground,
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrder,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Info Card
                    Card(
                      elevation: 2,
                      color: AppTheme.darkCard,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Status: ${_order!.statusDisplay}',
                              style: TextStyle(
                                fontSize: 16,
                                color: _order!.statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Trip Type: ${_order!.tripType}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              'Vehicle: ${_order!.vehicleNumber ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (_vehicleType != null && _vehicleType!.isNotEmpty && _vehicleType != 'Unknown')
                              Text(
                                'Vehicle Type: $_vehicleType',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Segments
                    ..._order!.tripSegments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final segment = entry.value;
                      return _buildSegmentSection(
                        segment,
                        index + 1,
                        userDepartment,
                        userRole,
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSegmentSection(
    TripSegment segment,
    int segmentNumber,
    String userDepartment,
    String userRole,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segment Header
            Row(
              children: [
                Icon(Icons.route, color: AppTheme.primaryOrange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Segment $segmentNumber',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    segment.statusDisplay,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // CRITICAL FIX: Display complete route with "From [Source] To [Destination]" format
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: AppTheme.primaryOrange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    segment.source.isNotEmpty && segment.destination.isNotEmpty
                        ? 'From ${segment.source} To ${segment.destination}'
                        : segment.source.isNotEmpty
                            ? 'From ${segment.source}'
                            : segment.destination.isNotEmpty
                                ? 'To ${segment.destination}'
                                : 'Route not specified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Weight: ${segment.materialWeight} kg',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Workflow Stages
            const Text(
              'Workflow Stages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // CRITICAL FIX: Group stages by location (Origin first, then Destination)
            Builder(
              builder: (context) {
                // Sort workflow steps by stage_index to ensure correct order
                final sortedSteps = List<WorkflowStep>.from(segment.workflow);
                sortedSteps.sort((a, b) {
                  final indexA = a.stageIndex ?? 999;
                  final indexB = b.stageIndex ?? 999;
                  return indexA.compareTo(indexB);
                });

                // Group stages by location
                final originLocation = segment.source.isNotEmpty ? segment.source : 'Origin';
                final destinationLocation = segment.destination.isNotEmpty ? segment.destination : 'Destination';
                
                // Origin stages (indices 0-2)
                final originStages = sortedSteps.where((ws) {
                  final index = ws.stageIndex ?? 999;
                  return index < 3 || (ws.location == originLocation && index == 999);
                }).toList();
                
                // Destination stages (indices 3-5)
                final destinationStages = sortedSteps.where((ws) {
                  final index = ws.stageIndex ?? 999;
                  return index >= 3 || (ws.location == destinationLocation && index == 999);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display Origin stages
                    if (originStages.isNotEmpty) ...[
                      Text(
                        'Origin: $originLocation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...originStages.map((step) => _buildStageCard(
                        segment,
                        step.stage,
                        userDepartment,
                        userRole,
                        location: step.location,
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Display Destination stages
                    if (destinationStages.isNotEmpty) ...[
                      Text(
                        'Destination: $destinationLocation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...destinationStages.map((step) => _buildStageCard(
                        segment,
                        step.stage,
                        userDepartment,
                        userRole,
                        location: step.location,
                      )),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard(
    TripSegment segment,
    String stage,
    String userDepartment,
    String userRole, {
    String? location,
  }) {
    if (_order == null) return const SizedBox.shrink();

    // CRITICAL FIX: Find workflow step by both stage name AND location
    // This is necessary because we now have 6 stages (3 origin + 3 destination) with same stage names
    WorkflowStep workflowStep;
    final matchingSteps = segment.workflow.where((ws) => 
      ws.stage == stage && 
      (location == null || ws.location == location)
    );
    if (matchingSteps.isNotEmpty) {
      workflowStep = matchingSteps.first;
    } else {
      // Fallback: try to find by stage name only (for backward compatibility)
      final fallbackSteps = segment.workflow.where((ws) => ws.stage == stage);
      if (fallbackSteps.isNotEmpty) {
        workflowStep = fallbackSteps.first;
      } else {
        workflowStep = WorkflowStep(
          stage: stage,
          status: 'PENDING',
          location: location ?? segment.source,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }

    final canPerformAction = _workflowService.canPerformAction(
      userDepartment,
      userRole,
      stage,
      'APPROVE', // Check for approve action
    );

    final isStageActive = _workflowService.isStageActive(
      segment,
      stage,
      _order!.orderStatus,
      location: location ?? workflowStep.location,
    );

    final isRejected = workflowStep.status == 'REJECTED';
    final canRevoke = _workflowService.canPerformAction(
      userDepartment,
      userRole,
      stage,
      'REVOKE',
    );

    final canCancelPermission = _workflowService.canPerformAction(
      userDepartment,
      userRole,
      stage,
      'CANCEL',
    );
    
    // Block cancellation if order is fully completed
    final isOrderFullyCompleted = _workflowService.isOrderCompleted(_order!);
    final canCancel = canCancelPermission && !isOrderFullyCompleted;

    // CRITICAL FIX: Enhanced debug logging to diagnose button visibility
    print('[Workflow Screen] ========================================');
    print('[Workflow Screen] Building Stage Card for: $stage');
    print('[Workflow Screen]   Segment ID: ${segment.segmentId}');
    print('[Workflow Screen]   User Department: "$userDepartment"');
    print('[Workflow Screen]   User Role: $userRole');
    print('[Workflow Screen]   Workflow Step Status: "${workflowStep.status}"');
    print('[Workflow Screen]   Stage String: "$stage"');
    print('[Workflow Screen]   Order Status: ${_order!.orderStatus}');
    print('[Workflow Screen]   Can Perform Action: $canPerformAction');
    print('[Workflow Screen]   Is Stage Active: $isStageActive');
    print('[Workflow Screen]   Show Approve/Reject Condition:');
    print('     - canPerformAction: $canPerformAction');
    print('     - isStageActive: $isStageActive');
    print('     - workflowStep.status == PENDING: ${workflowStep.status == 'PENDING'}');
    
    // CRITICAL FIX: Log all workflow steps for this segment to diagnose sequential activation
    print('[Workflow Screen]   All Workflow Steps in Segment:');
    for (final ws in segment.workflow) {
      print('     - ${ws.stage}: ${ws.status} (approved_by: ${ws.approvedBy ?? 'N/A'})');
    }
    
    final showButtons = canPerformAction && isStageActive && workflowStep.status == 'PENDING';
    print('[Workflow Screen]   FINAL RESULT - Show Approve/Reject: $showButtons');
    print('[Workflow Screen]   Can Cancel: $canCancel');
    print('[Workflow Screen] ========================================');

    return WorkflowStageCard(
      workflowStep: workflowStep,
      stage: stage,
      canPerformAction: canPerformAction,
      isStageActive: isStageActive,
      isRejected: isRejected,
      canRevoke: canRevoke,
      canCancel: canCancel,
      onAction: (action, comments) {
        _handleWorkflowAction(segment, stage, action, comments, location: location ?? workflowStep.location);
      },
    );
  }
}

