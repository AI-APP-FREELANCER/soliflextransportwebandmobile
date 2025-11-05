const express = require('express');
const router = express.Router();
const csvService = require('../services/csvDatabaseService');
const argon2 = require('argon2');

// ============================================
// USERS CRUD OPERATIONS
// ============================================

// GET /api/admin/users - Get all users
router.get('/admin/users', async (req, res) => {
  try {
    const users = await csvService.readUsers();
    // Remove password hash from response
    const sanitizedUsers = users.map(user => ({
      userId: user.userId,
      fullName: user.fullName,
      department: user.department,
      role: user.role
    }));
    res.json({
      success: true,
      users: sanitizedUsers
    });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/admin/users - Create new user
router.post('/admin/users', async (req, res) => {
  try {
    const { fullName, password, department } = req.body;

    // Validation
    if (!fullName || !password || !department) {
      return res.status(400).json({
        success: false,
        message: 'Full Name, Password, and Department are required'
      });
    }

    // Password validation
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
    if (!passwordRegex.test(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 symbol'
      });
    }

    // Validate department
    const departments = csvService.getDepartments();
    if (!departments.includes(department)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid department'
      });
    }

    // Hash password
    const passwordHash = await argon2.hash(password);

    // Create user
    const user = await csvService.writeUser({
      fullName,
      passwordHash,
      department
    });

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      user: {
        userId: user.userId,
        fullName: user.fullName,
        department: user.department,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PUT /api/admin/users/:userId - Update user
router.put('/admin/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { fullName, password, department } = req.body;

    // Get all users
    const users = await csvService.readUsers();
    const userIndex = users.findIndex(u => u.userId === userId);

    if (userIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Update fields
    if (fullName) users[userIndex].fullName = fullName;
    if (department) {
      const departments = csvService.getDepartments();
      if (!departments.includes(department)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid department'
        });
      }
      users[userIndex].department = department;
    }
    if (password) {
      // Password validation
      const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
      if (!passwordRegex.test(password)) {
        return res.status(400).json({
          success: false,
          message: 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 symbol'
        });
      }
      users[userIndex].passwordHash = await argon2.hash(password);
    }

    // Write all users back to CSV
    await csvService.writeAllUsers(users);

    res.json({
      success: true,
      message: 'User updated successfully',
      user: {
        userId: users[userIndex].userId,
        fullName: users[userIndex].fullName,
        department: users[userIndex].department,
        role: users[userIndex].role
      }
    });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// DELETE /api/admin/users/:userId - Delete user
router.delete('/admin/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    // Get all users
    const users = await csvService.readUsers();
    const filteredUsers = users.filter(u => u.userId !== userId);

    if (users.length === filteredUsers.length) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Write filtered users back to CSV
    await csvService.writeAllUsers(filteredUsers);

    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ============================================
// VENDORS CRUD OPERATIONS
// ============================================

// GET /api/admin/vendors - Get all vendors with pricing
router.get('/admin/vendors', async (req, res) => {
  try {
    console.log('[GET /api/admin/vendors] Starting request...');
    const vendors = await csvService.readVendorsWithPricing();
    console.log(`[GET /api/admin/vendors] Successfully loaded ${vendors.length} vendors`);
    res.json({
      success: true,
      vendors: vendors
    });
  } catch (error) {
    console.error('[GET /api/admin/vendors] Error:', error);
    console.error('[GET /api/admin/vendors] Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// POST /api/admin/vendors - Create new vendor
router.post('/admin/vendors', async (req, res) => {
  try {
    const { vendor_name, kl, pick_up_by_sol_below_3000_kgs, dropped_by_vendor_below_3000_kgs,
            pick_up_by_sol_between_3000_to_5999_kgs, dropped_by_vendor_below_5999_kgs,
            pick_up_by_sol_above_6000_kgs, dropped_by_vendor_above_6000_kgs, toll_charges } = req.body;

    if (!vendor_name) {
      return res.status(400).json({
        success: false,
        message: 'Vendor name is required'
      });
    }

    // Get all vendors
    const vendors = await csvService.readVendorsWithPricing();
    
    // Find next S/L number
    const maxSl = Math.max(...vendors.map(v => parseInt(v.vendor_name ? 0 : 0)), 0);
    const newSl = maxSl + 1;

    // Create new vendor
    const newVendor = {
      'S/L': newSl.toString(),
      'Vender Place': vendor_name,
      'KL': kl || '',
      'Pick_up_by_sol_below_3000_kgs': pick_up_by_sol_below_3000_kgs || '0',
      'Dropped_by_vendor_below_3000_kgs': dropped_by_vendor_below_3000_kgs || '0',
      'Pick_up_by_sol_between_3000_to_5999_kgs': pick_up_by_sol_between_3000_to_5999_kgs || '0',
      'Dropped_by_vendor_below_5999_kgs': dropped_by_vendor_below_5999_kgs || '0',
      'Pick_up_by_sol_above_6000_kgs': pick_up_by_sol_above_6000_kgs || '0',
      'Dropped_by_vendor_above_6000_kgs': dropped_by_vendor_above_6000_kgs || '0',
      'Toll charges': toll_charges || '0'
    };

    vendors.push({
      vendor_name: vendor_name,
      kl: kl || '',
      pick_up_by_sol_below_3000_kgs: pick_up_by_sol_below_3000_kgs || '0',
      dropped_by_vendor_below_3000_kgs: dropped_by_vendor_below_3000_kgs || '0',
      pick_up_by_sol_between_3000_to_5999_kgs: pick_up_by_sol_between_3000_to_5999_kgs || '0',
      dropped_by_vendor_below_5999_kgs: dropped_by_vendor_below_5999_kgs || '0',
      pick_up_by_sol_above_6000_kgs: pick_up_by_sol_above_6000_kgs || '0',
      dropped_by_vendor_above_6000_kgs: dropped_by_vendor_above_6000_kgs || '0',
      toll_charges: toll_charges || '0'
    });

    // Write vendors back to CSV
    await csvService.writeAllVendors(vendors);

    res.status(201).json({
      success: true,
      message: 'Vendor created successfully',
      vendor: newVendor
    });
  } catch (error) {
    console.error('Create vendor error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PUT /api/admin/vendors/:vendorName - Update vendor
router.put('/admin/vendors/:vendorName', async (req, res) => {
  try {
    const { vendorName } = req.params;
    const updates = req.body;

    // Get all vendors
    const vendors = await csvService.readVendorsWithPricing();
    const vendorIndex = vendors.findIndex(v => v.vendor_name === decodeURIComponent(vendorName));

    if (vendorIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Vendor not found'
      });
    }

    // Update fields
    if (updates.vendor_name) vendors[vendorIndex].vendor_name = updates.vendor_name;
    if (updates.kl !== undefined) vendors[vendorIndex].kl = updates.kl;
    if (updates.pick_up_by_sol_below_3000_kgs !== undefined) vendors[vendorIndex].pick_up_by_sol_below_3000_kgs = updates.pick_up_by_sol_below_3000_kgs;
    if (updates.dropped_by_vendor_below_3000_kgs !== undefined) vendors[vendorIndex].dropped_by_vendor_below_3000_kgs = updates.dropped_by_vendor_below_3000_kgs;
    if (updates.pick_up_by_sol_between_3000_to_5999_kgs !== undefined) vendors[vendorIndex].pick_up_by_sol_between_3000_to_5999_kgs = updates.pick_up_by_sol_between_3000_to_5999_kgs;
    if (updates.dropped_by_vendor_below_5999_kgs !== undefined) vendors[vendorIndex].dropped_by_vendor_below_5999_kgs = updates.dropped_by_vendor_below_5999_kgs;
    if (updates.pick_up_by_sol_above_6000_kgs !== undefined) vendors[vendorIndex].pick_up_by_sol_above_6000_kgs = updates.pick_up_by_sol_above_6000_kgs;
    if (updates.dropped_by_vendor_above_6000_kgs !== undefined) vendors[vendorIndex].dropped_by_vendor_above_6000_kgs = updates.dropped_by_vendor_above_6000_kgs;
    if (updates.toll_charges !== undefined) vendors[vendorIndex].toll_charges = updates.toll_charges;

    // Write vendors back to CSV
    await csvService.writeAllVendors(vendors);

    res.json({
      success: true,
      message: 'Vendor updated successfully',
      vendor: vendors[vendorIndex]
    });
  } catch (error) {
    console.error('Update vendor error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// DELETE /api/admin/vendors/:vendorName - Delete vendor
router.delete('/admin/vendors/:vendorName', async (req, res) => {
  try {
    const { vendorName } = req.params;
    const decodedName = decodeURIComponent(vendorName);

    // Get all vendors
    const vendors = await csvService.readVendorsWithPricing();
    const filteredVendors = vendors.filter(v => v.vendor_name !== decodedName);

    if (vendors.length === filteredVendors.length) {
      return res.status(404).json({
        success: false,
        message: 'Vendor not found'
      });
    }

    // Write filtered vendors back to CSV
    await csvService.writeAllVendors(filteredVendors);

    res.json({
      success: true,
      message: 'Vendor deleted successfully'
    });
  } catch (error) {
    console.error('Delete vendor error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ============================================
// VEHICLES CRUD OPERATIONS
// ============================================

// GET /api/admin/vehicles - Get all vehicles
router.get('/admin/vehicles', async (req, res) => {
  try {
    const vehicles = await csvService.readVehicles();
    res.json({
      success: true,
      vehicles: vehicles
    });
  } catch (error) {
    console.error('Get vehicles error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/admin/vehicles - Create new vehicle
router.post('/admin/vehicles', async (req, res) => {
  try {
    const { vehicle_number, type, capacity_kg, vehicle_type, vendor_vehicle, status } = req.body;

    if (!vehicle_number || !type || !capacity_kg) {
      return res.status(400).json({
        success: false,
        message: 'Vehicle number, type, and capacity are required'
      });
    }

    // Get all vehicles
    const vehicles = await csvService.readVehicles();
    
    // Find next vehicleId
    const maxId = Math.max(...vehicles.map(v => parseInt(v.vehicleId) || 0), 0);
    const newId = (maxId + 1).toString();

    // Create new vehicle
    const newVehicle = {
      vehicleId: newId,
      vehicle_number: vehicle_number,
      type: type,
      capacity_kg: parseInt(capacity_kg),
      vehicle_type: vehicle_type || '19ft',
      vendor_vehicle: vendor_vehicle || 'company_vehicle',
      status: status || 'Free'
    };

    vehicles.push(newVehicle);

    // Write vehicles back to CSV
    await csvService.writeAllVehicles(vehicles);

    res.status(201).json({
      success: true,
      message: 'Vehicle created successfully',
      vehicle: newVehicle
    });
  } catch (error) {
    console.error('Create vehicle error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PUT /api/admin/vehicles/:vehicleId - Update vehicle
router.put('/admin/vehicles/:vehicleId', async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const updates = req.body;

    // Get all vehicles
    const vehicles = await csvService.readVehicles();
    const vehicleIndex = vehicles.findIndex(v => v.vehicleId === vehicleId);

    if (vehicleIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found'
      });
    }

    // Update fields
    if (updates.vehicle_number) vehicles[vehicleIndex].vehicle_number = updates.vehicle_number;
    if (updates.type) vehicles[vehicleIndex].type = updates.type;
    if (updates.capacity_kg !== undefined) vehicles[vehicleIndex].capacity_kg = parseInt(updates.capacity_kg);
    if (updates.vehicle_type) vehicles[vehicleIndex].vehicle_type = updates.vehicle_type;
    if (updates.vendor_vehicle) vehicles[vehicleIndex].vendor_vehicle = updates.vendor_vehicle;
    if (updates.status) vehicles[vehicleIndex].status = updates.status;

    // Write vehicles back to CSV
    await csvService.writeAllVehicles(vehicles);

    res.json({
      success: true,
      message: 'Vehicle updated successfully',
      vehicle: vehicles[vehicleIndex]
    });
  } catch (error) {
    console.error('Update vehicle error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// DELETE /api/admin/vehicles/:vehicleId - Delete vehicle
router.delete('/admin/vehicles/:vehicleId', async (req, res) => {
  try {
    const { vehicleId } = req.params;

    // Get all vehicles
    const vehicles = await csvService.readVehicles();
    const filteredVehicles = vehicles.filter(v => v.vehicleId !== vehicleId);

    if (vehicles.length === filteredVehicles.length) {
      return res.status(404).json({
        success: false,
        message: 'Vehicle not found'
      });
    }

    // Write filtered vehicles back to CSV
    await csvService.writeAllVehicles(filteredVehicles);

    res.json({
      success: true,
      message: 'Vehicle deleted successfully'
    });
  } catch (error) {
    console.error('Delete vehicle error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

module.exports = router;

