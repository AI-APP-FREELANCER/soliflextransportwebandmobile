import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import '../services/order_workflow_service.dart';
import '../theme/app_theme.dart';
import '../utils/export_utils.dart';
import '../utils/order_card_info.dart';
import '../utils/order_edit_eligibility.dart';
import '../utils/permission_utils.dart';
import '../widgets/notification_badge.dart';
import 'admin_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Global route observer for home screen refresh
final RouteObserver<PageRoute> homeRouteObserver = RouteObserver<PageRoute>();

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, RouteAware {
  String _selectedDateRange = 'Current Week';
  DateTime? _customFromDate;
  DateTime? _customToDate;
  List<VehicleModel> _vehicles = [];
  bool _isLoadingVehicles = false;
  // Drives the All Orders table's always-visible horizontal scrollbar, so a
  // narrow window doesn't silently hide the columns on the right.
  final ScrollController _allOrdersHScroll = ScrollController();
  // Same workflow rules the order cards use to decide an order's status.
  final OrderWorkflowService _workflowService = OrderWorkflowService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load orders and vehicles when home screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      homeRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeRouteObserver.unsubscribe(this);
    _allOrdersHScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload data when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  // Called when the current route has been pushed.
  @override
  void didPush() {
    _refreshData();
  }

  // Called when the top route has been popped off, and this route shows up.
  @override
  void didPopNext() {
    // Refresh when navigating back to home screen
    _refreshData();
  }

  Future<void> _refreshData() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    await orderProvider.loadOrders();
    if (mounted) {
      _loadVehicles();
    }
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final apiService = ApiService();
      final result = await apiService.getVehicles();
      if (result['success'] == true) {
        setState(() {
          _vehicles = result['vehicles'] as List<VehicleModel>;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
    }
  }

  DateTime _getDateRangeStart() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case 'Current Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case 'Previous Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return startOfWeek.subtract(const Duration(days: 7));
      case 'Last 15 Days':
        return now.subtract(const Duration(days: 15));
      case 'Month to Date':
        return DateTime(now.year, now.month, 1);
      case 'Custom Range':
        return _customFromDate ?? DateTime(2020, 1, 1);
      default:
        return DateTime(2020, 1, 1);
    }
  }

  DateTime _getDateRangeEnd() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case 'Previous Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return startOfWeek.subtract(const Duration(days: 1));
      case 'Custom Range':
        return _customToDate != null
            ? DateTime(_customToDate!.year, _customToDate!.month, _customToDate!.day, 23, 59, 59)
            : now;
      default:
        return now;
    }
  }

  // Uses two single-month pickers (each with visible prev/next month
  // navigation) instead of showDateRangePicker, whose default calendar view
  // only supports going back via an undiscoverable vertical scroll gesture.
  Future<void> _openCustomDateRangePicker() async {
    final now = DateTime.now();
    final firstAllowedDate = DateTime(2020, 1, 1);

    final fromDate = await showDatePicker(
      context: context,
      helpText: 'SELECT START DATE',
      initialDate: _customFromDate ?? now,
      firstDate: firstAllowedDate,
      lastDate: now,
    );
    if (fromDate == null || !mounted) return;

    final defaultToDate = _customToDate != null && !_customToDate!.isBefore(fromDate)
        ? _customToDate!
        : (now.isBefore(fromDate) ? fromDate : now);
    final toDate = await showDatePicker(
      context: context,
      helpText: 'SELECT END DATE',
      initialDate: defaultToDate,
      firstDate: fromDate,
      lastDate: now,
    );
    if (toDate == null || !mounted) return;

    setState(() {
      _customFromDate = fromDate;
      _customToDate = toDate;
      _selectedDateRange = 'Custom Range';
    });
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _customRangeLabel() =>
      (_customFromDate != null && _customToDate != null)
          ? '${_formatDate(_customFromDate!)} - ${_formatDate(_customToDate!)}'
          : 'Custom Range';

  // Used for export filenames so a custom range doesn't collide with
  // previously exported "Custom_Range" files.
  String _dateRangeFileSuffix() => (_selectedDateRange == 'Custom Range')
      ? _customRangeLabel().replaceAll(' ', '').replaceAll('/', '-')
      : _selectedDateRange.replaceAll(' ', '_');

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    final startDate = _getDateRangeStart();
    final endDate = _getDateRangeEnd();
    // Bound by calendar day, not by the exact instant _getDateRangeStart/End
    // return. The previous "-1 day / +1 day" padding was meant to make the
    // comparison inclusive, but it actually widened the window by a full
    // extra day on each side whenever effectiveDate carried a time-of-day
    // (which createdAt-based dates always do) -- e.g. a Custom Range of
    // 1-9 Sep would still match an order timestamped Aug 31 at 18:00,
    // since that's "after" (1 Sep minus 1 day = 31 Aug at 00:00).
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    return orders.where((order) {
      // Bucket by the actual trip/bill date when the order has one;
      // orders created before that field existed fall back to createdAt.
      final effectiveDate = order.effectiveDate;
      if (effectiveDate == null) return false;
      return !effectiveDate.isBefore(rangeStart) && !effectiveDate.isAfter(rangeEnd);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soliflex Packaging - Home'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _refreshData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Analytics refreshed'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            tooltip: 'Refresh Analytics',
          ),
          // Notification badge
          const NotificationBadge(),
          // User info in top right corner
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.user;
              if (user == null) {
                return const SizedBox.shrink();
              }
              
              // For mobile, show popup menu
              if (MediaQuery.of(context).size.width < 600) {
                return PopupMenuButton<String>(
                  icon: CircleAvatar(
                    backgroundColor: AppTheme.textPrimary.withOpacity(0.2),
                    child: const Icon(Icons.person, color: AppTheme.textPrimary),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _handleLogout(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.department,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                );
              }
              
              // For desktop/tablet, show inline user info
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          user.department,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppTheme.textPrimary),
                      onPressed: () => _handleLogout(context),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final user = authProvider.user;
            
            if (user == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                // Determine optimal number of cards to show based on screen width
                // Calculate based on average card width (~200px) plus spacing
                final cardWidth = 200.0; // Target width for each card
                final minSpacing = 12.0; // Minimum spacing between cards
                final maxSpacing = 24.0; // Maximum spacing between cards
                
                // Calculate how many cards fit with optimal spacing
                int crossAxisCount;
                double cardSpacing;
                double containerPadding;
                
                if (constraints.maxWidth > 1400) {
                  crossAxisCount = 6;
                } else if (constraints.maxWidth > 1100) {
                  crossAxisCount = 5;
                } else if (constraints.maxWidth > 900) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 600) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }
                
                // Calculate spacing to center cards evenly
                final totalCardWidth = cardWidth * crossAxisCount;
                final availableWidth = constraints.maxWidth - 32; // Account for container padding
                final totalSpacing = availableWidth - totalCardWidth;
                final spacingPerGap = totalSpacing / (crossAxisCount + 1); // +1 for left and right padding
                
                // Clamp spacing to reasonable limits
                cardSpacing = spacingPerGap.clamp(minSpacing, maxSpacing);
                
                // Calculate container padding to center cards
                final usedWidth = (cardWidth * crossAxisCount) + (cardSpacing * (crossAxisCount - 1));
                containerPadding = (availableWidth - usedWidth) / 2;
                containerPadding = containerPadding.clamp(16.0, 32.0);
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: containerPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            // Quick Actions Section (centered)
                            Text(
                              'Quick Actions',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Action Cards Grid centered with equal spacing
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: cardSpacing,
                                runSpacing: cardSpacing,
                                children: [
                          // Create Order Button
                          _buildActionCard(
                            context,
                            icon: Icons.add_business,
                            title: 'Create Order',
                            subtitle: 'New Order',
                            onTap: () {
                              // CRITICAL FIX: Use centralized permission check
                              if (hasOperationalAccess(user.department, user.role)) {
                                Navigator.of(context).pushNamed('/rfq/create');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You do not have permission to create orders'),
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                );
                              }
                            },
                          ),
                          // Orders Dashboard Button
                          _buildActionCard(
                            context,
                            icon: Icons.dashboard,
                            title: 'Orders Dashboard',
                            subtitle: 'View All',
                            onTap: () {
                              Navigator.of(context).pushNamed('/orders');
                            },
                          ),
                          // Admin Dashboard Button - Only for Admin, Accounts Team, or SUPER_USER
                          if (hasSuperAdminAccess(user.department, user.role) || 
                              hasAccountTeamAccess(user.department, user.role))
                            _buildActionCard(
                              context,
                              icon: Icons.admin_panel_settings,
                              title: 'Admin',
                              subtitle: 'Manage',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AdminDashboardScreen(),
                                  ),
                                );
                              },
                            ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Analytics Section - Real-time metrics
                            Consumer<OrderProvider>(
                              builder: (context, orderProvider, child) {
                                final allOrders = orderProvider.orders;
                                // Apply date range filter to all analytics
                                final filteredOrders = _getFilteredOrders(allOrders);
                                final metrics = _calculateMetrics(filteredOrders);
                                final statusMetrics = _calculateStatusMetrics(filteredOrders);
                                final user = Provider.of<AuthProvider>(context, listen: false).user;
                                final showFinancials = OrderEditEligibility.canViewOrderFinancials(user);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Section Title with Date Range Filter
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Analytics Dashboard',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            fontSize: 18,
                                          ),
                                        ),
                                        // Date Range Filter
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkSurface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.darkBorder, width: 0.5),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.date_range, size: 16, color: AppTheme.textSecondary),
                                              const SizedBox(width: 8),
                                              DropdownButton<String>(
                                                value: _selectedDateRange,
                                                isDense: true,
                                                underline: const SizedBox(),
                                                dropdownColor: AppTheme.darkCard,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 13,
                                                ),
                                                items: ['Current Week', 'Previous Week', 'Last 15 Days', 'Month to Date', 'Custom Range']
                                                    .map((range) => DropdownMenuItem(
                                                          value: range,
                                                          child: Text(range),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  if (value == 'Custom Range') {
                                                    _openCustomDateRangePicker();
                                                  } else if (value != null) {
                                                    setState(() => _selectedDateRange = value);
                                                  }
                                                },
                                              ),
                                              if (_selectedDateRange == 'Custom Range' &&
                                                  _customFromDate != null &&
                                                  _customToDate != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '(${_customRangeLabel()})',
                                                  style: const TextStyle(
                                                    color: AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Real-time Metrics Cards
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isMobile = constraints.maxWidth < 600;
                                        return GridView.count(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          crossAxisCount: isMobile ? 2 : 4,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: isMobile ? 2.5 : 3.2,
                                          children: [
                                            _buildMetricCard(
                                              context,
                                              'Total Orders',
                                              statusMetrics['total'].toString(),
                                              Icons.description,
                                              AppTheme.primaryOrange,
                                            ),
                                            _buildMetricCard(
                                              context,
                                              'Open',
                                              statusMetrics['open'].toString(),
                                              Icons.open_in_new,
                                              Colors.green,
                                            ),
                                            _buildMetricCard(
                                              context,
                                              'In-Progress',
                                              statusMetrics['inProgress'].toString(),
                                              Icons.hourglass_empty,
                                              Colors.blue,
                                            ),
                                            _buildMetricCard(
                                              context,
                                              'Completed',
                                              statusMetrics['completed'].toString(),
                                              Icons.check_circle,
                                              Colors.grey,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    // Trip Type Analysis
                                    _buildTripTypeCard(context, metrics),
                                    if (showFinancials) ...[
                                      const SizedBox(height: 12),
                                      _buildRevenueCard(context, metrics),
                                    ],
                                    const SizedBox(height: 16),
                                    // Operational Analysis Section
                                    _buildOperationalAnalysisSection(
                                      context,
                                      filteredOrders,
                                      showFinancialBreakdown: showFinancials,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: AppTheme.darkBorder,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200, // Fixed width for uniformity
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0), // Reduced by ~50%
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Reduced from 8
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6600).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5), // Reduced from 6
                ),
                child: Icon(
                  icon,
                  size: 14, // Reduced from 18 (~22% reduction to maintain visibility)
                  color: const Color(0xFFFF6600),
                ),
              ),
              const SizedBox(width: 8), // Reduced from 10
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 12, // Reduced from 13
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1), // Reduced from 2
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 10, // Reduced from 11
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate analytics metrics from orders
  Map<String, dynamic> _calculateMetrics(List<OrderModel> orders) {
    Map<String, int> tripTypeCount = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    Map<String, int> tripTypeInvoice = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    Map<String, int> tripTypeToll = {
      'Single-Trip-Vendor': 0,
      'Round-Trip-Vendor': 0,
      'Multiple-Trip-Vendor': 0,
      'Internal-Transfer': 0,
    };
    
    int totalInvoice = 0;
    int totalToll = 0;
    int totalOther = 0;

    for (var order in orders) {
      // Count by trip type
      if (tripTypeCount.containsKey(order.tripType)) {
        tripTypeCount[order.tripType] = (tripTypeCount[order.tripType] ?? 0) + 1;
      }
      
      // Calculate invoice and toll by trip type
      int orderInvoice = order.getTotalInvoiceAmount();
      int orderToll = order.getTotalTollCharges();
      
      totalInvoice += orderInvoice;
      totalToll += orderToll;
      totalOther += order.getTotalOtherCharges();

      if (tripTypeInvoice.containsKey(order.tripType)) {
        tripTypeInvoice[order.tripType] = (tripTypeInvoice[order.tripType] ?? 0) + orderInvoice;
        tripTypeToll[order.tripType] = (tripTypeToll[order.tripType] ?? 0) + orderToll;
      }
    }
    
    return {
      'tripTypeCount': tripTypeCount,
      'tripTypeInvoice': tripTypeInvoice,
      'tripTypeToll': tripTypeToll,
      'totalInvoice': totalInvoice,
      'totalToll': totalToll,
      'totalOther': totalOther,
      'totalOrders': orders.length,
    };
  }

  // Calculate status metrics - Normalize status for comparison
  String _normalizeStatus(String status) {
    return status.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
  }

  // Calculate status metrics
  Map<String, int> _calculateStatusMetrics(List<OrderModel> orders) {
    return {
      'total': orders.length,
      'open': orders.where((o) => _normalizeStatus(o.orderStatus) == 'open').length,
      'inProgress': orders.where((o) {
        final normalized = _normalizeStatus(o.orderStatus);
        return normalized == 'in-progress' || normalized == 'inprogress';
      }).length,
      'enRoute': orders.where((o) {
        final normalized = _normalizeStatus(o.orderStatus);
        return normalized == 'en-route' || normalized == 'enroute';
      }).length,
      'completed': orders.where((o) {
        final normalized = _normalizeStatus(o.orderStatus);
        return normalized == 'completed' || normalized == 'complete';
      }).length,
      'cancelled': orders.where((o) {
        final normalized = _normalizeStatus(o.orderStatus);
        return normalized == 'cancelled' || normalized == 'canceled';
      }).length,
    };
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon and Title on left
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            // Value on right
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                    fontSize: 18,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTypeCard(BuildContext context, Map<String, dynamic> metrics) {
    final tripTypeCount = metrics['tripTypeCount'] as Map<String, int>? ?? {};
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trip Type Distribution',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTripTypeItem(context, 'Single', tripTypeCount['Single-Trip-Vendor'] ?? 0, Colors.blue),
                _buildTripTypeItem(context, 'Round', tripTypeCount['Round-Trip-Vendor'] ?? 0, Colors.green),
                _buildTripTypeItem(context, 'Multiple', tripTypeCount['Multiple-Trip-Vendor'] ?? 0, Colors.orange),
                _buildTripTypeItem(context, 'Internal', tripTypeCount['Internal-Transfer'] ?? 0, Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTypeItem(BuildContext context, String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard(BuildContext context, Map<String, dynamic> metrics) {
    final totalInvoice = metrics['totalInvoice'] as int? ?? 0;
    final totalToll = metrics['totalToll'] as int? ?? 0;
    final totalOther = metrics['totalOther'] as int? ?? 0;
    // Everything charged on the orders: freight + toll + other charges. Same
    // formula as "Total" in All Orders and "Total Cost" in Financial Breakdown.
    final total = totalInvoice + totalToll + totalOther;
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Revenue Summary',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 10),
            _buildRevenueItem(context, 'Freight Charges', '₹$totalInvoice', Colors.green),
            const SizedBox(height: 8),
            _buildRevenueItem(context, 'Total Toll Charges', '₹$totalToll', Colors.blue),
            const SizedBox(height: 8),
            _buildRevenueItem(context, 'Other Charges', '₹$totalOther', Colors.purple),
            const Divider(height: 16, thickness: 0.5, color: AppTheme.darkBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Revenue',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                ),
                Text(
                  '₹$total',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueItem(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
            ),
          ],
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
      ],
    );
  }

  // ====================================================================
  // OPERATIONAL ANALYSIS SECTION
  // ====================================================================

  Widget _buildOperationalAnalysisSection(
    BuildContext context,
    List<OrderModel> filteredOrders, {
    required bool showFinancialBreakdown,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
      ),
      color: AppTheme.darkCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Title
            Text(
              'Operational Analysis',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
            ),
            const SizedBox(height: 16),
            // All Orders -- every order in the currently applied filter
            // (date range, or a future search filter), one row per order.
            // Unlike the sections below, this always matches "Total Orders".
            _buildAllOrdersTable(
              context,
              filteredOrders,
              showFinancials: showFinancialBreakdown,
            ),
            _buildSectionDivider(),
            // Utilization Analysis Table
            _buildUtilizationAnalysisTable(context, filteredOrders),
            if (showFinancialBreakdown) ...[
              _buildSectionDivider(),
              _buildFinancialBreakdownTable(context, filteredOrders),
            ],
            _buildSectionDivider(),
            // Operational Insights
            _buildOperationalInsights(context, filteredOrders),
          ],
        ),
      ),
    );
  }

  // Clear visual break between two dashboard tables/sections -- a plain
  // gap alone made it hard to tell where one table ended and the next began.
  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1, color: AppTheme.darkBorder),
    );
  }

  Widget _buildAllOrdersTable(
    BuildContext context,
    List<OrderModel> orders, {
    required bool showFinancials,
  }) {
    // Single source of truth for this section: the on-screen table AND the
    // CSV export are both generated from this list, so what is shown and what
    // is exported cannot drift apart. Money columns follow the same rule as
    // Revenue Summary / Financial Breakdown on this page
    // (OrderEditEligibility.canViewOrderFinancials).
    //
    // All figures come from the same OrderModel getters the Order Detail
    // screen and Financial Breakdown already use, so numbers reconcile:
    //   Total = Invoice + Toll + Other  (same formula as Financial Breakdown).
    int totalCost(OrderModel o) =>
        o.getTotalInvoiceAmount() + o.getTotalTollCharges() + o.getTotalOtherCharges();
    String dateOf(OrderModel o) =>
        o.effectiveDate != null ? _formatDate(o.effectiveDate!) : 'N/A';
    String shortTripType(OrderModel o) =>
        o.tripType.replaceAll('-Trip-Vendor', '').replaceAll('-', ' ');
    // Descriptions entered with "Other charges" (per segment), only for
    // segments that actually carry an amount.
    String otherChargesNote(OrderModel o) {
      final notes = <String>[];
      for (final s in o.tripSegments) {
        if ((s.otherCharges ?? 0) <= 0) continue;
        final d = (s.otherChargesDescription ?? '').trim();
        if (d.isNotEmpty && !notes.contains(d)) notes.add(d);
      }
      return notes.join('; ');
    }

    VehicleModel? vehicleOf(OrderModel o) =>
        OrderCardInfo.vehicleFor(_vehicles, o.vehicleNumber);
    // The card only shows a utilisation badge once a vehicle is assigned.
    String utilizationOf(OrderModel o) {
      final v = vehicleOf(o);
      return v == null ? 'N/A' : '${OrderCardInfo.utilizationPercent(o, v)}%';
    }
    // The card prints "(was N kg)" only when an amendment changed the weight.
    String? originalWeightOf(OrderModel o) {
      final original = o.originalTotalWeight;
      return (original != null && original != o.getTotalWeight()) ? '$original' : null;
    }

    final columns = <_AllOrdersColumn>[
      _AllOrdersColumn(
        header: 'Order ID',
        exportHeader: 'Order ID',
        width: 90,
        emphasize: true,
        display: (o) => o.orderId,
        export: (o) => o.orderId,
      ),
      _AllOrdersColumn(
        header: 'Date',
        exportHeader: 'Date',
        width: 85,
        display: dateOf,
        export: dateOf,
      ),
      _AllOrdersColumn(
        header: 'Source',
        exportHeader: 'Source',
        width: 100,
        flexible: true,
        display: (o) => o.source,
        export: (o) => o.source,
      ),
      _AllOrdersColumn(
        header: 'Destination',
        exportHeader: 'Destination',
        width: 100,
        flexible: true,
        display: (o) => o.destination,
        export: (o) => o.destination,
      ),
      _AllOrdersColumn(
        header: 'Vehicle',
        exportHeader: 'Vehicle',
        width: 95,
        display: (o) => o.vehicleNumber ?? 'N/A',
        export: (o) => o.vehicleNumber ?? '',
      ),
      _AllOrdersColumn(
        header: 'Trip Type',
        exportHeader: 'Trip Type',
        width: 100,
        display: shortTripType,
        export: (o) => o.tripType,
      ),
      _AllOrdersColumn(
        header: 'Weight (kg)',
        exportHeader: 'Weight (kg)',
        width: 80,
        alignEnd: true,
        display: (o) => '${o.getTotalWeight()}',
        export: (o) => o.getTotalWeight(),
      ),
      _AllOrdersColumn(
        header: 'Invoice (₹)',
        exportHeader: 'Invoice Amount (₹)',
        width: 90,
        alignEnd: true,
        financial: true,
        headerTooltip: 'Freight / invoice amount',
        display: (o) => '₹${o.getTotalInvoiceAmount()}',
        export: (o) => o.getTotalInvoiceAmount(),
      ),
      _AllOrdersColumn(
        header: 'Toll (₹)',
        exportHeader: 'Toll Charges (₹)',
        width: 80,
        alignEnd: true,
        financial: true,
        headerTooltip: 'Toll charges',
        display: (o) => '₹${o.getTotalTollCharges()}',
        export: (o) => o.getTotalTollCharges(),
      ),
      _AllOrdersColumn(
        header: 'Other (₹)',
        exportHeader: 'Other Charges (₹)',
        width: 80,
        alignEnd: true,
        financial: true,
        headerTooltip: 'Other charges',
        // Hover shows what the other charge was for, when one was entered.
        cellTooltip: otherChargesNote,
        display: (o) => '₹${o.getTotalOtherCharges()}',
        export: (o) => o.getTotalOtherCharges(),
      ),
      _AllOrdersColumn(
        header: '',
        exportHeader: 'Other Charges Description',
        width: 0,
        financial: true,
        exportOnly: true,
        display: (o) => '',
        export: otherChargesNote,
      ),
      _AllOrdersColumn(
        header: 'Total (₹)',
        exportHeader: 'Total Cost (₹)',
        width: 90,
        alignEnd: true,
        financial: true,
        emphasize: true,
        headerTooltip: 'Invoice + Toll + Other charges',
        display: (o) => '₹${totalCost(o)}',
        export: totalCost,
      ),
      // Wording matches the status chip on the order card.
      _AllOrdersColumn(
        header: 'Status',
        exportHeader: 'Status',
        width: 100,
        display: (o) => OrderCardInfo.statusDisplay(o, _workflowService),
        export: (o) => OrderCardInfo.statusDisplay(o, _workflowService),
      ),
      // ---- Everything else the order card shows, so the dashboard and the
      // export carry the same information as the card. ----
      _AllOrdersColumn(
        header: 'Amended',
        exportHeader: 'Amended',
        width: 75,
        display: (o) => o.isAmended ? 'Yes' : 'No',
        export: (o) => o.isAmended ? 'Yes' : 'No',
      ),
      _AllOrdersColumn(
        header: 'Member',
        exportHeader: 'Member',
        width: 130,
        display: (o) => o.creatorName ?? 'N/A',
        export: (o) => o.creatorName ?? 'N/A',
      ),
      _AllOrdersColumn(
        header: 'Department',
        exportHeader: 'Department',
        width: 150,
        display: (o) => o.creatorDepartment ?? 'N/A',
        export: (o) => o.creatorDepartment ?? 'N/A',
      ),
      _AllOrdersColumn(
        header: 'Vehicle Type',
        exportHeader: 'Vehicle Type',
        width: 110,
        display: (o) => OrderCardInfo.vehicleType(vehicleOf(o)),
        export: (o) => OrderCardInfo.vehicleType(vehicleOf(o)),
      ),
      _AllOrdersColumn(
        header: 'Utilization',
        exportHeader: 'Utilization %',
        width: 90,
        alignEnd: true,
        headerTooltip: 'Load as a share of the vehicle capacity',
        display: (o) => utilizationOf(o),
        export: (o) => utilizationOf(o),
      ),
      _AllOrdersColumn(
        header: 'Route',
        exportHeader: 'Route',
        width: 230,
        display: OrderCardInfo.routeSummary,
        export: OrderCardInfo.routeSummary,
      ),
      _AllOrdersColumn(
        header: 'Current Stage',
        exportHeader: 'Current Stage',
        width: 160,
        display: OrderCardInfo.currentStage,
        export: OrderCardInfo.currentStage,
      ),
      _AllOrdersColumn(
        header: 'Flow Status',
        exportHeader: 'Flow Status',
        width: 110,
        display: (o) => OrderCardInfo.flowStatus(o, _workflowService),
        export: (o) => OrderCardInfo.flowStatus(o, _workflowService),
      ),
      _AllOrdersColumn(
        header: 'Approval Status',
        exportHeader: 'Approval Status',
        width: 180,
        display: OrderCardInfo.approvalStatus,
        export: OrderCardInfo.approvalStatus,
      ),
      _AllOrdersColumn(
        header: 'Original Wt (kg)',
        exportHeader: 'Original Weight (kg)',
        width: 110,
        alignEnd: true,
        headerTooltip: 'Weight before amendment (only when it changed)',
        display: (o) => originalWeightOf(o) ?? '-',
        export: (o) => originalWeightOf(o) ?? '',
      ),
      _AllOrdersColumn(
        header: 'Creator ID',
        exportHeader: 'Creator ID',
        width: 80,
        display: (o) => o.creatorUserId ?? '',
        export: (o) => o.creatorUserId ?? '',
      ),
      _AllOrdersColumn(
        header: 'Created At',
        exportHeader: 'Created At',
        width: 130,
        display: OrderCardInfo.createdLabel,
        export: OrderCardInfo.createdLabel,
      ),
      _AllOrdersColumn(
        header: 'Order Category',
        exportHeader: 'Order Category',
        width: 140,
        display: (o) => o.orderCategory,
        export: (o) => o.orderCategory,
      ),
    ].where((c) => showFinancials || !c.financial).toList();
    final displayColumns = columns.where((c) => !c.exportOnly).toList();

    if (orders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Orders',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder, width: 0.5),
            ),
            child: const Text(
              'No orders found in the selected date range.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All Orders (${orders.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final rows = <List<dynamic>>[
                  columns.map((c) => c.exportHeader).toList(),
                  ...orders.map((o) => columns.map((c) => c.export(o)).toList()),
                ];
                ExportUtils.downloadCsv('all_orders_${_dateRangeFileSuffix()}.csv', rows);
              },
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Export', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Header and rows are generated from the same column list as the CSV
        // export above, so every exported column (money columns included)
        // is also visible here. Source/Destination absorb spare width on wide
        // screens (capped, so columns don't drift far apart); on narrow
        // screens the table scrolls horizontally, with a scrollbar that stays
        // visible so the columns off to the right are discoverable.
        LayoutBuilder(
          builder: (context, constraints) {
            const columnGap = 8.0;
            const rowHorizontalPadding = 24.0; // 12px each side; matches header/row padding below
            const maxFlexGrowth = 160.0;

            final minTableWidth = displayColumns.fold<double>(0, (sum, c) => sum + c.width) +
                columnGap * (displayColumns.length - 1) +
                rowHorizontalPadding;
            final flexCount = displayColumns.where((c) => c.flexible).length;
            final available =
                constraints.maxWidth.isFinite ? constraints.maxWidth : minTableWidth;
            final spare = available - minTableWidth;
            var growth = (flexCount == 0 || spare <= 0) ? 0.0 : spare / flexCount;
            if (growth > maxFlexGrowth) growth = maxFlexGrowth;
            final tableWidth = minTableWidth + growth * flexCount;
            final contentWidth = available > tableWidth ? available : tableWidth;
            final needsHorizontalScroll = tableWidth > available;

            double widthOf(_AllOrdersColumn c) => c.flexible ? c.width + growth : c.width;

            List<Widget> withGaps(List<Widget> cells) {
              final out = <Widget>[];
              for (var i = 0; i < cells.length; i++) {
                if (i > 0) out.add(const SizedBox(width: columnGap));
                out.add(cells[i]);
              }
              return out;
            }

            Widget headerCell(_AllOrdersColumn c) {
              Widget label = Text(
                c.header,
                textAlign: c.alignEnd ? TextAlign.right : TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
              );
              if (c.headerTooltip != null) {
                label = Tooltip(message: c.headerTooltip!, child: label);
              }
              return SizedBox(width: widthOf(c), child: label);
            }

            Widget dataCell(_AllOrdersColumn c, OrderModel o) {
              Widget value = Text(
                c.display(o),
                textAlign: c.alignEnd ? TextAlign.right : TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.emphasize ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: c.emphasize ? FontWeight.w600 : FontWeight.normal,
                ),
              );
              final tip = c.cellTooltip?.call(o);
              if (tip != null && tip.isNotEmpty) {
                value = Tooltip(message: tip, child: value);
              }
              return SizedBox(width: widthOf(c), child: value);
            }

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.darkBorder, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Scrollbar(
                controller: _allOrdersHScroll,
                thumbVisibility: needsHorizontalScroll,
                child: SingleChildScrollView(
                  controller: _allOrdersHScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                          child: Row(
                            children: withGaps(displayColumns.map(headerCell).toList()),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: orders.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: AppTheme.darkBorder),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: withGaps(
                                    displayColumns.map((c) => dataCell(c, order)).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Room for the horizontal scrollbar so it doesn't
                        // sit on top of the last visible row.
                        if (needsHorizontalScroll) const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUtilizationAnalysisTable(BuildContext context, List<OrderModel> orders) {
    // Calculate utilization for each order
    final utilizationData = <Map<String, dynamic>>[];
    
    for (var order in orders) {
      if (order.vehicleNumber != null && order.vehicleNumber!.isNotEmpty) {
        // Find vehicle capacity
        final vehicle = _vehicles.firstWhere(
          (v) => v.vehicleNumber == order.vehicleNumber,
          orElse: () => VehicleModel(
            vehicleId: order.vehicleId ?? '',
            vehicleNumber: order.vehicleNumber ?? '',
            type: '',
            capacityKg: 0,
            vehicleType: '',
            vendorVehicle: '',
            isBusy: false,
          ),
        );
        
        if (vehicle.capacityKg > 0) {
          final totalWeight = order.getTotalWeight();
          final utilization = (totalWeight / vehicle.capacityKg) * 100;
          
          // Only include orders with 80-100% utilization
          if (utilization >= 80 && utilization <= 100) {
            utilizationData.add({
              'orderId': order.orderId,
              'date': order.effectiveDate,
              'vehicle': order.vehicleNumber ?? 'N/A',
              'weight': totalWeight,
              'capacity': vehicle.capacityKg,
              'utilization': utilization,
            });
          }
        }
      }
    }

    if (utilizationData.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Truck Utilization Analysis (80-100%)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder, width: 0.5),
            ),
            child: const Text(
              'No orders found with 80-100% truck utilization in the selected date range.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Truck Utilization Analysis (80-100%)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final rows = <List<dynamic>>[
                  ['Order ID', 'Date', 'Vehicle', 'Weight (kg)', 'Capacity (kg)', 'Utilization %'],
                  ...utilizationData.map((d) => [
                        d['orderId'],
                        d['date'] != null ? _formatDate(d['date'] as DateTime) : 'N/A',
                        d['vehicle'],
                        d['weight'],
                        d['capacity'],
                        '${(d['utilization'] as double).toStringAsFixed(1)}%',
                      ]),
                ];
                ExportUtils.downloadCsv('truck_utilization_${_dateRangeFileSuffix()}.csv', rows);
              },
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Export', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Table Container - Proper scrolling structure
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.darkBorder, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Order ID',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Date',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Vehicle',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Weight (kg)',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Capacity (kg)',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Utilization %',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows - Scrollable
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: utilizationData.length,
                  itemBuilder: (context, index) {
                    final data = utilizationData[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.darkBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              data['orderId'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              data['date'] != null ? _formatDate(data['date'] as DateTime) : 'N/A',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              data['vehicle'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${data['weight']}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${data['capacity']}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${(data['utilization'] as double).toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialBreakdownTable(BuildContext context, List<OrderModel> orders) {
    // Group by trip type
    final Map<String, List<OrderModel>> ordersByType = {};
    for (var order in orders) {
      final type = order.tripType;
      if (!ordersByType.containsKey(type)) {
        ordersByType[type] = [];
      }
      ordersByType[type]!.add(order);
    }

    if (ordersByType.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Breakdown by Trip Type',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.darkBorder, width: 0.5),
            ),
            child: const Text(
              'No financial data available for the selected date range.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    // Pre-compute rows for both display and export
    final financialRows = ordersByType.entries.map((entry) {
      final type = entry.key;
      final typeOrders = entry.value;
      final totalCost = typeOrders.fold<int>(
        0,
        (sum, order) => sum + order.getTotalInvoiceAmount() + order.getTotalTollCharges() + order.getTotalOtherCharges(),
      );
      final totalWeight = typeOrders.fold<int>(
        0,
        (sum, order) => sum + order.getTotalWeight(),
      );
      final avgCostPerOrder = typeOrders.isNotEmpty ? totalCost / typeOrders.length : 0.0;
      final avgCostPerKg = totalWeight > 0 ? totalCost / totalWeight : 0.0;
      return {
        'type': type,
        'orders': typeOrders.length,
        'totalCost': totalCost,
        'avgCostPerOrder': avgCostPerOrder,
        'avgCostPerKg': avgCostPerKg,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Financial Breakdown by Trip Type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final rows = <List<dynamic>>[
                  ['Trip Type', 'Orders', 'Total Cost (₹)', 'Avg/Order (₹)', 'Avg/kg (₹)'],
                  ...financialRows.map((r) => [
                        (r['type'] as String).replaceAll('-Trip-Vendor', '').replaceAll('-', ' '),
                        r['orders'],
                        r['totalCost'],
                        (r['avgCostPerOrder'] as double).toStringAsFixed(0),
                        (r['avgCostPerKg'] as double).toStringAsFixed(2),
                      ]),
                ];
                ExportUtils.downloadCsv('financial_breakdown_${_dateRangeFileSuffix()}.csv', rows);
              },
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Export', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Table Container - Proper scrolling structure
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.darkBorder, width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Trip Type',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Orders',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Total Cost',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Avg/Order',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Avg/kg',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows - Scrollable
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: financialRows.length,
                  itemBuilder: (context, index) {
                    final row = financialRows[index];
                    final type = row['type'] as String;
                    final orderCount = row['orders'] as int;
                    final totalCost = row['totalCost'] as int;
                    final avgCostPerOrder = row['avgCostPerOrder'] as double;
                    final avgCostPerKg = row['avgCostPerKg'] as double;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.darkBorder,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              type.replaceAll('-Trip-Vendor', '').replaceAll('-', ' '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '$orderCount',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹$totalCost',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${avgCostPerOrder.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${avgCostPerKg.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalInsights(BuildContext context, List<OrderModel> orders) {
    // Calculate frequently used routes
    final routeCounts = <String, int>{};
    for (var order in orders) {
      if (order.tripSegments.isNotEmpty) {
        final firstSegment = order.tripSegments.first;
        final lastSegment = order.tripSegments.last;
        final route = '${firstSegment.source} → ${lastSegment.destination}';
        routeCounts[route] = (routeCounts[route] ?? 0) + 1;
      }
    }
    final sortedRoutes = routeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRoutes = sortedRoutes.take(3).toList();

    // Calculate cost saving suggestions
    final lowUtilizationOrders = <Map<String, dynamic>>[];
    for (var order in orders) {
      if (order.vehicleNumber != null && order.vehicleNumber!.isNotEmpty) {
        final vehicle = _vehicles.firstWhere(
          (v) => v.vehicleNumber == order.vehicleNumber,
          orElse: () => VehicleModel(
            vehicleId: order.vehicleId ?? '',
            vehicleNumber: order.vehicleNumber ?? '',
            type: '',
            capacityKg: 0,
            vehicleType: '',
            vendorVehicle: '',
            isBusy: false,
          ),
        );
        if (vehicle.capacityKg > 0) {
          final weightUsed = order.getTotalWeight();
          final utilization = (weightUsed / vehicle.capacityKg) * 100;
          if (utilization < 80) {
            final firstSeg = order.tripSegments.isNotEmpty ? order.tripSegments.first : null;
            final lastSeg = order.tripSegments.isNotEmpty ? order.tripSegments.last : null;
            lowUtilizationOrders.add({
              'orderId': order.orderId,
              'date': order.effectiveDate,
              'vehicleNumber': order.vehicleNumber ?? 'N/A',
              'capacityKg': vehicle.capacityKg,
              'weightUsed': weightUsed,
              'from': firstSeg?.source ?? order.source,
              'to': lastSeg?.destination ?? order.destination,
              'utilization': utilization,
            });
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Insights',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
        ),
        const SizedBox(height: 12),
        // Frequently Used Routes
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
          ),
          color: AppTheme.darkSurface,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: AppTheme.primaryOrange),
                    const SizedBox(width: 8),
                    Text(
                      'Frequently Used Routes',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (topRoutes.isEmpty)
                  const Text(
                    'No route data available.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  ...topRoutes.map((route) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '• ${route.key}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${route.value}x',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Cost Saving Suggestions
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.darkBorder, width: 0.5),
          ),
          color: AppTheme.darkSurface,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cost Saving Suggestions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (lowUtilizationOrders.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          final rows = <List<dynamic>>[
                            ['Order ID', 'Date', 'Truck Number', 'Capacity (kg)', 'Weight Used (kg)', 'From', 'To', 'Utilization %'],
                            ...lowUtilizationOrders.map((d) => [
                                  d['orderId'],
                                  d['date'] != null ? _formatDate(d['date'] as DateTime) : 'N/A',
                                  d['vehicleNumber'],
                                  d['capacityKg'],
                                  d['weightUsed'],
                                  d['from'],
                                  d['to'],
                                  '${(d['utilization'] as double).toStringAsFixed(1)}%',
                                ]),
                          ];
                          ExportUtils.downloadCsv('low_utilization_${_dateRangeFileSuffix()}.csv', rows);
                        },
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Export', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (lowUtilizationOrders.isEmpty)
                  const Text(
                    'All orders show optimal truck utilization (≥80%).',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lowUtilizationOrders.length} order(s) with <80% utilization detected.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Consider consolidating smaller orders or using smaller vehicles to improve efficiency and reduce costs.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Table header
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.darkBorder, width: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.08),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 2, child: Text('Truck No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 2, child: Text('Capacity (kg)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 2, child: Text('Used (kg)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 3, child: Text('From', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 3, child: Text('To', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                  Expanded(flex: 2, child: Text('Util %', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary))),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.25,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: lowUtilizationOrders.length,
                                itemBuilder: (context, idx) {
                                  final d = lowUtilizationOrders[idx];
                                  final util = (d['utilization'] as double).toStringAsFixed(1);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: AppTheme.darkBorder, width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(d['orderId'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text(d['date'] != null ? _formatDate(d['date'] as DateTime) : 'N/A', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text(d['vehicleNumber'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 2, child: Text('${d['capacityKg']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                                        Expanded(flex: 2, child: Text('${d['weightUsed']}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary))),
                                        Expanded(flex: 3, child: Text(d['from'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 3, child: Text(d['to'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '$util%',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One column of the Home dashboard's "All Orders" table. The on-screen table
/// and its CSV export are both generated from a list of these, which is what
/// keeps the two in step.
class _AllOrdersColumn {
  const _AllOrdersColumn({
    required this.header,
    required this.exportHeader,
    required this.width,
    required this.display,
    required this.export,
    this.flexible = false,
    this.alignEnd = false,
    this.emphasize = false,
    this.financial = false,
    this.exportOnly = false,
    this.headerTooltip,
    this.cellTooltip,
  });

  /// Header text on screen.
  final String header;

  /// Header text in the exported CSV.
  final String exportHeader;

  /// Minimum on-screen width in logical pixels.
  final double width;

  /// Whether this column may grow with spare width on wide screens.
  final bool flexible;
  final bool alignEnd;
  final bool emphasize;

  /// Money column: only shown/exported to users allowed to view order
  /// financials (see OrderEditEligibility.canViewOrderFinancials).
  final bool financial;

  /// Present in the CSV export but not as a column on screen.
  final bool exportOnly;

  final String? headerTooltip;
  final String Function(OrderModel order) display;
  final dynamic Function(OrderModel order) export;
  final String? Function(OrderModel order)? cellTooltip;
}
