/// Permission utility functions for role-based access control
/// 
/// This file provides centralized access control functions used across
/// the application to determine what UI elements and features users can access
/// based on their role and department.

/// Check if user has Super Admin access (Full Admin privileges)
/// 
/// Super Admin users can:
/// - Create/Edit/Delete Users
/// - Manage Master Data (Vendors, Factories, Trucks)
/// - Cancel orders
/// - Revoke workflow rejections
/// - Access all administrative features
/// 
/// Requirements:
/// - User Role must be 'SUPER_USER', OR
/// - User Department must be 'Admin' (case-insensitive)
bool hasSuperAdminAccess(String userDepartment, String userRole) {
  final normalizedDepartment = userDepartment.trim().toLowerCase();
  final normalizedRole = userRole.trim().toUpperCase();
  
  // Check for SUPER_USER role
  if (normalizedRole == 'SUPER_USER') {
    return true;
  }
  
  // Check for Admin department (case-insensitive, partial match)
  if (normalizedDepartment == 'admin' || 
      normalizedDepartment.contains('admin')) {
    return true;
  }
  
  return false;
}

/// Check if user has Operational access (can create and manage orders)
/// 
/// Operational users can:
/// - Create new orders
/// - Amend existing orders
/// - View orders dashboard
/// - Perform workflow approvals (if department matches stage requirement)
/// 
/// Requirements:
/// - All users except guests have operational access
/// - This is the default access level for authenticated users
bool hasOperationalAccess(String userDepartment, String userRole) {
  // All authenticated users have operational access
  // This excludes only unauthenticated/guest users
  if (userDepartment.isEmpty && userRole.isEmpty) {
    return false;
  }
  
  return true;
}

/// Check if user has Account Team privileges
/// 
/// Account Team users can:
/// - Approve/Reject workflow stages (privileged override)
/// - Cancel orders
/// - Revoke workflow rejections
/// - Access approval dashboards
/// 
/// Requirements:
/// - User Department must be 'Accounts Team' (case-insensitive)
/// - User Role must be 'APPROVAL_MANAGER', OR
/// - Department contains 'accounts' or 'account'
bool hasAccountTeamAccess(String userDepartment, String userRole) {
  final normalizedDepartment = userDepartment.trim().toLowerCase();
  final normalizedRole = userRole.trim().toUpperCase();
  
  // Check for APPROVAL_MANAGER role
  if (normalizedRole == 'APPROVAL_MANAGER') {
    return true;
  }
  
  // Check for Accounts Team department (case-insensitive, partial match)
  if (normalizedDepartment == 'accounts team' ||
      normalizedDepartment.contains('accounts') ||
      normalizedDepartment.contains('account')) {
    return true;
  }
  
  return false;
}

/// Check if user has privileged workflow access (Admin or Account Team)
/// 
/// Privileged users can approve/reject any workflow stage regardless of
/// department-specific restrictions.
/// 
/// This is used in the workflow approval system to grant overriding authority.
bool hasPrivilegedWorkflowAccess(String userDepartment, String userRole) {
  return hasSuperAdminAccess(userDepartment, userRole) || 
         hasAccountTeamAccess(userDepartment, userRole);
}

/// Check if user belongs to Admin department
/// 
/// Used for granular permission checks for Manage Users feature.
/// Admin department users can create, edit, delete, and reset user passwords.
bool isAdminDept(String userDepartment) {
  final normalized = userDepartment.trim().toLowerCase();
  return normalized == 'admin' || normalized.contains('admin');
}

/// Check if user can manage Vendors and Vehicles
/// 
/// Returns true if user is Admin OR Accounts Team.
/// Accounts Team has been granted permission to manage Vendors and Vehicles
/// as per business requirements.
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

/// Check if user can manage Users (Create, Edit, Delete, Reset Password)
/// 
/// Requirements:
/// - User Department must be 'Admin' (case-insensitive)
/// - User Role must be 'SUPER_USER'
bool canManageUsers(String userDepartment, String userRole) {
  return isAdminDept(userDepartment) || 
         userRole.trim().toUpperCase() == 'SUPER_USER';
}

/// Check if user can manage Vendors (Create, Edit, Delete)
/// 
/// Requirements:
/// - User Department must be 'Admin' OR 'Accounts Team' (case-insensitive)
/// - User Role must be 'SUPER_USER' OR 'APPROVAL_MANAGER'
bool canManageVendors(String userDepartment, String userRole) {
  return isVendorVehicleManager(userDepartment, userRole);
}

/// Check if user can manage Vehicles (Create, Edit, Delete)
/// 
/// Requirements:
/// - User Department must be 'Admin' OR 'Accounts Team' (case-insensitive)
/// - User Role must be 'SUPER_USER' OR 'APPROVAL_MANAGER'
bool canManageVehicles(String userDepartment, String userRole) {
  return isVendorVehicleManager(userDepartment, userRole);
}

