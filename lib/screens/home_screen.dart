import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  List<VehicleModel> _vehicles = [];
  bool _isLoadingVehicles = false;

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
      default:
        return DateTime(2020, 1, 1); // All time
    }
  }

  DateTime _getDateRangeEnd() {
    final now = DateTime.now();
    switch (_selectedDateRange) {
      case 'Previous Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return startOfWeek.subtract(const Duration(days: 1));
      default:
        return now;
    }
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    final startDate = _getDateRangeStart();
    final endDate = _getDateRangeEnd();
    return orders.where((order) {
      if (order.createdAt == null) return false;
      return order.createdAt!.isAfter(startDate.subtract(const Duration(days: 1))) &&
             order.createdAt!.isBefore(endDate.add(const Duration(days: 1)));
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
                                                items: ['Current Week', 'Previous Week', 'Last 15 Days', 'Month to Date']
                                                    .map((range) => DropdownMenuItem(
                                                          value: range,
                                                          child: Text(range),
                                                        ))
                                                    .toList(),
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(() => _selectedDateRange = value);
                                                  }
                                                },
                                              ),
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
                                    const SizedBox(height: 12),
                                    // Revenue Analysis
                                    _buildRevenueCard(context, metrics),
                                    const SizedBox(height: 16),
                                    // Operational Analysis Section
                                    _buildOperationalAnalysisSection(context, filteredOrders),
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
    final total = totalInvoice + totalToll;
    
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

  Widget _buildOperationalAnalysisSection(BuildContext context, List<OrderModel> filteredOrders) {
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
            // Utilization Analysis Table
            _buildUtilizationAnalysisTable(context, filteredOrders),
            const SizedBox(height: 16),
            // Financial Breakdown Table
            _buildFinancialBreakdownTable(context, filteredOrders),
            const SizedBox(height: 16),
            // Operational Insights
            _buildOperationalInsights(context, filteredOrders),
          ],
        ),
      ),
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
        Text(
          'Truck Utilization Analysis (80-100%)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
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
                  itemCount: ordersByType.length,
                  itemBuilder: (context, index) {
                    final entry = ordersByType.entries.elementAt(index);
                    final type = entry.key;
                    final typeOrders = entry.value;
                    final totalCost = typeOrders.fold<int>(
                      0,
                      (sum, order) => sum + order.getTotalInvoiceAmount() + order.getTotalTollCharges(),
                    );
                    final totalWeight = typeOrders.fold<int>(
                      0,
                      (sum, order) => sum + order.getTotalWeight(),
                    );
                    final avgCostPerOrder = typeOrders.isNotEmpty ? totalCost / typeOrders.length : 0.0;
                    final avgCostPerKg = totalWeight > 0 ? totalCost / totalWeight : 0.0;

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
          final utilization = (order.getTotalWeight() / vehicle.capacityKg) * 100;
          if (utilization < 80) {
            lowUtilizationOrders.add({
              'orderId': order.orderId,
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
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Cost Saving Suggestions',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
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
                      Text(
                        'Consider consolidating smaller orders or using smaller vehicles to improve efficiency and reduce costs.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
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
