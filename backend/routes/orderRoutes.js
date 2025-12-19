const express = require('express');
const router = express.Router();
const csvService = require('../services/csvDatabaseService');
const notificationService = require('../services/notificationService');

// GET /api/orders - Get all orders
router.get('/orders', async (req, res) => {
  try {
    const orders = await csvService.readOrders();
    res.json({
      success: true,
      orders: orders
    });
  } catch (error) {
    console.error('Get orders error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/orders/user/:userId - Get user's orders
router.get('/orders/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const orders = await csvService.readOrders();
    const userOrders = orders.filter(order => order.user_id === userId);
    
    res.json({
      success: true,
      orders: userOrders
    });
  } catch (error) {
    console.error('Get user orders error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/orders/:orderId - Get single order details
router.get('/orders/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await csvService.getOrderById(orderId);
    
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    res.json({
      success: true,
      order: order
    });
  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/create-order - Create a new order
router.post('/create-order', async (req, res) => {
  try {
    let {
      userId,
      source,
      destination,
      materialWeight,
      materialType,
      tripType = 'Single-Trip-Vendor',
      vehicleId,
      vehicleNumber,
      segments, // For Multiple trip type - array of segment objects
      invoiceAmount, // For Single/Round/Internal trips - optional manual override
      tollCharges // For Single/Round/Internal trips - optional manual override
    } = req.body;
    
    // CRITICAL FIX: Validate required fields based on trip type
    // For Multiple Trip, materialWeight and materialType are in segments, not top-level
    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'Missing required field: userId'
      });
    }
    
    // For non-Multiple Trip orders, validate materialWeight and materialType at top level
    if (tripType !== 'Multiple-Trip-Vendor') {
      if (!materialWeight || materialWeight <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Missing or invalid required field: materialWeight'
        });
      }
      if (!materialType || materialType.trim() === '') {
        return res.status(400).json({
          success: false,
          message: 'Missing required field: materialType'
        });
      }
    } else {
      // For Multiple Trip, validate segments array
      if (!segments || !Array.isArray(segments) || segments.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Missing or empty segments array for Multiple Trip'
        });
      }
      // Validate each segment has required fields
      for (let i = 0; i < segments.length; i++) {
        const seg = segments[i];
        if (!seg.source || !seg.destination || !seg.material_weight || seg.material_weight <= 0 || !seg.material_type) {
          return res.status(400).json({
            success: false,
            message: `Segment ${i + 1} is missing required fields: source, destination, material_weight (>0), or material_type`
          });
        }
      }
    }
    
    // Generate order ID
    const orderId = await csvService.getNextOrderId();
    
    // Build trip_segments array based on trip type
    let tripSegments = [];
    let finalSource = source || '';
    let finalDestination = destination || '';
    // Store original trip type for audit trail (may be recategorized for factory-to-factory Round Trips)
    let originalTripType = tripType;
    
    if (tripType === 'Single-Trip-Vendor') {
      // Single Trip Vendor: 1 segment from source to destination
      if (!source || !destination) {
        return res.status(400).json({
          success: false,
          message: 'Source and destination are required for Single Trip Vendor'
        });
      }
      tripSegments = [{
        segment_id: 1,
        source: source,
        destination: destination,
        material_weight: parseInt(materialWeight) || 0,
        material_type: materialType,
        segment_status: 'Pending',
        invoice_amount: invoiceAmount !== undefined ? parseInt(invoiceAmount) : undefined,
        toll_charges: tollCharges !== undefined ? parseInt(tollCharges) : undefined
      }];
      finalSource = source;
      finalDestination = destination;
    } else if (tripType === 'Round-Trip-Vendor') {
      // Round Trip Vendor: MANDATORY two-segment creation (A->B, B->A)
      // Part 1: Strict Validation
      // - A (Starting Point) must be Factory
      // - B (End Point) must be Vendor
      // - A and B must be different
      // Part 2: Dynamic Categorization
      // - If both A and B are Factories, recategorize as 'Internal Transfer' but keep A->B->A segments
      
      if (!source || !destination) {
        return res.status(400).json({
          success: false,
          message: 'Source and destination are required for Round Trip Vendor'
        });
      }
      
      const sourceLocation = source.trim();
      const destLocation = destination.trim();
      
      // Validation 1: Source and Destination cannot be the same
      if (sourceLocation.toLowerCase() === destLocation.toLowerCase()) {
        return res.status(400).json({
          success: false,
          message: 'Starting Point and End Point cannot be the same location for Round Trip. Please select different locations.'
        });
      }
      
      // Validation 2: Check if both locations are factories (for recategorization)
      const isSourceFactory = csvService.isFactoryLocation(sourceLocation);
      const isDestFactory = csvService.isFactoryLocation(destLocation);
      
      // Part 2: Dynamic Trip Categorization (Internal Transfer Logic)
      // If both A and B are Factories, recategorize as 'Internal Transfer'
      // originalTripType already stored in outer scope for audit trail
      if (isSourceFactory && isDestFactory) {
        // Recategorize: Both are Factories -> Internal Transfer
        // But still generate A->B->A segments (same structure)
        tripType = 'Internal-Transfer';
        console.log(`[Round Trip Recategorization] Both Starting Point (${sourceLocation}) and End Point (${destLocation}) are Factories. Recategorizing as 'Internal Transfer' but maintaining A->B->A segment structure.`);
      } else {
        // Part 1: Strict Validation for Round-Trip-Vendor
        // A (Starting Point) must be Factory, B (End Point) must be Vendor
        
        // Validation 2a: A must be Factory for Round-Trip-Vendor
        if (!isSourceFactory) {
          return res.status(400).json({
            success: false,
            message: `Round Trip Starting Point must be a Factory location. Selected location '${sourceLocation}' is not a Factory. Please select a Factory location (IAF unit-1/2/3/4 or Soliflex unit-1/2/3/4) as the Starting Point, or use 'Single-Trip-Vendor' if starting from a Vendor.`
          });
        }
        
        // Validation 2b: B must be Vendor (not Factory) for Round-Trip-Vendor
        if (isDestFactory) {
          return res.status(400).json({
            success: false,
            message: `Round Trip End Point must be a Vendor location (not a Factory). Selected location '${destLocation}' is a Factory. Please select a Vendor location as the End Point, or use 'Internal Transfer' if the destination is a Factory.`
          });
        }
        
        // Validation passed: A is Factory, B is Vendor
        console.log(`[Round Trip Validation] ✓ Valid Round Trip: Factory (${sourceLocation}) -> Vendor (${destLocation})`);
      }
      
      // Part 3: Final Segment Structure Guarantee
      // MANDATORY: Always generate exactly 2 segments: A->B and B->A
      // Segment 1 (Outbound): A -> B
      // Segment 2 (Return): B -> A
      tripSegments = [
        {
          segment_id: 1,
          source: sourceLocation, // Starting Point (A)
          destination: destLocation, // End Point (B)
          material_weight: parseInt(materialWeight) || 0,
          material_type: materialType,
          segment_status: 'Pending',
          invoice_amount: invoiceAmount !== undefined ? parseInt(invoiceAmount) : undefined,
          toll_charges: tollCharges !== undefined ? parseInt(tollCharges) : undefined,
          is_manual_invoice: 'No' // Will be updated during invoice calculation
        },
        // Segment 2 (Return): B -> A
        // MANDATORY: Always generate return segment to complete the round trip
        // NON-CHARGEABLE RETURN LEG: Weight for display, but 0 invoice/toll (does not contribute to totals)
        // Part 1: Material Weight MUST use same value as Segment 1 (for visual representation that load is still present)
        // Part 1: Invoice Amount and Toll Charges MUST be 0 (non-chargeable return leg)
        {
          segment_id: 2,
          source: destLocation, // End Point (B) becomes source for return leg
          destination: sourceLocation, // Original Starting Point (A) is the return destination
          material_weight: parseInt(materialWeight) || 0, // Part 1: MUST use same weight as Segment 1 (for display)
          material_type: materialType, // Default to same material type
          segment_status: 'Pending',
          // Part 1: MANDATORY: Set to 0 (non-chargeable return leg - does not contribute to totals)
          invoice_amount: 0,
          toll_charges: 0,
          is_manual_invoice: 'No'
        }
      ];
      // For Round Trip: finalSource is starting point (A), finalDestination is also A (round trip completes)
      // BUT: The route summary should show A → B → A, not just A → A
      // We'll use trip_segments to derive the correct display route
      finalSource = sourceLocation; // Starting Point (A)
      finalDestination = sourceLocation; // Round trip always ends at original starting point (A)
      
      // Debug: Log segment structure for Round Trip
      console.log(`[Round Trip] Segment structure created:`);
      console.log(`  Segment 1: ${sourceLocation} → ${destLocation}`);
      console.log(`  Segment 2: ${destLocation} → ${sourceLocation}`);
      console.log(`  Final Source: ${finalSource}, Final Destination: ${finalDestination}`);
    } else if (tripType === 'Internal-Transfer') {
      // Internal Transfer: 1 segment from source to destination (factory locations only)
      if (!source || !destination) {
        return res.status(400).json({
          success: false,
          message: 'Source and destination are required for Internal Transfer'
        });
      }
      tripSegments = [{
        segment_id: 1,
        source: source,
        destination: destination,
        material_weight: parseInt(materialWeight) || 0,
        material_type: materialType,
        segment_status: 'Pending',
        invoice_amount: invoiceAmount !== undefined ? parseInt(invoiceAmount) : undefined,
        toll_charges: tollCharges !== undefined ? parseInt(tollCharges) : undefined
      }];
      finalSource = source;
      finalDestination = destination;
    } else if (tripType === 'Multiple-Trip-Vendor') {
      // Multiple Trip: N segments from segments array
      if (!segments || !Array.isArray(segments) || segments.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Segments array is required for Multiple trip type'
        });
      }
      // Multiple Trip: Map segments and ensure each has independent invoice/toll calculation
      // Part 1: ALL segments can have manual invoice/toll from frontend
      tripSegments = segments.map((seg, index) => ({
        segment_id: index + 1,
        source: seg.source || '',
        destination: seg.destination || '',
        material_weight: parseInt(seg.material_weight) || 0,
        material_type: seg.material_type || '',
        segment_status: 'Pending',
        // Part 1: ALL segments can have manual invoice/toll from frontend (not just Segment 1)
        invoice_amount: (seg.invoice_amount !== undefined && seg.invoice_amount !== null) ? parseInt(seg.invoice_amount) : undefined,
        toll_charges: (seg.toll_charges !== undefined && seg.toll_charges !== null) ? parseInt(seg.toll_charges) : undefined,
        is_manual_invoice: 'No' // Will be updated during calculation
      }));
      
      // Set source/destination from first/last segment
      finalSource = segments[0].source || '';
      finalDestination = segments[segments.length - 1].destination || '';
    } else {
      return res.status(400).json({
        success: false,
        message: 'Invalid trip type. Must be Single-Trip-Vendor, Round-Trip-Vendor, Multiple-Trip-Vendor, or Internal-Transfer'
      });
    }
    
    // Calculate invoice_amount and toll_charges for each segment
    // CRITICAL: Each segment must be calculated independently based on its own source and weight
    for (let i = 0; i < tripSegments.length; i++) {
      const segment = tripSegments[i];
      
      // Part 1 Fix: For Round Trip Segment 2, skip rate card calculation (already set to 0)
      // Segment 2 must remain 0 weight and 0 invoice for initial creation
      if (i === 1 && (tripType === 'Round-Trip-Vendor' || originalTripType === 'Round-Trip-Vendor')) {
        // Segment 2 is already initialized with 0 values - skip rate card calculation
        console.log(`[Round Trip Segment 2] Skipping rate card calculation - kept at 0 weight and 0 invoice`);
        continue; // Skip to next segment
      }
      
      // Part 1: For Multiple Trip, ALL segments can have manual invoice/toll from frontend
      // For Round Trip, only Segment 1 can have manual override
      const providedInvoice = (tripType === 'Multiple-Trip-Vendor') 
        ? segment.invoice_amount  // Multiple Trip: All segments can have manual override
        : ((i === 0) ? segment.invoice_amount : undefined); // Round Trip: Only Segment 1
      const providedToll = (tripType === 'Multiple-Trip-Vendor')
        ? segment.toll_charges  // Multiple Trip: All segments can have manual override
        : ((i === 0) ? segment.toll_charges : undefined); // Round Trip: Only Segment 1
      
      // Part 1: For Round Trip only, ensure Segment 2+ starts with undefined
      if (i > 0 && (tripType === 'Round-Trip-Vendor' || originalTripType === 'Round-Trip-Vendor')) {
        // Round Trip Segment 2+ handled separately
      } else if (i > 0 && tripType !== 'Multiple-Trip-Vendor') {
        // For other trip types (not Round Trip, not Multiple Trip), reset Segment 2+
        segment.invoice_amount = undefined;
        segment.toll_charges = undefined;
      }
      
      try {
        // Part 1: For Multiple Trip, use segment-specific calculation (checks both source and destination)
        // For other trip types, use source-only calculation (backward compatible)
        let rateResult;
        if (tripType === 'Multiple-Trip-Vendor') {
          // Multiple Trip: USER REQUEST - Always use Drop rates for all segments
          rateResult = await csvService.calculateInvoiceRate(
            segment.source, // Source location
            segment.material_weight, // Material weight
            segment.destination, // Destination location
            tripType // Pass tripType to force Drop rates
          );
        } else {
          // Single/Round/Internal: Use source-only calculation (backward compatible)
          rateResult = await csvService.calculateInvoiceRate(
            segment.source, // Use segment's own source
            segment.material_weight // Use segment's own weight
          );
        }
        
        // Check if frontend provided manual values that differ from calculated
        if (providedInvoice !== undefined && providedInvoice !== null && 
            parseInt(providedInvoice) !== rateResult.invoice_amount) {
          segment.invoice_amount = parseInt(providedInvoice);
          segment.is_manual_invoice = 'Yes';
        } else {
          // Auto-calculated value
          segment.invoice_amount = rateResult.invoice_amount;
          segment.is_manual_invoice = (providedInvoice !== undefined && providedInvoice !== null) ? 'Yes' : 'No';
        }
        
        // Check if frontend provided manual toll values
        if (providedToll !== undefined && providedToll !== null &&
            parseInt(providedToll) !== rateResult.toll_charges) {
          segment.toll_charges = parseInt(providedToll);
          if (segment.is_manual_invoice !== 'Yes') {
            segment.is_manual_invoice = 'Yes';
          }
        } else {
          // Auto-calculated toll charges
          segment.toll_charges = rateResult.toll_charges;
          if (segment.is_manual_invoice !== 'Yes' && providedToll === undefined) {
            segment.is_manual_invoice = 'No';
          }
        }
        
        // Debug logging for Segment 1 (already calculated above)
        if (i === 0 && (tripType === 'Round-Trip-Vendor' || originalTripType === 'Round-Trip-Vendor')) {
          console.log(`[Round Trip Segment 1] Calculated:`);
          console.log(`  Source: ${segment.source} (Factory location)`);
          console.log(`  Destination: ${segment.destination} (Vendor location)`);
          console.log(`  Weight: ${segment.material_weight} kg (User input)`);
          console.log(`  Invoice: ₹${segment.invoice_amount} (User input or calculated)`);
          console.log(`  Segment 2 will remain at 0 weight and 0 invoice`);
        }
      } catch (error) {
        console.error(`Error calculating invoice rate for segment ${i + 1}:`, error);
        // Set defaults if calculation fails
        if (i === 0 && providedInvoice !== undefined) {
          segment.invoice_amount = parseInt(providedInvoice);
        } else {
          segment.invoice_amount = 0; // Default for Segment 2+ or if calculation fails
        }
        
        if (i === 0 && providedToll !== undefined) {
          segment.toll_charges = parseInt(providedToll);
        } else {
          segment.toll_charges = 0; // Default for Segment 2+ or if calculation fails
        }
        
        segment.is_manual_invoice = (i === 0 && (providedInvoice !== undefined || providedToll !== undefined)) ? 'Yes' : 'No';
      }
    }
    
    // Calculate order totals (ONCE) - sums only chargeable segments' weights, invoice amounts, and toll charges
    // For Round Trip: Only Segment 1 contributes (Segment 2 is non-chargeable)
    // CRITICAL: This calculation happens only once during order creation to prevent double-counting
    const totals = csvService.calculateOrderTotals(tripSegments, tripType);
    
    // Validation: Ensure Round Trip (or recategorized Internal Transfer from Round Trip) has exactly 2 segments in correct A->B->A structure
    // Note: Recategorized Internal Transfer from Round Trip will have tripType='Internal-Transfer' but should still have 2 segments
    if (tripType === 'Round-Trip-Vendor' || originalTripType === 'Round-Trip-Vendor') {
      if (tripSegments.length !== 2) {
        console.error(`[Round Trip Validation] Expected 2 segments, found: ${tripSegments.length}`);
        console.error(`[Round Trip Validation] Segments:`, JSON.stringify(tripSegments, null, 2));
        return res.status(400).json({
          success: false,
          message: `Round Trip must have exactly 2 segments. Found: ${tripSegments.length}. Please ensure the backend correctly generated both outbound (A->B) and return (B->A) segments.`
        });
      }
      
      // Verify Round Trip structure: A->B (segment 1), B->A (segment 2)
      const segment1 = tripSegments[0];
      const segment2 = tripSegments[1];
      
      // Validation: Segment 1 destination must equal Segment 2 source (A->B->A continuity)
      if (segment1.destination !== segment2.source) {
        console.error(`[Round Trip Validation] Segment continuity error:`);
        console.error(`  Segment 1: ${segment1.source} -> ${segment1.destination}`);
        console.error(`  Segment 2: ${segment2.source} -> ${segment2.destination}`);
        return res.status(400).json({
          success: false,
          message: `Round Trip segment structure invalid: Segment 1 destination (${segment1.destination}) must equal Segment 2 source (${segment2.source}) to form a valid A->B->A route.`
        });
      }
      
      // Validation: Segment 2 destination must equal Segment 1 source (completes the round trip)
      if (segment2.destination !== segment1.source) {
        console.error(`[Round Trip Validation] Return destination error:`);
        console.error(`  Segment 1: ${segment1.source} -> ${segment1.destination}`);
        console.error(`  Segment 2: ${segment2.source} -> ${segment2.destination}`);
        return res.status(400).json({
          success: false,
          message: `Round Trip return segment invalid: Segment 2 destination (${segment2.destination}) must equal Segment 1 source (${segment1.source}) to complete the round trip back to the starting point.`
        });
      }
      
      console.log(`[Round Trip Validation] ✓ Valid Round Trip structure:`);
      console.log(`  Segment 1 (Outbound): ${segment1.source} -> ${segment1.destination}`);
      console.log(`  Segment 2 (Return): ${segment2.source} -> ${segment2.destination}`);
    }
    
    // NEW LOGIC: Only assign truck if vehicleId is provided during creation
    if (vehicleId && vehicleId.trim() !== '') {
      try {
        await csvService.updateVehicleStatus(vehicleId, 'Booked');
      } catch (error) {
        console.error('Error updating vehicle status:', error);
        return res.status(400).json({
          success: false,
          message: `Failed to assign vehicle: ${error.message}`
        });
      }
    } else {
      console.log(`[Create Order] No vehicle assigned at creation for Order ${orderId}. Assignment required at approval.`);
    }
    
    // Calculate order category based on trip segments
    const orderCategory = csvService.calculateOrderCategory(tripSegments);
    
    // Get user's department and full name for creator tracking fields
    let creatorDepartment = '';
    let creatorName = '';
    try {
      const user = await csvService.getUserById(userId.toString());
      if (user) {
        if (user.department) {
          creatorDepartment = user.department;
        }
        if (user.fullName) {
          creatorName = user.fullName;
        }
      }
    } catch (error) {
      console.error('Error fetching user data:', error);
      // Continue without user data if lookup fails
    }
    
    // CRITICAL FIX: For Multiple Trip, calculate materialWeight and materialType from segments
    let finalMaterialWeight = materialWeight || 0;
    let finalMaterialType = materialType || '';
    
    if (tripType === 'Multiple-Trip-Vendor') {
      // Calculate total weight from segments
      finalMaterialWeight = tripSegments.reduce((sum, seg) => sum + (parseInt(seg.material_weight) || 0), 0);
      
      // Consolidate material types from all segments
      const allMaterialTypes = new Set();
      for (const seg of tripSegments) {
        try {
          const segMaterialType = seg.material_type || '';
          if (segMaterialType.trim() !== '') {
            // Try to parse as JSON array
            try {
              const parsed = JSON.parse(segMaterialType);
              if (Array.isArray(parsed)) {
                parsed.forEach(type => allMaterialTypes.add(type.toString()));
              } else {
                allMaterialTypes.add(segMaterialType);
              }
            } catch (e) {
              // If not JSON, treat as single string
              allMaterialTypes.add(segMaterialType);
            }
          }
        } catch (e) {
          console.error(`Error parsing material_type for segment:`, e);
        }
      }
      finalMaterialType = JSON.stringify(Array.from(allMaterialTypes));
      
      console.log(`[Multiple Trip] Calculated totals:`);
      console.log(`  Total Weight: ${finalMaterialWeight} kg`);
      console.log(`  Material Types: ${finalMaterialType}`);
    }
    
    // Create order object
    // CRITICAL FIX: Ensure all fields have defaults (null safety)
    // CRITICAL FIX: Add creator tracking fields (creatorUserId, creatorDepartment)
    const order = {
      order_id: orderId,
      user_id: userId.toString(),
      source: finalSource || '',
      destination: finalDestination || '',
      material_weight: finalMaterialWeight.toString(),
      material_type: finalMaterialType || '[]', // CRITICAL FIX: Ensure not null/empty
      trip_type: tripType,
      vehicle_id: vehicleId ? vehicleId.toString() : '',
      vehicle_number: vehicleNumber || '',
      order_status: 'Open',
      created_at: csvService.getISTTimestamp(),
      creator_department: creatorDepartment || '',
      creator_user_id: userId.toString(), // CRITICAL FIX: Track creator user ID
      creator_name: creatorName || '', // Track creator's full name
      trip_segments: tripSegments, // Will be stringified in writeOrder
      is_amended: 'No',
      original_trip_type: originalTripType || tripType, // Preserve original selection if recategorized
      order_category: orderCategory || 'Client/Vendor Order',
      total_weight: (totals.total_weight || 0).toString(), // CRITICAL FIX: Ensure not null
      total_invoice_amount: (totals.total_invoice_amount || 0).toString(), // CRITICAL FIX: Ensure not null
      total_toll_charges: (totals.total_toll_charges || 0).toString() // CRITICAL FIX: Ensure not null
    };
    
    // CRITICAL FIX: Initialize workflow for ALL segments when order is created
    // This ensures workflows are available immediately, not just when status changes to En-Route
    for (let i = 0; i < tripSegments.length; i++) {
      const segment = tripSegments[i];
      // Initialize workflow if it doesn't exist
      if (!segment.workflow || !Array.isArray(segment.workflow) || segment.workflow.length === 0) {
        const location = segment.destination || segment.source || '';
        segment.workflow = csvService.initializeSegmentWorkflow(segment, location);
        console.log(`[Create Order] Initialized workflow for Segment ${i + 1} (${segment.source} → ${segment.destination})`);
      }
    }
    
    // Update order with segments that now have workflows
    order.trip_segments = tripSegments;
    
    // CRITICAL FIX: Log final order payload before saving
    console.log(`[Create Order] Final Order Payload:`);
    console.log(`  Order ID: ${order.order_id}`);
    console.log(`  Trip Type: ${order.trip_type}`);
    console.log(`  Material Weight: ${order.material_weight} kg`);
    console.log(`  Material Type: ${order.material_type}`);
    console.log(`  Total Weight: ${order.total_weight} kg`);
    console.log(`  Total Invoice: ₹${order.total_invoice_amount}`);
    console.log(`  Total Toll: ₹${order.total_toll_charges}`);
    console.log(`  Vehicle ID: ${order.vehicle_id || 'N/A'}`);
    console.log(`  Vehicle Number: ${order.vehicle_number || 'N/A'}`);
    console.log(`  Segments Count: ${tripSegments.length}`);
    console.log(`  Workflows Initialized: ${tripSegments.every(seg => seg.workflow && Array.isArray(seg.workflow) && seg.workflow.length > 0)}`);
    
    // Save order
    await csvService.writeOrder(order);
    
    // Create notifications for new order
    try {
      await notificationService.notifyNewOrder(order);
    } catch (notificationError) {
      console.error('Error creating notifications for new order:', notificationError);
      // Continue even if notification creation fails
    }
    
    res.json({
      success: true,
      message: 'Order created successfully',
      order: {
        ...order,
        trip_segments: tripSegments // Return as array, not string
      }
    });
  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/assign-vehicle-to-order - Assign vehicle to an order
router.post('/assign-vehicle-to-order', async (req, res) => {
  try {
    const { orderId, vehicleId, vehicleNumber, vehicleType, capacityKg, userId } = req.body;
    
    if (!orderId || !vehicleNumber) {
      return res.status(400).json({
        success: false,
        message: 'Order ID and vehicle number are required'
      });
    }
    
    // Get order
    const order = await csvService.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    // Check if order already has a vehicle
    if (order.vehicle_id && order.vehicle_id.trim() !== '') {
      // Free the old vehicle if it exists
      try {
        await csvService.updateVehicleStatus(order.vehicle_id, 'Free');
      } catch (error) {
        console.error('Error freeing old vehicle:', error);
      }
    }
    
    // Update order with vehicle info
    order.vehicle_id = vehicleId ? vehicleId.toString() : '';
    order.vehicle_number = vehicleNumber;
    
    // Save order
    await csvService.writeOrder(order);
    
    // Mark new vehicle as booked if vehicleId is provided
    if (vehicleId && vehicleId.trim() !== '') {
      try {
        await csvService.updateVehicleStatus(vehicleId, 'Booked');
      } catch (error) {
        console.error('Error updating vehicle status:', error);
        // Continue even if vehicle status update fails
      }
    }
    
    return res.json({
      success: true,
      message: 'Vehicle assigned successfully',
      order: order
    });
  } catch (error) {
    console.error('Assign vehicle error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/update-order-status - Update order status
router.post('/update-order-status', async (req, res) => {
  try {
    const { orderId, newStatus, userId } = req.body;
    
    if (!orderId || !newStatus) {
      return res.status(400).json({
        success: false,
        message: 'Order ID and new status are required'
      });
    }
    
    // Get order before update to check previous status
    const orderBeforeUpdate = await csvService.getOrderById(orderId);
    if (!orderBeforeUpdate) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    const previousStatus = orderBeforeUpdate.order_status || '';
    
    // Parse segments to check completion status
    let segments = [];
    try {
      if (orderBeforeUpdate.trip_segments && orderBeforeUpdate.trip_segments.trim() !== '') {
        segments = JSON.parse(orderBeforeUpdate.trip_segments);
      }
    } catch (e) {
      console.error('Error parsing segments for validation:', e);
    }
    
    // Validation: Block manual completion unless all workflow stages are approved
    if (newStatus === 'Completed' || newStatus === 'COMPLETED') {
      const isCompleted = csvService.isOrderCompleted(orderBeforeUpdate, segments);
      if (!isCompleted) {
        return res.status(400).json({
          success: false,
          message: 'Order cannot be marked as Completed until all workflow stages are approved'
        });
      }
    }
    
    // Validation: Block cancellation after final approval
    if (newStatus === 'Cancelled' || newStatus === 'CANCELLED' || newStatus === 'Canceled' || newStatus === 'CANCELED') {
      const isCompleted = csvService.isOrderCompleted(orderBeforeUpdate, segments);
      if (isCompleted) {
        return res.status(400).json({
          success: false,
          message: 'Order cannot be cancelled after all approval stages have been completed'
        });
      }
    }
    
    // NEW VALIDATION: Block approval/start if no vehicle is assigned
    if ((newStatus === 'In-Progress' || newStatus === 'En-Route') && 
        (!orderBeforeUpdate.vehicle_id || orderBeforeUpdate.vehicle_id === '')) {
      return res.status(400).json({
        success: false,
        message: 'Vehicle assignment is mandatory before approving or starting this trip.'
      });
    }
    
    // Prepare update data with audit fields
    const updateData = {};
    
    // Capture approval stage data when status changes from Open to In-Progress or En-Route
    if ((newStatus === 'In-Progress' || newStatus === 'En-Route') && 
        (previousStatus === 'Open' || previousStatus === '')) {
      // Capture approval timestamp
      updateData.approved_timestamp = csvService.getISTTimestamp();
      
      // Capture approval user information if userId is provided
      if (userId) {
        try {
          const user = await csvService.getUserById(userId.toString());
          if (user) {
            updateData.approved_by_member = user.fullName || user.full_name || '';
            updateData.approved_by_department = user.department || '';
          }
        } catch (error) {
          console.error('Error fetching user for approval audit:', error);
          // Continue without user data if lookup fails
        }
      }
    }
    
    // Update order status (truck freeing is handled automatically in updateOrderStatus)
    const updatedOrder = await csvService.updateOrderStatus(orderId, newStatus, updateData);
    
    // Create notifications when order is approved (status changes to In-Progress or En-Route)
    if ((newStatus === 'In-Progress' || newStatus === 'En-Route') && 
        (previousStatus === 'Open' || previousStatus === '')) {
      try {
        await notificationService.notifyApprovedOrder(updatedOrder);
      } catch (notificationError) {
        console.error('Error creating notifications for approved order:', notificationError);
        // Continue even if notification creation fails
      }
    }
    
    // If status changed to 'En-Route', automatically initialize workflow
    if (newStatus === 'En-Route') {
      try {
        // Parse segments to check if workflow needs initialization
        let segments = [];
        if (updatedOrder.trip_segments && updatedOrder.trip_segments.trim() !== '') {
          try {
            segments = JSON.parse(updatedOrder.trip_segments);
          } catch (e) {
            console.error('Error parsing segments for workflow initialization:', e);
          }
        }
        
        // Check if any segment needs workflow initialization
        let needsInitialization = false;
        for (const segment of segments) {
          if (!segment.workflow || !Array.isArray(segment.workflow) || segment.workflow.length === 0) {
            needsInitialization = true;
            break;
          }
        }
        
        if (needsInitialization) {
          // Initialize workflow directly
          for (let i = 0; i < segments.length; i++) {
            const segment = segments[i];
            if (!segment.workflow || !Array.isArray(segment.workflow) || segment.workflow.length === 0) {
              const location = segment.destination || segment.source || '';
              segment.workflow = csvService.initializeSegmentWorkflow(segment, location);
            }
          }
          
          // Update order with initialized workflow
          const orderWithWorkflow = {
            ...updatedOrder,
            trip_segments: segments
          };
          
          // Save order with workflow
          await csvService.writeOrder(orderWithWorkflow);
          console.log(`Workflow initialized for order ${orderId}`);
        }
      } catch (error) {
        console.error('Error initializing workflow on status change:', error);
        // Don't fail the status update if workflow initialization fails
      }
    }
    
    res.json({
      success: true,
      message: 'Order status updated successfully',
      order: updatedOrder
    });
  } catch (error) {
    console.error('Update order status error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/calculate-invoice-rate - Calculate invoice amount and toll charges
// USER REQUEST: For Multiple Trip, ALWAYS use Drop rates (dropped_by_vendor_*) for all segments
router.post('/calculate-invoice-rate', async (req, res) => {
  try {
    const { source_location, material_weight, destination_location, trip_type } = req.body;
    
    if (!source_location || source_location.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Source location is required'
      });
    }
    
    if (material_weight === undefined || material_weight === null) {
      return res.status(400).json({
        success: false,
        message: 'Material weight is required'
      });
    }
    
    const weight = parseInt(material_weight);
    if (isNaN(weight) || weight < 0) {
      return res.status(400).json({
        success: false,
        message: 'Material weight must be a positive number (>= 0)'
      });
    }
    
    try {
      // USER REQUEST: If trip_type is 'Multiple-Trip-Vendor', force Drop rates for all segments
      // Otherwise, use segment-specific Pick/Drop logic based on source/destination
      // For frontend preview calls, trip_type is now passed from the frontend
      const result = await csvService.calculateInvoiceRate(
        source_location, 
        weight,
        destination_location || null, // Pass destination if provided
        trip_type || null // USER REQUEST: Pass trip_type to force Drop rates for Multiple Trip
      );
      
      res.json({
        success: true,
        invoice_amount: result.invoice_amount,
        toll_charges: result.toll_charges
      });
    } catch (error) {
      console.error('Calculate invoice rate error:', error);
      res.status(400).json({
        success: false,
        message: error.message || 'Failed to calculate invoice rate'
      });
    }
  } catch (error) {
    console.error('Calculate invoice rate endpoint error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/amend-order - Amend an existing order by adding new segments
router.post('/amend-order', async (req, res) => {
  try {
    const { orderId, newSegments, userId } = req.body;
    
    if (!orderId || !newSegments || !Array.isArray(newSegments) || newSegments.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Order ID and newSegments array are required'
      });
    }
    
    // Get user information for audit trail
    let amendmentRequestedBy = '';
    let amendmentRequestedDepartment = '';
    if (userId) {
      try {
        const user = await csvService.getUserById(userId.toString());
        if (user) {
          amendmentRequestedBy = user.full_name || user.fullName || '';
          amendmentRequestedDepartment = user.department || '';
        }
      } catch (error) {
        console.error('Error fetching user for amendment audit trail:', error);
      }
    }
    
    // Get existing order
    const order = await csvService.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    // Parse existing trip_segments
    let existingSegments = [];
    try {
      if (order.trip_segments && order.trip_segments.trim() !== '') {
        existingSegments = JSON.parse(order.trip_segments);
      }
    } catch (error) {
      console.error('Error parsing existing segments:', error);
      existingSegments = [];
    }
    
    // Determine if this is a Round Trip order
    const isRoundTrip = order.original_trip_type === 'Round-Trip-Vendor' || order.trip_type === 'Round-Trip-Vendor';
    // Get the original starting point from the first segment (unchanged)
    const originalStartingPoint = existingSegments.length > 0 
      ? existingSegments[0].source 
      : order.source;
    
    // For Round Trip: Validate that exactly ONE new segment is provided (B → C)
    if (isRoundTrip && (!Array.isArray(newSegments) || newSegments.length !== 1)) {
      console.log(`[Round Trip Amendment] Validation failed:`);
      console.log(`  Expected: 1 segment`);
      console.log(`  Received: ${Array.isArray(newSegments) ? newSegments.length : 'not an array'}`);
      return res.status(400).json({
        success: false,
        message: `Round Trip amendments require exactly one additional route (B → C). Please provide a single segment. Received: ${Array.isArray(newSegments) ? newSegments.length : 'not an array'} segments.`
      });
    }
    
    // Find highest segment_id
    let maxSegmentId = 0;
    if (existingSegments.length > 0) {
      maxSegmentId = Math.max(...existingSegments.map(s => parseInt(s.segment_id) || 0));
    }
    
    // Add new segments with sequential IDs
    const segmentsToAdd = newSegments.map((seg, index) => ({
      segment_id: maxSegmentId + index + 1,
      source: seg.source || '',
      destination: seg.destination || '',
      material_weight: parseInt(seg.material_weight) || 0,
      material_type: seg.material_type || '',
      segment_status: 'Pending',
      invoice_amount: seg.invoice_amount !== undefined ? parseInt(seg.invoice_amount) : undefined,
      toll_charges: seg.toll_charges !== undefined ? parseInt(seg.toll_charges) : undefined,
      is_manual_invoice: seg.is_manual_invoice || 'No'
    }));
    
    // For Round Trip: Validate that the new segment's source matches the outbound segment's destination (B)
    if (isRoundTrip && existingSegments.length >= 2) {
      // For Round Trip: Segment 1 is A → B (outbound), Segment 2 is B → A (return)
      // The new segment should start from B (destination of segment 1)
      const outboundSegment = existingSegments[0]; // Segment 1: A → B
      const newSegmentSource = segmentsToAdd[0].source;
      
      console.log(`[Round Trip Amendment] Source validation:`);
      console.log(`  Existing segments: ${existingSegments.length}`);
      console.log(`  Segment 1 (A → B): ${existingSegments[0].source} → ${existingSegments[0].destination}`);
      console.log(`  Segment 2 (B → A): ${existingSegments[1].source} → ${existingSegments[1].destination}`);
      console.log(`  Expected source (B): ${outboundSegment.destination}`);
      console.log(`  Received source: ${newSegmentSource}`);
      
      if (outboundSegment.destination !== newSegmentSource) {
        return res.status(400).json({
          success: false,
          message: `Round Trip amendment error: New segment must start from location B (${outboundSegment.destination}), but received ${newSegmentSource}. Please ensure the source matches the destination of the outbound segment (A → B).`
        });
      }
      
      console.log(`[Round Trip Amendment] ✓ Source validation passed`);
      console.log(`[Round Trip Amendment] Validating single segment insertion:`);
      console.log(`  Existing route: ${existingSegments[0].source} → ${existingSegments[0].destination} → ${existingSegments[1].destination}`);
      console.log(`  New segment: ${segmentsToAdd[0].source} → ${segmentsToAdd[0].destination}`);
      console.log(`  Expected result: ${existingSegments[0].source} → ${existingSegments[0].destination} → ${segmentsToAdd[0].destination} → ${originalStartingPoint}`);
    }
    
    // Calculate invoice_amount and toll_charges for new segments
    // Part 2: Multiple Trip Amendment - Use segment-specific Pick/Drop logic
    // For Round Trip: Use drop rates (source is vendor)
    // For Multiple Trip: Use segment-specific calculation (checks both source and destination)
    const isMultipleTrip = order.trip_type === 'Multiple-Trip-Vendor' || order.original_trip_type === 'Multiple-Trip-Vendor';
    
    for (let i = 0; i < segmentsToAdd.length; i++) {
      const segment = segmentsToAdd[i];
      const providedInvoice = segment.invoice_amount;
      const providedToll = segment.toll_charges;
      
      try {
        // Part 2: For Multiple Trip, use segment-specific calculation (checks both source and destination)
        // For Round Trip, use source-only calculation (backward compatible)
        let rateResult;
        if (isMultipleTrip) {
          // Multiple Trip: USER REQUEST - Always use Drop rates for all segments
          rateResult = await csvService.calculateInvoiceRate(
            segment.source, // Source location
            segment.material_weight, // Material weight
            segment.destination, // Destination location
            order.trip_type || order.original_trip_type // Pass tripType to force Drop rates
          );
        } else {
          // Round Trip: Use drop rates (source is vendor)
          rateResult = await csvService.calculateInvoiceRate(
            segment.source, // Vendor location (source for drop rates)
            segment.material_weight // Weight from amendment modal input
          );
        }
        
        console.log(`[Amendment Segment ${i + 1}] Calculated using drop rates:`);
        console.log(`  Source: ${segment.source} (Vendor - uses dropped_by_vendor rates)`);
        console.log(`  Weight: ${segment.material_weight} kg`);
        console.log(`  Invoice: ₹${rateResult.invoice_amount}`);
        console.log(`  Toll: ₹${rateResult.toll_charges}`);
        
        // If frontend provided values that differ from calculated, mark as manual override
        if (providedInvoice !== undefined && providedInvoice !== null &&
            providedInvoice !== rateResult.invoice_amount) {
          segment.invoice_amount = providedInvoice;
          segment.is_manual_invoice = 'Yes';
        } else {
          segment.invoice_amount = rateResult.invoice_amount;
          if (segment.is_manual_invoice !== 'Yes') {
            segment.is_manual_invoice = 'No';
          }
        }
        
        if (providedToll !== undefined && providedToll !== null &&
            providedToll !== rateResult.toll_charges) {
          segment.toll_charges = providedToll;
          if (segment.is_manual_invoice !== 'Yes') {
            segment.is_manual_invoice = 'Yes';
          }
        } else {
          segment.toll_charges = rateResult.toll_charges;
          if (segment.is_manual_invoice !== 'Yes') {
            segment.is_manual_invoice = 'No';
          }
        }
      } catch (error) {
        console.error(`Error calculating invoice rate for new segment ${i + 1}:`, error);
        segment.invoice_amount = providedInvoice !== undefined ? providedInvoice : 0;
        segment.toll_charges = providedToll !== undefined ? providedToll : 0;
        segment.is_manual_invoice = (providedInvoice !== undefined || providedToll !== undefined) ? 'Yes' : 'No';
      }
    }
    
    let updatedSegments = [];
    
    if (isRoundTrip) {
      // For Round Trip: Transform A → B → A into A → B → C → A
      // Part 1: Retrieve Segments - existingSegments contains [A→B, B→A]
      // Part 2: Define New Segment #2 (B → C) - segmentsToAdd[0] contains B → C
      // Part 3: Update Final Segment #3 (C → A) - update B → A to C → A with 0 weight/invoice
      
      // Find the return segment (the one that returns to original starting point)
      let returnSegmentIndex = -1;
      for (let i = existingSegments.length - 1; i >= 0; i--) {
        if (existingSegments[i].destination === originalStartingPoint) {
          returnSegmentIndex = i;
          break;
        }
      }
      
      if (returnSegmentIndex >= 0) {
        // Found return segment: Insert new segment BEFORE the return segment
        // Part 2: Round Trip Amendment Logic (A → B → C → A)
        
        // Part 1: Retrieve Segments - Preserve segment 1 (A → B) - unchanged, contributes to totals
        const segmentsBeforeReturn = existingSegments.slice(0, returnSegmentIndex);
        const originalSegment1 = segmentsBeforeReturn[0]; // Segment 1: A → B (chargeable)
        
        // Part 2: Define New Segment #2 (B → C) - Display Only
        // MUST carry original Segment 1's weight/invoice/toll for display, but NOT contribute to totals
        const newSegmentBtoC = segmentsToAdd[0]; // From amendment modal: B → C
        const displayOnlySegment = {
          segment_id: maxSegmentId + 1, // Sequential ID after Segment 1
          source: newSegmentBtoC.source, // B (from amendment modal)
          destination: newSegmentBtoC.destination, // C (from amendment modal)
          material_weight: originalSegment1.material_weight, // Part 2: MUST use original Segment 1 weight (for display)
          material_type: originalSegment1.material_type || newSegmentBtoC.material_type || '', // Use original or new
          segment_status: 'Pending',
          invoice_amount: originalSegment1.invoice_amount || 0, // Part 2: MUST use original Segment 1 invoice (for display)
          toll_charges: originalSegment1.toll_charges || 0, // Part 2: MUST use original Segment 1 toll (for display)
          is_manual_invoice: 'No' // Display-only segment
        };
        
        // Part 3: Define New Segment #3 (C → A) - New Chargeable Leg
        // MUST use amendment weight/invoice/toll and contribute to totals
        const truckCurrentLocation = newSegmentBtoC.destination; // C (destination of Segment 2)
        const chargeableReturnSegment = {
          segment_id: maxSegmentId + 2, // Sequential ID after Segment 2
          source: truckCurrentLocation, // C (truck's current location after amendment)
          destination: originalStartingPoint, // A (original starting point)
          material_weight: parseInt(newSegmentBtoC.material_weight) || 0, // Part 2: Use weight from amendment modal
          material_type: newSegmentBtoC.material_type || originalSegment1.material_type || '', // Use amendment or original
          segment_status: 'Pending',
          invoice_amount: parseInt(newSegmentBtoC.invoice_amount) || 0, // Part 2: Use invoice from amendment modal (calculated)
          toll_charges: parseInt(newSegmentBtoC.toll_charges) || 0, // Part 2: Use toll from amendment modal
          is_manual_invoice: newSegmentBtoC.is_manual_invoice || 'No'
        };
        
        // Part 4: Rebuild Array - Final structure: [Segment #1 (A → B), Segment #2 (B → C) display-only, Segment #3 (C → A) chargeable]
        updatedSegments = [...segmentsBeforeReturn, displayOnlySegment, chargeableReturnSegment];
        
        console.log(`[Round Trip Amendment] Transforming route:`);
        console.log(`  Original route: ${originalSegment1.source} → ${originalSegment1.destination} → ${originalStartingPoint}`);
        console.log(`  Segment 1 (A → B): Unchanged, contributes to totals`);
        console.log(`  Segment 2 (B → C): Display only - Weight: ${displayOnlySegment.material_weight} kg (original), Invoice: ₹${displayOnlySegment.invoice_amount} (original), NOT in totals`);
        console.log(`  Segment 3 (C → A): Chargeable - Weight: ${chargeableReturnSegment.material_weight} kg (amendment), Invoice: ₹${chargeableReturnSegment.invoice_amount} (amendment), IN totals`);
        console.log(`  Final route: ${originalSegment1.source} → ${originalSegment1.destination} → ${truckCurrentLocation} → ${originalStartingPoint}`);
        
        console.log(`[Round Trip Amendment] Final segment array:`);
        updatedSegments.forEach((seg, idx) => {
          const contribution = (idx === 0 || idx === 2) ? 'CONTRIBUTES' : 'DISPLAY ONLY';
          console.log(`  Segment #${idx + 1} (ID: ${seg.segment_id}): ${seg.source} → ${seg.destination} (${seg.material_weight} kg, ₹${seg.invoice_amount}) [${contribution}]`);
        });
      } else {
        // No return segment found (shouldn't happen for Round Trip, but handle gracefully)
        // Append new segments and add return segment at end
        updatedSegments = [...existingSegments, ...segmentsToAdd];
        const lastSegment = updatedSegments[updatedSegments.length - 1];
        if (lastSegment.destination !== originalStartingPoint) {
          // MANDATORY: Create new return segment with 0 weight and 0 invoice
          console.log(`[Round Trip Amendment] Creating new return segment with 0 weight and 0 invoice`);
          console.log(`  Return route: ${lastSegment.destination} → ${originalStartingPoint}`);
          
          updatedSegments.push({
            segment_id: maxSegmentId + segmentsToAdd.length + 1,
            source: lastSegment.destination,
            destination: originalStartingPoint,
            material_weight: 0, // MANDATORY: Always 0
            material_type: lastSegment.material_type || '',
            segment_status: 'Pending',
            invoice_amount: 0, // MANDATORY: Always 0
            toll_charges: 0, // MANDATORY: Always 0
            is_manual_invoice: 'No'
          });
        }
      }
    } else {
      // Part 2: For Multiple Trip: Simply append new segments (no complex manipulation)
      // All segments contribute to totals - simple addition
      updatedSegments = [...existingSegments, ...segmentsToAdd];
      
      // Part 2: For Multiple Trip amendments, log the simple addition
      if (isMultipleTrip) {
        console.log(`[Multiple Trip Amendment] Adding ${segmentsToAdd.length} new segment(s):`);
        segmentsToAdd.forEach((seg, idx) => {
          console.log(`  New Segment #${existingSegments.length + idx + 1} (ID: ${seg.segment_id}): ${seg.source} → ${seg.destination} (${seg.material_weight} kg, ₹${seg.invoice_amount}) - CONTRIBUTES to totals`);
        });
        console.log(`  Total segments after amendment: ${updatedSegments.length}`);
      }
    }
    
    // Calculate original totals (before amendment) for comparison in approval summary
    // Use original trip type for accurate calculation
    const orderTripType = order.original_trip_type || order.trip_type || 'Single-Trip-Vendor';
    const originalTotals = csvService.calculateOrderTotals(existingSegments, orderTripType);
    
    // Recalculate order category after amendment
    const orderCategory = csvService.calculateOrderCategory(updatedSegments);
    
    // Recalculate totals with updated segments (projected totals after approval)
    // For Round Trip: Only Segment 1 and final segment contribute (middle segments are display-only)
    const projectedTotals = csvService.calculateOrderTotals(updatedSegments, orderTripType);
    
    // Determine final destination based on trip type
    let finalDestination = updatedSegments[updatedSegments.length - 1]?.destination || order.destination || '';
    if (order.original_trip_type === 'Round-Trip-Vendor' || order.trip_type === 'Round-Trip-Vendor') {
      // Round trips always end at original starting point
      finalDestination = updatedSegments[0]?.source || order.source || '';
    }
    
    // Store original segment count for identifying new segments in approval modal
    const originalSegmentCount = existingSegments.length;
    
    // Initialize workflow for any new segments (regardless of current order status)
    for (let i = originalSegmentCount; i < updatedSegments.length; i++) {
      const segment = updatedSegments[i];
      if (!segment.workflow || !Array.isArray(segment.workflow) || segment.workflow.length === 0) {
        const location = segment.destination || segment.source || '';
        segment.workflow = csvService.initializeSegmentWorkflow(segment, location);
        segment.segment_status = 'SECURITY_ENTRY_PENDING';
      }
    }
    
    // Generate change log for this amendment
    const changeLog = [];
    
    // Track segment count change
    if (updatedSegments.length !== existingSegments.length) {
      changeLog.push(`Segment count changed from ${existingSegments.length} to ${updatedSegments.length}`);
    }
    
    // Track new segments added
    const newSegmentsAdded = updatedSegments.slice(originalSegmentCount);
    if (newSegmentsAdded.length > 0) {
      newSegmentsAdded.forEach((seg, idx) => {
        const segmentNum = originalSegmentCount + idx + 1;
        const route = `${seg.source} → ${seg.destination}`;
        const weight = seg.material_weight || 0;
        const materialType = seg.material_type || 'N/A';
        changeLog.push(`Added Segment #${segmentNum}: ${route} (${weight} kg, Type: ${materialType})`);
      });
    }
    
    // Track changes in existing segments (if any were modified)
    for (let i = 0; i < Math.min(existingSegments.length, updatedSegments.length); i++) {
      const oldSeg = existingSegments[i];
      const newSeg = updatedSegments[i];
      const segmentChanges = [];
      
      if (oldSeg.source !== newSeg.source) {
        segmentChanges.push(`Starting Point changed from '${oldSeg.source}' to '${newSeg.source}'`);
      }
      if (oldSeg.destination !== newSeg.destination) {
        segmentChanges.push(`End Point changed from '${oldSeg.destination}' to '${newSeg.destination}'`);
      }
      if ((oldSeg.material_weight || 0) !== (newSeg.material_weight || 0)) {
        segmentChanges.push(`Material Weight changed from ${oldSeg.material_weight || 0} kg to ${newSeg.material_weight || 0} kg`);
      }
      if (oldSeg.material_type !== newSeg.material_type) {
        segmentChanges.push(`Material Type changed from '${oldSeg.material_type || 'N/A'}' to '${newSeg.material_type || 'N/A'}'`);
      }
      if ((oldSeg.invoice_amount || 0) !== (newSeg.invoice_amount || 0)) {
        segmentChanges.push(`Freight Charges changed from ₹${oldSeg.invoice_amount || 0} to ₹${newSeg.invoice_amount || 0}`);
      }
      
      if (segmentChanges.length > 0) {
        changeLog.push(`Segment #${i + 1} modifications: ${segmentChanges.join('; ')}`);
      }
    }
    
    // Track total changes
    if (originalTotals.total_weight !== projectedTotals.total_weight) {
      changeLog.push(`Total Weight changed from ${originalTotals.total_weight} kg to ${projectedTotals.total_weight} kg`);
    }
    if (originalTotals.total_invoice_amount !== projectedTotals.total_invoice_amount) {
      changeLog.push(`Total Freight Charges changed from ₹${originalTotals.total_invoice_amount} to ₹${projectedTotals.total_invoice_amount}`);
    }
    
    // If no specific changes detected, add generic message
    if (changeLog.length === 0) {
      changeLog.push(`Order amended with ${newSegmentsAdded.length} new segment(s)`);
    }
    
    // Parse existing amendment history
    let amendmentHistory = [];
    try {
      if (order.amendment_history && order.amendment_history.trim() !== '') {
        amendmentHistory = JSON.parse(order.amendment_history);
      }
    } catch (error) {
      console.error('Error parsing existing amendment history:', error);
      amendmentHistory = [];
    }
    
    // Calculate next version number
    const versionNumber = amendmentHistory.length + 1;
    
    // Create new amendment entry
    const newAmendment = {
      version: `V${versionNumber}`,
      timestamp: csvService.getISTTimestamp(),
      amendedBy: amendmentRequestedBy || 'Unknown',
      amendedByDepartment: amendmentRequestedDepartment || 'Unknown',
      amendedByUserId: userId ? userId.toString() : '',
      changeLog: changeLog,
      segmentsBefore: existingSegments.length,
      segmentsAfter: updatedSegments.length,
      totalWeightBefore: originalTotals.total_weight,
      totalWeightAfter: projectedTotals.total_weight,
      totalInvoiceBefore: originalTotals.total_invoice_amount,
      totalInvoiceAfter: projectedTotals.total_invoice_amount
    };
    
    // Append to history
    amendmentHistory.push(newAmendment);
    
    // Update order: set status to 'Open', mark as amended, add audit trail
    // CRITICAL FIX: Add lastAmendedByUserId and lastAmendedTimestamp for tracking
    const now = csvService.getISTTimestamp();
    const updatedOrder = {
      ...order,
      trip_segments: updatedSegments,
      order_status: 'Open', // Reset to Open requiring re-approval
      is_amended: 'Yes',
      order_category: orderCategory, // Recalculate category
      total_weight: projectedTotals.total_weight.toString(),
      total_invoice_amount: projectedTotals.total_invoice_amount.toString(),
      total_toll_charges: projectedTotals.total_toll_charges.toString(),
      // Store original totals for approval summary comparison
      original_total_weight: originalTotals.total_weight.toString(),
      original_total_invoice_amount: originalTotals.total_invoice_amount.toString(),
      original_total_toll_charges: originalTotals.total_toll_charges.toString(),
      original_segment_count: originalSegmentCount.toString(),
      // Audit trail fields for amendment
      amendment_requested_by: amendmentRequestedBy || '',
      amendment_requested_department: amendmentRequestedDepartment || '',
      amendment_requested_at: now,
      // CRITICAL FIX: Track last amendment user and timestamp
      last_amended_by_user_id: userId ? userId.toString() : '',
      last_amended_timestamp: now,
      // Amendment history (JSON array of all amendments)
      amendment_history: JSON.stringify(amendmentHistory),
      // Keep original_trip_type unchanged
      // Update source/destination from first/last segment
      source: updatedSegments[0]?.source || order.source || '',
      destination: finalDestination
    };
    
    // Save updated order
    await csvService.writeOrder(updatedOrder);
    
    res.json({
      success: true,
      message: 'Order amended successfully. Status reset to Open for re-approval.',
      order: {
        ...updatedOrder,
        trip_segments: updatedSegments // Return as array
      }
    });
  } catch (error) {
    console.error('Amend order error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/initialize-workflow - Initialize workflow for an order
router.post('/initialize-workflow', async (req, res) => {
  try {
    const { orderId } = req.body;
    
    if (!orderId) {
      return res.status(400).json({
        success: false,
        message: 'Order ID is required'
      });
    }
    
    // Get order
    const order = await csvService.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    // Parse trip_segments
    let segments = [];
    try {
      if (order.trip_segments && order.trip_segments.trim() !== '') {
        segments = JSON.parse(order.trip_segments);
      }
    } catch (error) {
      console.error('Error parsing segments:', error);
      return res.status(400).json({
        success: false,
        message: 'Invalid trip segments format'
      });
    }
    
    // Initialize workflow for each segment
    for (let i = 0; i < segments.length; i++) {
      const segment = segments[i];
      
      // CRITICAL FIX: Migrate existing 3-stage workflows to 6-stage format
      if (segment.workflow && Array.isArray(segment.workflow) && segment.workflow.length === 3) {
        // Old format detected: migrate to 6 stages
        const oldWorkflow = segment.workflow;
        const originLocation = segment.source || '';
        const destinationLocation = segment.destination || '';
        
        // Create new 6-stage workflow
        const newWorkflow = csvService.initializeSegmentWorkflow(segment);
        
        // Preserve existing approval statuses for destination stages (indices 3-5)
        // Map old stages to new destination stages
        for (let j = 0; j < oldWorkflow.length; j++) {
          const oldStage = oldWorkflow[j];
          const newStageIndex = j + 3; // Destination stages start at index 3
          if (newWorkflow[newStageIndex]) {
            // Preserve status, approved_by, department, timestamp, comments
            newWorkflow[newStageIndex].status = oldStage.status || 'PENDING';
            newWorkflow[newStageIndex].approved_by = oldStage.approved_by || '';
            newWorkflow[newStageIndex].department = oldStage.department || '';
            newWorkflow[newStageIndex].timestamp = oldStage.timestamp || Date.now();
            newWorkflow[newStageIndex].comments = oldStage.comments || '';
          }
        }
        
        segment.workflow = newWorkflow;
        console.log(`[Migration] Migrated segment ${segment.segment_id} from 3-stage to 6-stage workflow`);
      } else if (!segment.workflow || !Array.isArray(segment.workflow) || segment.workflow.length === 0) {
        // No workflow exists: initialize new 6-stage workflow
        segment.workflow = csvService.initializeSegmentWorkflow(segment);
        
        // For first segment, set first stage status based on order status
        if (i === 0 && order.order_status === 'En-Route') {
          // First segment's origin SECURITY_ENTRY (index 0) is active
          if (segment.workflow[0]) {
            segment.workflow[0].status = 'PENDING';
          }
        }
      }
    }
    
    // Update order with workflow-initialized segments
    const updatedOrder = {
      ...order,
      trip_segments: segments
    };
    
    // Save order
    await csvService.writeOrder(updatedOrder);
    
    res.json({
      success: true,
      message: 'Workflow initialized successfully',
      order: {
        ...updatedOrder,
        trip_segments: segments
      }
    });
  } catch (error) {
    console.error('Initialize workflow error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// POST /api/workflow-action - Perform workflow action (approve/reject/revoke/cancel)
router.post('/workflow-action', async (req, res) => {
  try {
    const { orderId, segmentId, stage, action, userId, comments, location } = req.body;
    
    if (!orderId || !segmentId || !stage || !action || !userId) {
      return res.status(400).json({
        success: false,
        message: 'Order ID, Segment ID, Stage, Action, and User ID are required'
      });
    }
    
    // Get user information
    let userDepartment = '';
    let userRole = '';
    let userName = '';
    try {
      const user = await csvService.getUserById(userId.toString());
      if (user) {
        userDepartment = user.department || '';
        userRole = csvService.getRoleByDepartment(userDepartment) || '';
        userName = user.full_name || user.fullName || '';
      }
    } catch (error) {
      console.error('Error fetching user:', error);
    }
    
    // Get order
    const order = await csvService.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({
        success: false,
        message: 'Order not found'
      });
    }
    
    // Parse trip_segments
    let segments = [];
    try {
      if (order.trip_segments && order.trip_segments.trim() !== '') {
        segments = JSON.parse(order.trip_segments);
      }
    } catch (error) {
      console.error('Error parsing segments:', error);
      return res.status(400).json({
        success: false,
        message: 'Invalid trip segments format'
      });
    }
    
    // Find segment
    const segmentIndex = segments.findIndex(s => parseInt(s.segment_id) === parseInt(segmentId));
    if (segmentIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Segment not found'
      });
    }
    
    const segment = segments[segmentIndex];
    
    // Parse workflow steps
    let workflowSteps = [];
    if (segment.workflow) {
      if (Array.isArray(segment.workflow)) {
        workflowSteps = segment.workflow;
      } else if (typeof segment.workflow === 'string') {
        try {
          workflowSteps = JSON.parse(segment.workflow);
        } catch (e) {
          workflowSteps = [];
        }
      }
    }
    
    // Validate action
    if (action === 'REJECT' && (!comments || comments.trim() === '')) {
      return res.status(400).json({
        success: false,
        message: 'Comments are required for rejection'
      });
    }
    
    // Check if user can perform action
    if (!csvService.canPerformWorkflowAction(userDepartment, userRole, stage, action)) {
      return res.status(403).json({
        success: false,
        message: 'User does not have permission to perform this action'
      });
    }
    
    // Sort workflow steps by stage_index to ensure correct order
    workflowSteps.sort((a, b) => {
      const indexA = a.stage_index !== undefined ? a.stage_index : 999;
      const indexB = b.stage_index !== undefined ? b.stage_index : 999;
      return indexA - indexB;
    });
    
    // CRITICAL FIX: Find workflow step by both stage name AND location
    // This is necessary because we now have 6 stages (3 origin + 3 destination) with same stage names
    const stepIndex = workflowSteps.findIndex(ws => 
      ws.stage === stage && 
      (!location || ws.location === location)
    );
    if (stepIndex === -1) {
      return res.status(404).json({
        success: false,
        message: 'Workflow step not found'
      });
    }
    
    const workflowStep = workflowSteps[stepIndex];
    
    // Handle CANCEL action
    if (action === 'CANCEL') {
      // CRITICAL FIX: Record complete audit trail for cancellation
      const cancelTimestamp = Date.now();
      const cancelDateTime = csvService.getISTTimestamp();
      
      // Update order status to CANCELED
      order.order_status = 'CANCELED';
      
      // Add CANCELED workflow step
      workflowStep.status = 'CANCELED';
      workflowStep.approved_by = userName || 'Unknown';
      workflowStep.department = userDepartment || 'Unknown';
      workflowStep.timestamp = cancelTimestamp;
      workflowStep.comments = comments || 'Order canceled';
      workflowStep.location = segment.destination || segment.source || '';
      
      // CRITICAL FIX: Log audit trail
      console.log(`[Workflow Audit] CANCELLED - Stage: ${stage}, Order: ${orderId}, Segment: ${segmentId}`);
      console.log(`  Cancelled By: ${userName}`);
      console.log(`  Canceller Department: ${userDepartment}`);
      console.log(`  Date/Time: ${cancelDateTime}`);
      console.log(`  Cancellation Reason: ${comments || 'Not provided'}`);
      
      // Update segment status
      segment.segment_status = 'CANCELED';
      
      // Save order
      await csvService.writeOrder(order);
      
      return res.json({
        success: true,
        message: 'Order canceled successfully',
        order: {
          ...order,
          trip_segments: segments
        }
      });
    }
    
    // Handle REVOKE action
    if (action === 'REVOKE') {
      if (workflowStep.status !== 'REJECTED') {
        return res.status(400).json({
          success: false,
          message: 'Can only revoke rejected stages'
        });
      }
      
      // CRITICAL FIX: Record complete audit trail for revocation
      const revokeTimestamp = Date.now();
      const revokeDateTime = csvService.getISTTimestamp();
      
      // Sort workflow steps by stage_index to ensure correct order
      workflowSteps.sort((a, b) => {
        const indexA = a.stage_index !== undefined ? a.stage_index : 999;
        const indexB = b.stage_index !== undefined ? b.stage_index : 999;
        return indexA - indexB;
      });
      
      // Get current stage index
      const currentStepIndex = stepIndex;
      
      // CRITICAL FIX: Reset to PENDING
      workflowStep.status = 'PENDING';
      workflowStep.approved_by = userName || 'Unknown'; // Keep who revoked for audit
      workflowStep.department = userDepartment || 'Unknown'; // Keep department for audit
      workflowStep.timestamp = revokeTimestamp;
      workflowStep.comments = comments || 'Rejection revoked';
      workflowStep.location = workflowStep.location || segment.destination || segment.source || '';
      
      // CRITICAL FIX: Reset downstream stages that were APPROVED after this stage
      // When a stage is rejected, downstream stages are blocked. When we revoke,
      // we need to reset any downstream APPROVED stages back to PENDING so they
      // can be re-approved in the correct sequence.
      for (let i = currentStepIndex + 1; i < workflowSteps.length; i++) {
        const downstreamStage = workflowSteps[i];
        if (downstreamStage && downstreamStage.status === 'APPROVED') {
          console.log(`[Revoke] Resetting downstream stage ${i} (${downstreamStage.stage}) from APPROVED to PENDING`);
          downstreamStage.status = 'PENDING';
          downstreamStage.approved_by = '';
          downstreamStage.department = '';
          downstreamStage.comments = '';
          downstreamStage.timestamp = Date.now();
        }
      }
      
      // CRITICAL FIX: Log audit trail
      console.log(`[Workflow Audit] REVOKED - Stage: ${stage}, Order: ${orderId}, Segment: ${segmentId}`);
      console.log(`  Revoked By: ${userName}`);
      console.log(`  Revoker Department: ${userDepartment}`);
      console.log(`  Date/Time: ${revokeDateTime}`);
      console.log(`  Revocation Reason: ${comments || 'Not provided'}`);
      console.log(`  Downstream stages reset to PENDING`);
      
      // Update segment status based on stage position
      const isOriginLocation = currentStepIndex < 3; // Stages 0-2 are origin
      const isDestinationLocation = currentStepIndex >= 3; // Stages 3-5 are destination
      
      if (stage === 'SECURITY_ENTRY') {
        if (isOriginLocation) {
          segment.segment_status = 'SECURITY_ENTRY_PENDING';
        } else {
          segment.segment_status = 'SECURITY_ENTRY_PENDING';
        }
      } else if (stage === 'STORES_VERIFICATION') {
        segment.segment_status = 'STORES_VERIFICATION_PENDING';
      } else if (stage === 'SECURITY_EXIT') {
        segment.segment_status = 'SECURITY_EXIT_PENDING';
      }
    }
    
    // CRITICAL FIX: Record complete audit trail for all workflow actions
    const auditTimestamp = Date.now();
    const auditDateTime = csvService.getISTTimestamp();
    
    // CRITICAL FIX: Ensure all audit fields are properly set
    // Handle APPROVE action
    if (action === 'APPROVE') {
      workflowStep.status = 'APPROVED';
      workflowStep.approved_by = userName || 'Unknown';
      workflowStep.department = userDepartment || 'Unknown';
      workflowStep.timestamp = auditTimestamp;
      workflowStep.comments = comments || '';
      // CRITICAL FIX: Preserve location from workflow step (origin or destination)
      workflowStep.location = workflowStep.location || location || segment.destination || segment.source || '';
      
      // CRITICAL FIX: Log audit trail
      console.log(`[Workflow Audit] APPROVED - Stage: ${stage}, Order: ${orderId}, Segment: ${segmentId}`);
      console.log(`  Approver Name: ${userName}`);
      console.log(`  Approver Department: ${userDepartment}`);
      console.log(`  Date/Time: ${auditDateTime}`);
      console.log(`  Comments: ${comments || 'None'}`);
      
      // Capture audit fields based on workflow stage
      // Check if this is the first SECURITY_ENTRY approval across all segments
      if (stage === 'SECURITY_ENTRY') {
        let isFirstSecurityEntry = true;
        for (let i = 0; i < segments.length; i++) {
          const seg = segments[i];
          let segWorkflowSteps = [];
          if (seg.workflow) {
            if (Array.isArray(seg.workflow)) {
              segWorkflowSteps = seg.workflow;
            } else if (typeof seg.workflow === 'string') {
              try {
                segWorkflowSteps = JSON.parse(seg.workflow);
              } catch (e) {
                segWorkflowSteps = [];
              }
            }
          }
          const securityEntryStep = segWorkflowSteps.find(ws => ws.stage === 'SECURITY_ENTRY');
          // Check if any previous segment has an approved SECURITY_ENTRY
          if (i < segmentIndex && securityEntryStep && securityEntryStep.status === 'APPROVED') {
            isFirstSecurityEntry = false;
            break;
          }
        }
        
        // Capture Vehicle/Facility Execution and Entry/Security Checkpoint data
        if (isFirstSecurityEntry) {
          order.vehicle_started_at_timestamp = auditDateTime;
          order.vehicle_started_from_location = segment.source || workflowStep.location || '';
          order.security_entry_timestamp = auditDateTime;
          order.security_entry_member_name = userName || '';
          order.security_entry_checkpoint_location = workflowStep.location || segment.source || '';
          console.log(`[Audit] Captured Vehicle Start and Security Entry for order ${orderId}`);
        }
      }
      
      // Capture Stores/Validation Checkpoint data (first STORES_VERIFICATION approval)
      if (stage === 'STORES_VERIFICATION') {
        let isFirstStoresVerification = true;
        for (let i = 0; i < segments.length; i++) {
          const seg = segments[i];
          let segWorkflowSteps = [];
          if (seg.workflow) {
            if (Array.isArray(seg.workflow)) {
              segWorkflowSteps = seg.workflow;
            } else if (typeof seg.workflow === 'string') {
              try {
                segWorkflowSteps = JSON.parse(seg.workflow);
              } catch (e) {
                segWorkflowSteps = [];
              }
            }
          }
          const storesStep = segWorkflowSteps.find(ws => ws.stage === 'STORES_VERIFICATION');
          if (i < segmentIndex && storesStep && storesStep.status === 'APPROVED') {
            isFirstStoresVerification = false;
            break;
          }
        }
        
        if (isFirstStoresVerification) {
          order.stores_validation_timestamp = auditDateTime;
          console.log(`[Audit] Captured Stores Validation for order ${orderId}`);
        }
      }
      
      // Capture Exit/Completion data (last SECURITY_EXIT approval - last segment, last stage)
      if (stage === 'SECURITY_EXIT') {
        const isLastSegment = segmentIndex === segments.length - 1;
        if (isLastSegment) {
          order.vehicle_exited_timestamp = auditDateTime;
          order.exit_approved_by_timestamp = auditDateTime;
          order.exit_approved_by_member_name = userName || '';
          console.log(`[Audit] Captured Vehicle Exit and Completion for order ${orderId}`);
        }
      }
      
      // CRITICAL FIX: Update segment status based on 6-stage workflow progression
      // Sort workflow steps by stage_index to ensure correct order
      workflowSteps.sort((a, b) => {
        const indexA = a.stage_index !== undefined ? a.stage_index : 999;
        const indexB = b.stage_index !== undefined ? b.stage_index : 999;
        return indexA - indexB;
      });
      
      const currentStepIndex = stepIndex;
      const isOriginLocation = currentStepIndex < 3; // Stages 0-2 are origin
      const isDestinationLocation = currentStepIndex >= 3; // Stages 3-5 are destination
      
      if (stage === 'SECURITY_ENTRY') {
        if (isOriginLocation) {
          segment.segment_status = 'STORES_VERIFICATION_PENDING';
        } else {
          // Destination SECURITY_ENTRY approved, activate STORES_VERIFICATION
          segment.segment_status = 'STORES_VERIFICATION_PENDING';
        }
      } else if (stage === 'STORES_VERIFICATION') {
        if (isOriginLocation) {
          segment.segment_status = 'SECURITY_EXIT_PENDING';
        } else {
          // Destination STORES_VERIFICATION approved, activate SECURITY_EXIT
          segment.segment_status = 'SECURITY_EXIT_PENDING';
        }
      } else if (stage === 'SECURITY_EXIT') {
        if (isOriginLocation) {
          // Origin SECURITY_EXIT approved, activate destination SECURITY_ENTRY
          const destinationSecurityEntry = workflowSteps.find(ws => 
            ws.stage === 'SECURITY_ENTRY' && ws.stage_index === 3
          );
          if (destinationSecurityEntry) {
            destinationSecurityEntry.status = 'PENDING';
            segment.segment_status = 'SECURITY_ENTRY_PENDING';
          }
        } else {
          // Destination SECURITY_EXIT approved, segment is completed
          segment.segment_status = 'COMPLETED';
          
          // Activate next segment's origin SECURITY_ENTRY if exists
          if (segmentIndex + 1 < segments.length) {
            const nextSegment = segments[segmentIndex + 1];
            let nextWorkflowSteps = [];
            if (nextSegment.workflow) {
              if (Array.isArray(nextSegment.workflow)) {
                nextWorkflowSteps = nextSegment.workflow;
              } else if (typeof nextSegment.workflow === 'string') {
                try {
                  nextWorkflowSteps = JSON.parse(nextSegment.workflow);
                } catch (e) {
                  nextWorkflowSteps = [];
                }
              }
            }
            
            // Initialize workflow if not exists
            if (nextWorkflowSteps.length === 0) {
              nextWorkflowSteps = csvService.initializeSegmentWorkflow(nextSegment);
              nextSegment.workflow = nextWorkflowSteps;
            }
            
            // Sort next segment workflow steps by stage_index
            nextWorkflowSteps.sort((a, b) => {
              const indexA = a.stage_index !== undefined ? a.stage_index : 999;
              const indexB = b.stage_index !== undefined ? b.stage_index : 999;
              return indexA - indexB;
            });
            
            // Activate origin SECURITY_ENTRY (stage_index 0)
            const nextOriginSecurityEntry = nextWorkflowSteps.find(ws => 
              ws.stage === 'SECURITY_ENTRY' && ws.stage_index === 0
            );
            if (nextOriginSecurityEntry) {
              nextOriginSecurityEntry.status = 'PENDING';
              nextSegment.segment_status = 'SECURITY_ENTRY_PENDING';
            }
          }
        }
      }
    }
    
    // Handle REJECT action
    if (action === 'REJECT') {
      // Validation: Block rejection after final approval
      const isCompleted = csvService.isOrderCompleted(order, segments);
      if (isCompleted) {
        return res.status(400).json({
          success: false,
          message: 'Order cannot be rejected after all approval stages have been completed'
        });
      }
      
      workflowStep.status = 'REJECTED';
      workflowStep.approved_by = userName || 'Unknown';
      workflowStep.department = userDepartment || 'Unknown';
      workflowStep.timestamp = auditTimestamp;
      workflowStep.comments = comments || 'Rejection reason not provided';
      workflowStep.location = segment.destination || segment.source || '';
      
      // CRITICAL FIX: Log audit trail
      console.log(`[Workflow Audit] REJECTED - Stage: ${stage}, Order: ${orderId}, Segment: ${segmentId}`);
      console.log(`  Rejector Name: ${userName}`);
      console.log(`  Rejector Department: ${userDepartment}`);
      console.log(`  Date/Time: ${auditDateTime}`);
      console.log(`  Rejection Reason: ${comments || 'Not provided'}`);
      
      // Update segment status
      if (stage === 'SECURITY_ENTRY') {
        segment.segment_status = 'SECURITY_ENTRY_REJECTED';
      } else if (stage === 'STORES_VERIFICATION') {
        segment.segment_status = 'STORES_VERIFICATION_REJECTED';
      } else if (stage === 'SECURITY_EXIT') {
        segment.segment_status = 'SECURITY_EXIT_REJECTED';
      }
    }
    
    // Update workflow step
    workflowSteps[stepIndex] = workflowStep;
    segment.workflow = workflowSteps;
    segments[segmentIndex] = segment;
    
    // CRITICAL FIX: Update order's trip_segments BEFORE checking completion status
    // This ensures the completion check uses the most up-to-date workflow data
    order.trip_segments = JSON.stringify(segments);
    
    // CRITICAL FIX: Check if order workflow is completed or rejected and update order status
    const isOrderRejected = csvService.isOrderRejected(order, segments);
    const isOrderCompleted = csvService.isOrderCompleted(order, segments);
    
    // Enhanced logging for debugging completion detection
    console.log(`[Workflow Status Check] Order ${orderId}:`);
    console.log(`  Current status: ${order.order_status}`);
    console.log(`  Is rejected: ${isOrderRejected}`);
    console.log(`  Is completed: ${isOrderCompleted}`);
    console.log(`  Segments count: ${segments.length}`);
    segments.forEach((seg, idx) => {
      const segWorkflow = Array.isArray(seg.workflow) ? seg.workflow : 
        (typeof seg.workflow === 'string' ? JSON.parse(seg.workflow) : []);
      const approvedCount = segWorkflow.filter(ws => 
        (ws.status || '').toUpperCase().trim() === 'APPROVED' || 
        (ws.status || '').toUpperCase().trim() === 'COMPLETED'
      ).length;
      console.log(`  Segment ${idx + 1}: ${approvedCount}/${segWorkflow.length} stages approved`);
    });
    
    // Normalize current status for case-insensitive comparison
    const currentStatus = (order.order_status || '').toUpperCase().trim();
    
    if (isOrderRejected && currentStatus !== 'REJECTED' && currentStatus !== 'CANCELLED' && currentStatus !== 'CANCELED') {
      console.log(`[Workflow Status Update] Order ${orderId} workflow is REJECTED - updating order status to REJECTED`);
      order.order_status = 'REJECTED';
      // Also free the vehicle when order is rejected
      if (order.vehicle_id) {
        try {
          await csvService.updateVehicleStatus(order.vehicle_id, 'Free');
        } catch (error) {
          console.error('Error freeing vehicle on rejection:', error);
        }
      }
    } else if (isOrderCompleted && currentStatus !== 'COMPLETED' && currentStatus !== 'REJECTED' && currentStatus !== 'CANCELLED' && currentStatus !== 'CANCELED') {
      console.log(`[Status Sync] Order ${orderId}: All segments approved. Forcing primary status to COMPLETED.`);
      console.log(`[Workflow Status Update] Order ${orderId} workflow is COMPLETED - updating order status to COMPLETED`);
      console.log(`[Workflow Status Update] Previous status: ${order.order_status}, New status: COMPLETED`);
      order.order_status = 'COMPLETED';
      
      // CRITICAL: Automatically free the vehicle when order is completed
      if (order.vehicle_id && order.vehicle_id.trim() !== '') {
        try {
          await csvService.updateVehicleStatus(order.vehicle_id, 'Free');
          console.log(`[Status Sync] Vehicle ${order.vehicle_id} automatically freed for completed order ${orderId}`);
        } catch (error) {
          console.error(`[Status Sync] Error freeing vehicle ${order.vehicle_id}:`, error);
        }
      }
    } else if (isOrderCompleted && currentStatus === 'COMPLETED') {
      console.log(`[Workflow Status Check] Order ${orderId} is already COMPLETED - no status change needed`);
      // Ensure vehicle is freed even if status was already COMPLETED
      if (order.vehicle_id && order.vehicle_id.trim() !== '' && currentStatus === 'COMPLETED') {
        try {
          const vehicle = await csvService.getVehicleById(order.vehicle_id);
          if (vehicle && vehicle.is_busy === true) {
            await csvService.updateVehicleStatus(order.vehicle_id, 'Free');
            console.log(`[Status Sync] Vehicle ${order.vehicle_id} freed (was already COMPLETED but vehicle still booked)`);
          }
        } catch (error) {
          console.error(`[Status Sync] Error checking/freeing vehicle:`, error);
        }
      }
    } else if (!isOrderCompleted) {
      console.log(`[Workflow Status Check] Order ${orderId} is not yet completed - remaining in ${order.order_status}`);
    }
    
    // Update order - order object already has audit fields updated above
    const updatedOrder = {
      ...order,
      trip_segments: JSON.stringify(segments) // Ensure segments are serialized
    };
    
    // Save order
    await csvService.writeOrder(updatedOrder);
    
    res.json({
      success: true,
      message: `Workflow action ${action} performed successfully`,
      order: {
        ...updatedOrder,
        trip_segments: segments
      }
    });
  } catch (error) {
    console.error('Workflow action error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// GET /api/notifications/department/:department - Get notifications for a department
router.get('/notifications/department/:department', async (req, res) => {
  try {
    const { department } = req.params;
    const notifications = await csvService.getNotificationsByDepartment(department);
    
    res.json({
      success: true,
      notifications: notifications
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/notifications/user/:userId - Get notifications for user's department
router.get('/notifications/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await csvService.getUserById(userId);
    
    if (!user || !user.department) {
      return res.status(404).json({
        success: false,
        message: 'User not found or department not set'
      });
    }
    
    const notifications = await csvService.getNotificationsByDepartment(user.department);
    
    res.json({
      success: true,
      notifications: notifications
    });
  } catch (error) {
    console.error('Get user notifications error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/notifications/:notificationId/read - Mark notification as read
router.post('/notifications/:notificationId/read', async (req, res) => {
  try {
    const { notificationId } = req.params;
    const notification = await csvService.markNotificationAsRead(notificationId);
    
    res.json({
      success: true,
      message: 'Notification marked as read',
      notification: notification
    });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

// GET /api/notifications/unread-count/:department - Get unread count for a department
router.get('/notifications/unread-count/:department', async (req, res) => {
  try {
    const { department } = req.params;
    const count = await csvService.getUnreadNotificationCount(department);
    
    res.json({
      success: true,
      count: count
    });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/fix-completed-orders - Retroactive fix for orders that are completed but still marked En-Route
router.post('/fix-completed-orders', async (req, res) => {
  try {
    console.log('[Fix Completed Orders] Starting retroactive fix for completed orders...');
    
    const orders = await csvService.readOrders();
    let fixedCount = 0;
    const fixedOrders = [];
    
    for (const order of orders) {
      // Skip orders that are already completed, rejected, or cancelled
      const currentStatus = (order.order_status || '').toUpperCase().trim();
      if (currentStatus === 'COMPLETED' || currentStatus === 'REJECTED' || 
          currentStatus === 'CANCELLED' || currentStatus === 'CANCELED') {
        continue;
      }
      
      // Parse segments
      let segments = [];
      try {
        if (order.trip_segments && order.trip_segments.trim() !== '') {
          segments = JSON.parse(order.trip_segments);
        }
      } catch (e) {
        console.error(`[Fix Completed Orders] Error parsing segments for order ${order.order_id}:`, e);
        continue;
      }
      
      // Check if order is actually completed
      const isOrderRejected = csvService.isOrderRejected(order, segments);
      const isOrderCompleted = csvService.isOrderCompleted(order, segments);
      
      if (!isOrderRejected && isOrderCompleted) {
        const previousStatus = order.order_status || 'Unknown';
        console.log(`[Fix Completed Orders] Order ${order.order_id} is fully completed but status is ${previousStatus} - fixing...`);
        
        // Update order status to COMPLETED
        order.order_status = 'COMPLETED';
        
        // Free the vehicle if assigned
        if (order.vehicle_id) {
          try {
            await csvService.updateVehicleStatus(order.vehicle_id, 'Free');
            console.log(`[Fix Completed Orders] Vehicle ${order.vehicle_id} freed for order ${order.order_id}`);
          } catch (error) {
            console.error(`[Fix Completed Orders] Error freeing vehicle ${order.vehicle_id}:`, error);
          }
        }
        
        // Save updated order
        await csvService.writeOrder(order);
        fixedCount++;
        fixedOrders.push({
          orderId: order.order_id,
          previousStatus: previousStatus,
          newStatus: 'COMPLETED'
        });
        
        console.log(`[Fix Completed Orders] ✓ Fixed order ${order.order_id} (${previousStatus} → COMPLETED)`);
      }
    }
    
    console.log(`[Fix Completed Orders] Completed. Fixed ${fixedCount} order(s).`);
    
    res.json({
      success: true,
      message: `Fixed ${fixedCount} completed order(s)`,
      fixedCount: fixedCount,
      fixedOrders: fixedOrders
    });
  } catch (error) {
    console.error('[Fix Completed Orders] Error:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Internal server error'
    });
  }
});

module.exports = router;

