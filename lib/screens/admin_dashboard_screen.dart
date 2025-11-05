import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/permission_utils.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/vendor_model.dart';
import '../models/vehicle_model.dart';

/// Admin Dashboard Screen
/// 
/// This screen provides administrative functionality for managing:
/// - Users (Create, Edit, Delete, Reset Password) - Admin only
/// - Vendors (Create, Edit, Delete) - Admin or Accounts Team
/// - Vehicles (Create, Edit, Delete) - Admin or Accounts Team
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();

  // Users state
  List<UserModel> _users = [];
  bool _usersLoading = false;
  String? _usersError;

  // Vendors state
  List<VendorModel> _vendors = [];
  bool _vendorsLoading = false;
  String? _vendorsError;

  // Vehicles state
  List<VehicleModel> _vehicles = [];
  bool _vehiclesLoading = false;
  String? _vehiclesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
        // Load data when tab changes
        if (_selectedIndex == 0) {
          _loadUsers();
        } else if (_selectedIndex == 1) {
          _loadVendors();
        } else if (_selectedIndex == 2) {
          _loadVehicles();
        }
      });
    });
    // Load initial data
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // DATA LOADING METHODS
  // ============================================

  Future<void> _loadUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });
    try {
      final result = await _apiService.getAdminUsers();
      if (result['success'] == true) {
        setState(() {
          _users = result['users'] as List<UserModel>;
          _usersLoading = false;
        });
      } else {
        setState(() {
          _usersError = result['message'] ?? 'Failed to load users';
          _usersLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _usersError = 'Error loading users: ${e.toString()}';
        _usersLoading = false;
      });
    }
  }

  Future<void> _loadVendors() async {
    setState(() {
      _vendorsLoading = true;
      _vendorsError = null;
    });
    try {
      final result = await _apiService.getAdminVendors();
      if (result['success'] == true) {
        setState(() {
          _vendors = result['vendors'] as List<VendorModel>;
          _vendorsLoading = false;
        });
      } else {
        setState(() {
          _vendorsError = result['message'] ?? 'Failed to load vendors';
          _vendorsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _vendorsError = 'Error loading vendors: ${e.toString()}';
        _vendorsLoading = false;
      });
    }
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _vehiclesLoading = true;
      _vehiclesError = null;
    });
    try {
      final result = await _apiService.getAdminVehicles();
      if (result['success'] == true) {
        setState(() {
          _vehicles = result['vehicles'] as List<VehicleModel>;
          _vehiclesLoading = false;
        });
      } else {
        setState(() {
          _vehiclesError = result['message'] ?? 'Failed to load vehicles';
          _vehiclesLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _vehiclesError = 'Error loading vehicles: ${e.toString()}';
        _vehiclesLoading = false;
      });
    }
  }

  // ============================================
  // USERS CRUD METHODS
  // ============================================

  Future<void> _createUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserFormDialog(),
    );
    if (result != null && result['action'] == 'create') {
      final createResult = await _apiService.createAdminUser(
        fullName: result['fullName'],
        password: result['password'],
        department: result['department'],
      );
      if (createResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully')),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult['message'] ?? 'Failed to create user')),
        );
      }
    }
  }

  Future<void> _editUser(UserModel user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserFormDialog(user: user),
    );
    if (result != null && result['action'] == 'update') {
      final updateResult = await _apiService.updateAdminUser(
        userId: user.userId,
        fullName: result['fullName'],
        password: result['password'],
        department: result['department'],
      );
      if (updateResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updateResult['message'] ?? 'Failed to update user')),
        );
      }
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final deleteResult = await _apiService.deleteAdminUser(user.userId);
      if (deleteResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
        _loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleteResult['message'] ?? 'Failed to delete user')),
        );
      }
    }
  }

  // ============================================
  // VENDORS CRUD METHODS
  // ============================================

  Future<void> _createVendor() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VendorFormDialog(),
    );
    if (result != null && result['action'] == 'create') {
      final createResult = await _apiService.createAdminVendor(result);
      if (createResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor created successfully')),
        );
        _loadVendors();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult['message'] ?? 'Failed to create vendor')),
        );
      }
    }
  }

  Future<void> _editVendor(VendorModel vendor) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VendorFormDialog(vendor: vendor),
    );
    if (result != null && result['action'] == 'update') {
      final vendorName = vendor.vendorName ?? vendor.name;
      final updateResult = await _apiService.updateAdminVendor(
        vendorName: vendorName,
        vendorData: result,
      );
      if (updateResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor updated successfully')),
        );
        _loadVendors();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updateResult['message'] ?? 'Failed to update vendor')),
        );
      }
    }
  }

  Future<void> _deleteVendor(VendorModel vendor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete ${vendor.vendorName ?? vendor.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final vendorName = vendor.vendorName ?? vendor.name;
      final deleteResult = await _apiService.deleteAdminVendor(vendorName);
      if (deleteResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor deleted successfully')),
        );
        _loadVendors();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleteResult['message'] ?? 'Failed to delete vendor')),
        );
      }
    }
  }

  // ============================================
  // VEHICLES CRUD METHODS
  // ============================================

  Future<void> _createVehicle() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VehicleFormDialog(),
    );
    if (result != null && result['action'] == 'create') {
      final createResult = await _apiService.createAdminVehicle(result);
      if (createResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle created successfully')),
        );
        _loadVehicles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(createResult['message'] ?? 'Failed to create vehicle')),
        );
      }
    }
  }

  Future<void> _editVehicle(VehicleModel vehicle) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _VehicleFormDialog(vehicle: vehicle),
    );
    if (result != null && result['action'] == 'update') {
      final updateResult = await _apiService.updateAdminVehicle(
        vehicleId: vehicle.vehicleId,
        vehicleData: result,
      );
      if (updateResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated successfully')),
        );
        _loadVehicles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updateResult['message'] ?? 'Failed to update vehicle')),
        );
      }
    }
  }

  Future<void> _deleteVehicle(VehicleModel vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to delete ${vehicle.vehicleNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final deleteResult = await _apiService.deleteAdminVehicle(vehicle.vehicleId);
      if (deleteResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully')),
        );
        _loadVehicles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(deleteResult['message'] ?? 'Failed to delete vehicle')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final userDepartment = user?.department ?? '';
        final userRole = user?.role ?? '';

        // Check permissions for each feature
        final canManageUsersFlag = canManageUsers(userDepartment, userRole);
        final canManageVendorsFlag = canManageVendors(userDepartment, userRole);
        final canManageVehiclesFlag = canManageVehicles(userDepartment, userRole);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Soliflex Packaging - Admin Dashboard'),
            backgroundColor: AppTheme.darkSurface,
            foregroundColor: AppTheme.textPrimary,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryOrange,
              labelColor: AppTheme.primaryOrange,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Manage Users',
                ),
                Tab(
                  icon: Icon(Icons.store),
                  text: 'Manage Vendors',
                ),
                Tab(
                  icon: Icon(Icons.local_shipping),
                  text: 'Manage Vehicles',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Manage Users Tab
              _buildManageUsersTab(canManageUsersFlag, userDepartment, userRole),
              // Manage Vendors Tab
              _buildManageVendorsTab(canManageVendorsFlag, userDepartment, userRole),
              // Manage Vehicles Tab
              _buildManageVehiclesTab(canManageVehiclesFlag, userDepartment, userRole),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // TAB BUILDERS
  // ============================================

  Widget _buildManageUsersTab(bool hasPermission, String userDepartment, String userRole) {
    if (!hasPermission) {
      return _buildAccessDeniedWidget(
        'You do not have permission to manage users.',
        'Required: Admin Department or SUPER_USER role',
      );
    }

    return Column(
      children: [
        // Header with Create Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Users (${_users.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createUser,
                icon: const Icon(Icons.person_add),
                label: const Text('Create User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.white,
                ),
              ),
            ],
          ),
        ),
        // Users List
        Expanded(
          child: _usersLoading
              ? const Center(child: CircularProgressIndicator())
              : _usersError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 16),
                          Text(_usersError!, style: const TextStyle(color: AppTheme.errorRed)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadUsers,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No users found',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createUser,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Create First User'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUsers,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                color: AppTheme.darkCard,
                                child: ListTile(
                                  title: Text(
                                    user.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Department: ${user.department}'),
                                      Text('Role: ${user.role}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                                        onPressed: () => _editUser(user),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteUser(user),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildManageVendorsTab(bool hasPermission, String userDepartment, String userRole) {
    if (!hasPermission) {
      return _buildAccessDeniedWidget(
        'You do not have permission to manage vendors.',
        'Required: Admin Department, Accounts Team, or SUPER_USER/APPROVAL_MANAGER role',
      );
    }

    return Column(
      children: [
        // Header with Create Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vendors (${_vendors.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createVendor,
                icon: const Icon(Icons.add_business),
                label: const Text('Create Vendor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.white,
                ),
              ),
            ],
          ),
        ),
        // Vendors List
        Expanded(
          child: _vendorsLoading
              ? const Center(child: CircularProgressIndicator())
              : _vendorsError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 16),
                          Text(_vendorsError!, style: const TextStyle(color: AppTheme.errorRed)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadVendors,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _vendors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_outlined, size: 64, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No vendors found',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createVendor,
                                icon: const Icon(Icons.add_business),
                                label: const Text('Create First Vendor'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadVendors,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _vendors.length,
                            itemBuilder: (context, index) {
                              final vendor = _vendors[index];
                              final vendorName = vendor.vendorName ?? vendor.name;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                color: AppTheme.darkCard,
                                child: ListTile(
                                  title: Text(
                                    vendorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text('ID: ${vendor.vendorId}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                                        onPressed: () => _editVendor(vendor),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteVendor(vendor),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildManageVehiclesTab(bool hasPermission, String userDepartment, String userRole) {
    if (!hasPermission) {
      return _buildAccessDeniedWidget(
        'You do not have permission to manage vehicles.',
        'Required: Admin Department, Accounts Team, or SUPER_USER/APPROVAL_MANAGER role',
      );
    }

    return Column(
      children: [
        // Header with Create Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicles (${_vehicles.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createVehicle,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Vehicle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.white,
                ),
              ),
            ],
          ),
        ),
        // Vehicles List
        Expanded(
          child: _vehiclesLoading
              ? const Center(child: CircularProgressIndicator())
              : _vehiclesError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 16),
                          Text(_vehiclesError!, style: const TextStyle(color: AppTheme.errorRed)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadVehicles,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _vehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 64, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No vehicles found',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _createVehicle,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Create First Vehicle'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadVehicles,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _vehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = _vehicles[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                color: AppTheme.darkCard,
                                child: ListTile(
                                  title: Text(
                                    vehicle.vehicleNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Type: ${vehicle.type}'),
                                      Text('Capacity: ${vehicle.capacityKg} kg'),
                                      Text('Status: ${vehicle.isBusy ? 'Booked' : 'Free'}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                                        onPressed: () => _editVehicle(vehicle),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteVehicle(vehicle),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildAccessDeniedWidget(String message, String requirement) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          const Text(
            'Access Denied',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            requirement,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================
// FORM DIALOGS
// ============================================

class _UserFormDialog extends StatefulWidget {
  final UserModel? user;

  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isPasswordVisible = false;
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _fullNameController.text = widget.user!.fullName;
      _departmentController.text = widget.user!.department;
    }
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final apiService = ApiService();
    final result = await apiService.getDepartments();
    if (result['success'] == true) {
      setState(() {
        _departments = result['departments'] as List<String>;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? 'Create User' : 'Edit User'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: widget.user == null ? 'Password *' : 'New Password (leave blank to keep current)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (widget.user == null && (value == null || value.isEmpty)) {
                      return 'Please enter password';
                    }
                    if (value != null && value.isNotEmpty) {
                      final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
                      if (!passwordRegex.hasMatch(value)) {
                        return 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 symbol';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _departmentController.text.isEmpty ? null : _departmentController.text,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(dept),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _departmentController.text = value;
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select department';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'action': widget.user == null ? 'create' : 'update',
                'fullName': _fullNameController.text,
                'password': _passwordController.text.isEmpty ? null : _passwordController.text,
                'department': _departmentController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: AppTheme.white,
          ),
          child: Text(widget.user == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

class _VendorFormDialog extends StatefulWidget {
  final VendorModel? vendor;

  const _VendorFormDialog({this.vendor});

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vendorNameController = TextEditingController();
  final _klController = TextEditingController();
  final _pickBelow3000Controller = TextEditingController();
  final _dropBelow3000Controller = TextEditingController();
  final _pick3000To5999Controller = TextEditingController();
  final _drop5999Controller = TextEditingController();
  final _pickAbove6000Controller = TextEditingController();
  final _dropAbove6000Controller = TextEditingController();
  final _tollChargesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.vendor != null) {
      _vendorNameController.text = widget.vendor!.vendorName ?? widget.vendor!.name;
      _klController.text = widget.vendor!.kl ?? '';
      _pickBelow3000Controller.text = widget.vendor!.pickUpBySolBelow3000Kgs ?? '';
      _dropBelow3000Controller.text = widget.vendor!.droppedByVendorBelow3000Kgs ?? '';
      _pick3000To5999Controller.text = widget.vendor!.pickUpBySolBetween3000To5999Kgs ?? '';
      _drop5999Controller.text = widget.vendor!.droppedByVendorBelow5999Kgs ?? '';
      _pickAbove6000Controller.text = widget.vendor!.pickUpBySolAbove6000Kgs ?? '';
      _dropAbove6000Controller.text = widget.vendor!.droppedByVendorAbove6000Kgs ?? '';
      _tollChargesController.text = widget.vendor!.tollCharges ?? '';
    }
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _klController.dispose();
    _pickBelow3000Controller.dispose();
    _dropBelow3000Controller.dispose();
    _pick3000To5999Controller.dispose();
    _drop5999Controller.dispose();
    _pickAbove6000Controller.dispose();
    _dropAbove6000Controller.dispose();
    _tollChargesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vendor == null ? 'Create Vendor' : 'Edit Vendor'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _vendorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vendor name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _klController,
                  decoration: const InputDecoration(
                    labelText: 'KL',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Text('Pick Up Rates (by Soliflex)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pickBelow3000Controller,
                        decoration: const InputDecoration(
                          labelText: 'Below 3000 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _pick3000To5999Controller,
                        decoration: const InputDecoration(
                          labelText: '3000-5999 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _pickAbove6000Controller,
                        decoration: const InputDecoration(
                          labelText: 'Above 6000 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Drop Rates (by Vendor)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dropBelow3000Controller,
                        decoration: const InputDecoration(
                          labelText: 'Below 3000 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _drop5999Controller,
                        decoration: const InputDecoration(
                          labelText: 'Below 5999 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _dropAbove6000Controller,
                        decoration: const InputDecoration(
                          labelText: 'Above 6000 kg',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tollChargesController,
                  decoration: const InputDecoration(
                    labelText: 'Toll Charges',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'action': widget.vendor == null ? 'create' : 'update',
                'vendor_name': _vendorNameController.text,
                'kl': _klController.text,
                'pick_up_by_sol_below_3000_kgs': _pickBelow3000Controller.text,
                'dropped_by_vendor_below_3000_kgs': _dropBelow3000Controller.text,
                'pick_up_by_sol_between_3000_to_5999_kgs': _pick3000To5999Controller.text,
                'dropped_by_vendor_below_5999_kgs': _drop5999Controller.text,
                'pick_up_by_sol_above_6000_kgs': _pickAbove6000Controller.text,
                'dropped_by_vendor_above_6000_kgs': _dropAbove6000Controller.text,
                'toll_charges': _tollChargesController.text,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: AppTheme.white,
          ),
          child: Text(widget.vendor == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

class _VehicleFormDialog extends StatefulWidget {
  final VehicleModel? vehicle;

  const _VehicleFormDialog({this.vehicle});

  @override
  State<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  String _selectedType = 'Open';
  String _selectedVehicleType = '19ft';
  String _selectedVendorVehicle = 'company_vehicle';
  String _selectedStatus = 'Free';

  final List<String> _types = ['Open', 'Closed', 'Container'];
  final List<String> _vehicleTypes = ['9ft', '17ft', '19ft', '22ft'];
  final List<String> _vendorVehicles = ['company_vehicle', 'rented_vehicle'];
  final List<String> _statuses = ['Free', 'Booked'];

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _vehicleNumberController.text = widget.vehicle!.vehicleNumber;
      _capacityController.text = widget.vehicle!.capacityKg.toString();
      _selectedType = widget.vehicle!.type;
      _selectedVehicleType = widget.vehicle!.vehicleType;
      _selectedVendorVehicle = widget.vehicle!.vendorVehicle;
      _selectedStatus = widget.vehicle!.isBusy ? 'Booked' : 'Free';
    }
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Create Vehicle' : 'Edit Vehicle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (kg) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter capacity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _vehicleTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVehicleType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedVendorVehicle,
                  decoration: const InputDecoration(
                    labelText: 'Vendor/Vehicle',
                    border: OutlineInputBorder(),
                  ),
                  items: _vendorVehicles.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('_', ' ')),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVendorVehicle = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: _statuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'action': widget.vehicle == null ? 'create' : 'update',
                'vehicle_number': _vehicleNumberController.text,
                'type': _selectedType,
                'capacity_kg': _capacityController.text,
                'vehicle_type': _selectedVehicleType,
                'vendor_vehicle': _selectedVendorVehicle,
                'status': _selectedStatus,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryOrange,
            foregroundColor: AppTheme.white,
          ),
          child: Text(widget.vehicle == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
