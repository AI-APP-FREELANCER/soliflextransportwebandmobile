const express = require('express');
const router = express.Router();
const csvService = require('../services/csvDatabaseService');

// GET /api/vendors - Get all vendors
router.get('/vendors', async (req, res) => {
  try {
    const vendors = await csvService.getVendors();
    res.json({
      success: true,
      vendors: vendors
    });
  } catch (error) {
    console.error('Vendors error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/vehicles - Get all vehicles
router.get('/vehicles', async (req, res) => {
  try {
    const isBusy = req.query.isBusy === 'true' ? true : req.query.isBusy === 'false' ? false : null;
    const vehicles = await csvService.getVehicles(isBusy);
    res.json({
      success: true,
      vehicles: vehicles
    });
  } catch (error) {
    console.error('Vehicles error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/rfq/match-vehicles - Match vehicles for material weight
router.post('/rfq/match-vehicles', async (req, res) => {
  try {
    const { materialWeight } = req.body;
    
    if (!materialWeight || materialWeight <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid material weight is required'
      });
    }
    
    const matchedVehicles = await csvService.matchVehicles(parseInt(materialWeight));
    
    res.json({
      success: true,
      vehicles: matchedVehicles
    });
  } catch (error) {
    console.error('Vehicle matching error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/rfq/create - Create new RFQ
router.post('/rfq/create', async (req, res) => {
  try {
    const { userId, source, destination, materialWeight, materialType, vehicleId, vehicle_number } = req.body;
    
    // Validation
    if (!userId || !source || !destination || !materialWeight || !materialType) {
      return res.status(400).json({
        success: false,
        message: 'All required fields must be provided'
      });
    }
    
    // Check user exists
    const user = await csvService.getUserById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check role - RFQ_CREATOR or higher can create RFQs
    const validRoles = ['RFQ_CREATOR', 'APPROVAL_MANAGER', 'SUPER_USER'];
    if (!validRoles.includes(user.role)) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to create RFQs'
      });
    }
    
    // Calculate cost (simple calculation for now)
    const baseCost = parseFloat(materialWeight) * 10; // 10 per kg
    const totalCost = baseCost;
    
    // Create RFQ
    const rfq = await csvService.writeRFQ({
      userId,
      source,
      destination,
      materialWeight: parseInt(materialWeight),
      materialType,
      vehicleId: vehicleId || null,
      vehicle_number: vehicle_number || null,
      status: 'PENDING_APPROVAL',
      totalCost: totalCost
    });
    
    res.status(201).json({
      success: true,
      message: 'RFQ created successfully',
      rfq: rfq
    });
  } catch (error) {
    console.error('RFQ creation error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/rfq/user/:userId - Get user's RFQs
router.get('/rfq/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const rfqs = await csvService.getRFQsByUserId(userId);
    
    res.json({
      success: true,
      rfqs: rfqs
    });
  } catch (error) {
    console.error('Get user RFQs error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/rfq/:rfqId - Get RFQ by ID
router.get('/rfq/:rfqId', async (req, res) => {
  try {
    const { rfqId } = req.params;
    const rfq = await csvService.getRFQById(rfqId);
    
    if (!rfq) {
      return res.status(404).json({
        success: false,
        message: 'RFQ not found'
      });
    }
    
    res.json({
      success: true,
      rfq: rfq
    });
  } catch (error) {
    console.error('Get RFQ error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/rfq/pending - Get all pending RFQs (for approval manager)
router.get('/rfq/pending', async (req, res) => {
  try {
    const rfqs = await csvService.getRFQsByStatus('PENDING_APPROVAL');
    
    res.json({
      success: true,
      rfqs: rfqs
    });
  } catch (error) {
    console.error('Get pending RFQs error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/rfq/:rfqId/approve - Approve RFQ
router.post('/rfq/:rfqId/approve', async (req, res) => {
  try {
    const { rfqId } = req.params;
    const { userId } = req.body; // Approval manager's user ID
    
    // Check user exists and has permission
    const user = await csvService.getUserById(userId);
    if (!user || (user.role !== 'APPROVAL_MANAGER' && user.role !== 'SUPER_USER')) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to approve RFQs'
      });
    }
    
    const rfq = await csvService.updateRFQStatus(rfqId, 'APPROVED', {
      approvedBy: userId,
      approvedAt: new Date().toISOString()
    });
    
    res.json({
      success: true,
      message: 'RFQ approved successfully',
      rfq: rfq
    });
  } catch (error) {
    console.error('Approve RFQ error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/rfq/:rfqId/reject - Reject RFQ
router.post('/rfq/:rfqId/reject', async (req, res) => {
  try {
    const { rfqId } = req.params;
    const { userId, rejectionReason } = req.body;
    
    if (!rejectionReason || rejectionReason.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Rejection reason is required'
      });
    }
    
    // Check user exists and has permission
    const user = await csvService.getUserById(userId);
    if (!user || (user.role !== 'APPROVAL_MANAGER' && user.role !== 'SUPER_USER')) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to reject RFQs'
      });
    }
    
    const rfq = await csvService.updateRFQStatus(rfqId, 'REJECTED', {
      approvedBy: userId,
      rejectedAt: new Date().toISOString(),
      rejectionReason: rejectionReason
    });
    
    res.json({
      success: true,
      message: 'RFQ rejected successfully',
      rfq: rfq
    });
  } catch (error) {
    console.error('Reject RFQ error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/rfq/:rfqId/start - Start trip (Super User only)
router.post('/rfq/:rfqId/start', async (req, res) => {
  try {
    const { rfqId } = req.params;
    const { userId } = req.body;
    
    // Check user exists and is Super User
    const user = await csvService.getUserById(userId);
    if (!user || user.role !== 'SUPER_USER') {
      return res.status(403).json({
        success: false,
        message: 'Only Super Users can start trips'
      });
    }
    
    const rfq = await csvService.updateRFQStatus(rfqId, 'IN_PROGRESS', {
      startedAt: new Date().toISOString()
    });
    
    res.json({
      success: true,
      message: 'Trip started successfully',
      rfq: rfq
    });
  } catch (error) {
    console.error('Start trip error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/rfq/:rfqId/complete - Complete trip (Super User only)
router.post('/rfq/:rfqId/complete', async (req, res) => {
  try {
    const { rfqId } = req.params;
    const { userId } = req.body;
    
    // Check user exists and is Super User
    const user = await csvService.getUserById(userId);
    if (!user || user.role !== 'SUPER_USER') {
      return res.status(403).json({
        success: false,
        message: 'Only Super Users can complete trips'
      });
    }
    
    const rfq = await csvService.updateRFQStatus(rfqId, 'COMPLETED', {
      completedAt: new Date().toISOString()
    });
    
    res.json({
      success: true,
      message: 'Trip completed successfully',
      rfq: rfq
    });
  } catch (error) {
    console.error('Complete trip error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

module.exports = router;

