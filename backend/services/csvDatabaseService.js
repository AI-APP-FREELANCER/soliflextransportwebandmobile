const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const CSV_FILE_PATH = path.join(__dirname, '../backend.csv');
const NOTIFICATIONS_CSV_PATH = path.join(__dirname, '../notifications.csv');

// Helper function to get current timestamp in IST (UTC+5:30)
function getISTTimestamp() {
  const now = new Date();
  // IST is UTC+5:30, so add 5 hours 30 minutes (19800000 milliseconds)
  const istOffset = 5.5 * 60 * 60 * 1000; // 5.5 hours in milliseconds
  const istTime = new Date(now.getTime() + istOffset);
  
  // Format as ISO string with IST offset (+05:30)
  const year = istTime.getUTCFullYear();
  const month = String(istTime.getUTCMonth() + 1).padStart(2, '0');
  const day = String(istTime.getUTCDate()).padStart(2, '0');
  const hours = String(istTime.getUTCHours()).padStart(2, '0');
  const minutes = String(istTime.getUTCMinutes()).padStart(2, '0');
  const seconds = String(istTime.getUTCSeconds()).padStart(2, '0');
  const milliseconds = String(istTime.getUTCMilliseconds()).padStart(3, '0');
  
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${milliseconds}+05:30`;
}

// Department list
const DEPARTMENTS = [
  'Accounts Team',
  'Admin',
'IAF Unit-1 Fabric',
'IAF Unit-1 Stores',
'IAT Unit-1 Maintenance',
'IAF Unit-1 Security',
'IAF Unit-4 Fabric',
'IAF Unit-4 Stores',
'IAF Unit-4 Maintenance',
'IAF Unit-4 Security',
'IAF Unit-6 Fabric',
'IAF Unit-6 Stores',
'IAF Unit-6 Maintenance',
'IAF Unit-6 Security',
'Purchase',
'Soliflex Unit-1 Fabric',
'Soliflex Unit-1 Stores',
'Soliflex Unit-1 Security',
'Soliflex Unit-2 Fabric',
'Soliflex Unit-2 Stores',
'Soliflex Unit-2 Security'
];

// Vendor list (45 vendors from provided data)
const VENDORS = [
  'Abhay packaging',
  'Abhinandan Petro Pack PVT LTD',
  'Ambica pattern',
  'BB Industeris',
  'Bhagyashree',
  'Bright globle',
  'Buildmet Fibres Pvt ltd (Dabaspet)',
  'Bulk Liquid Solution',
  'Bangalore airport',
  'Calibrics',
  'Chakrapani vyapar Private Limited',
  'Chavao Overs',
  'Cheenai plastic',
  'Flexible Industries',
  'Gotawat Industries',
  'Hooks & Buckles',
  'Innova Polypack',
  'ITC Limited',
  'JJ Traders',
  'Kamal Tapes',
  'Mahalakshmi',
  'Mega international',
  'Newteck',
  'Paragon Plastics',
  'Plasmix',
  'Polylam Industries',
  'Pradeep trader',
  'Presting Venus',
  'Priyadarshini',
  'Reliance Industries limited (dodhabalapura road)',
  'Reliance Industries limited(Nelamangala)',
  'Rotech enginering',
  'Rukuma plastic',
  'Seenu transporter/Roto colour',
  'Shree tech rubber',
  'Sri sai Packaging',
  'Sri Vishnu rubber product',
  'SRM Products Private Limited',
  'Sunshine Industries',
  'Synpack/Synthetic',
  'VB Polypack',
  'ved industries',
  'Venkatadri polymers',
  'VRL (Tumkur)',
  'Vertex Phenumatics'
];

// Vehicle list (26 vehicles from provided data)
const VEHICLES_DATA = [
  { vehicle_number: 'KA06AA3457', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA02AB1409', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA51AF2387', type: 'Container', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA04AC7980', type: 'Closed', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'HR47B3343', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA06A9729', type: 'Closed', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'rented_vehicle', is_busy: false },
  { vehicle_number: 'KA150323', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'rented_vehicle', is_busy: false },
  { vehicle_number: 'KA51B5148', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'rented_vehicle', is_busy: false },
  // Additional vehicles with various capacities
  { vehicle_number: 'KA01AA1001', type: 'Open', capacity_kg: 12500, vehicle_type: '22ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1002', type: 'Open', capacity_kg: 6250, vehicle_type: '17ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1003', type: 'Open', capacity_kg: 5000, vehicle_type: '17ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1004', type: 'Open', capacity_kg: 1700, vehicle_type: '9ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1005', type: 'Open', capacity_kg: 1500, vehicle_type: '9ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1006', type: 'Closed', capacity_kg: 1300, vehicle_type: '9ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1007', type: 'Closed', capacity_kg: 1100, vehicle_type: '9ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1008', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1009', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1010', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1011', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1012', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1013', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1014', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1015', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1016', type: 'Open', capacity_kg: 7500, vehicle_type: '19ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1017', type: 'Closed', capacity_kg: 6250, vehicle_type: '17ft', vendor_vehicle: 'company_vehicle', is_busy: false },
  { vehicle_number: 'KA01AA1018', type: 'Closed', capacity_kg: 5000, vehicle_type: '17ft', vendor_vehicle: 'company_vehicle', is_busy: false }
];

// Role assignment logic
function getRoleByDepartment(department) {
  if (department === 'Admin') {
    return 'SUPER_USER';
  } else if (department === 'Accounts Team') {
    return 'APPROVAL_MANAGER';
  } else {
    return 'RFQ_CREATOR';
  }
}

// Initialize CSV file with headers if it doesn't exist
function initializeCsvFile() {
  if (!fs.existsSync(CSV_FILE_PATH)) {
    const headers = 'userId,fullName,passwordHash,department,role\n';
    fs.writeFileSync(CSV_FILE_PATH, headers, 'utf8');
  }
}

// Read all users from CSV
function readUsers() {
  return new Promise((resolve, reject) => {
    const users = [];
    
    if (!fs.existsSync(CSV_FILE_PATH)) {
      return resolve([]);
    }

    fs.createReadStream(CSV_FILE_PATH)
      .pipe(csv())
      .on('data', (row) => {
        // Filter out empty rows - only add rows with userId and fullName
        if (row.userId && row.fullName && row.fullName.trim() !== '') {
          users.push(row);
        }
      })
      .on('end', () => {
        resolve(users);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Write user to CSV
async function writeUser(user) {
  initializeCsvFile();
  
  const users = await readUsers();
  
  // Generate sequential user ID
  let maxUserId = 0;
  if (users.length > 0) {
    maxUserId = Math.max(...users.map(u => parseInt(u.userId) || 0));
  }
  const newUserId = maxUserId + 1;

  // Check if user with same fullName AND department already exists
  // Allow same name in different departments, but block same name+department combination
  const existingUser = users.find(u => 
    u.fullName && 
    u.fullName.toLowerCase() === user.fullName.toLowerCase() &&
    u.department && 
    u.department.toLowerCase() === user.department.toLowerCase()
  );
  if (existingUser) {
    throw new Error('User with this name already exists in this department. Please use a unique identifier or variation (e.g., adding a middle initial, employee ID, or a number) to differentiate your user name.');
  }

  const role = getRoleByDepartment(user.department);
  
  const newUser = {
    userId: newUserId.toString(),
    fullName: user.fullName,
    passwordHash: user.passwordHash,
    department: user.department,
    role: role
  };

  users.push(newUser);

  // Write all users back to CSV
  const csvWriter = createCsvWriter({
    path: CSV_FILE_PATH,
    header: [
      { id: 'userId', title: 'userId' },
      { id: 'fullName', title: 'fullName' },
      { id: 'passwordHash', title: 'passwordHash' },
      { id: 'department', title: 'department' },
      { id: 'role', title: 'role' }
    ]
  });

  await csvWriter.writeRecords(users);
  return newUser;
}

// Find user by credentials (name and department)
async function findUserByCredentials(fullName, department) {
  const users = await readUsers();
  const user = users.find(u => 
    u.fullName && 
    u.fullName.toLowerCase() === fullName.toLowerCase() &&
    u.department && 
    u.department.toLowerCase() === department.toLowerCase()
  );
  
  if (!user) {
    return null;
  }

  // Password verification is done in the route handler
  // This function just finds the user by name and department
  return user;
}

// Get user by ID
async function getUserById(userId) {
  const users = await readUsers();
  return users.find(u => u.userId === userId) || null;
}

// Get all departments
function getDepartments() {
  return DEPARTMENTS;
}

// Read vendors from vendors.csv
function readVendors() {
  return new Promise((resolve, reject) => {
    const vendors = [];
    const VENDORS_CSV_PATH = path.join(__dirname, '../vendors.csv');
    
    if (!fs.existsSync(VENDORS_CSV_PATH)) {
      return resolve([]);
    }

    let rowIndex = 0;
    fs.createReadStream(VENDORS_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        rowIndex++;
        // CSV uses 'Vender Place' column (note the spelling)
        const vendorName = row['Vender Place'] || row['Vender Place '] || '';
        const slNumber = row['S/L'] || rowIndex.toString();
        
        if (vendorName && vendorName.trim() !== '') {
          vendors.push({
            vendorId: slNumber,
            name: vendorName.trim()
          });
        }
      })
      .on('end', () => {
        resolve(vendors);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Get all vendors (reads from vendors.csv, falls back to VENDORS constant if CSV is empty)
async function getVendors() {
  const vendors = await readVendors();
  if (vendors.length === 0) {
    // Fallback to constant if CSV is empty (for backward compatibility)
    return VENDORS.map((name, index) => ({
      vendorId: (index + 1).toString(),
      name: name
    }));
  }
  return vendors;
}

// Get all vehicles (legacy - reads from VEHICLES_DATA constant)
async function getVehicles(filterBusy = null) {
  let result = VEHICLES_DATA.map((v, index) => ({
    vehicleId: (index + 1).toString(),
    vehicle_number: v.vehicle_number,
    type: v.type,
    capacity_kg: v.capacity_kg,
    vehicle_type: v.vehicle_type,
    vendor_vehicle: v.vendor_vehicle,
    is_busy: v.is_busy
  }));
  
  if (filterBusy !== null) {
    result = result.filter(v => v.is_busy === filterBusy);
  }
  
  return result;
}

// Read all vehicles from vehicles.csv
function readVehicles() {
  return new Promise((resolve, reject) => {
    const vehicles = [];
    const VEHICLES_CSV_PATH = path.join(__dirname, '../vehicles.csv');
    
    if (!fs.existsSync(VEHICLES_CSV_PATH)) {
      return resolve([]);
    }

    fs.createReadStream(VEHICLES_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        if (row.vehicleId) {
          vehicles.push({
            vehicleId: row.vehicleId,
            vehicle_number: row.vehicle_number,
            type: row.type,
            capacity_kg: parseInt(row.capacity_kg) || 0,
            vehicle_type: row.vehicle_type,
            vendor_vehicle: row.vendor_vehicle,
            status: row.status || 'Free',
            is_busy: row.status === 'Booked' // For backward compatibility
          });
        }
      })
      .on('end', () => {
        resolve(vehicles);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Write vehicles to vehicles.csv
async function writeVehicles(vehicles) {
  const VEHICLES_CSV_PATH = path.join(__dirname, '../vehicles.csv');
  
  const vehiclesWriter = createCsvWriter({
    path: VEHICLES_CSV_PATH,
    header: [
      { id: 'vehicleId', title: 'vehicleId' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'type', title: 'type' },
      { id: 'capacity_kg', title: 'capacity_kg' },
      { id: 'vehicle_type', title: 'vehicle_type' },
      { id: 'vendor_vehicle', title: 'vendor_vehicle' },
      { id: 'status', title: 'status' }
    ]
  });

  await vehiclesWriter.writeRecords(vehicles);
}

// Update vehicle status
async function updateVehicleStatus(vehicleId, status) {
  const vehicles = await readVehicles();
  const vehicleIndex = vehicles.findIndex(v => v.vehicleId === vehicleId.toString());
  
  if (vehicleIndex === -1) {
    throw new Error('Vehicle not found');
  }
  
  vehicles[vehicleIndex].status = status;
  vehicles[vehicleIndex].is_busy = status === 'Booked'; // Update is_busy for backward compatibility
  
  await writeVehicles(vehicles);
  return vehicles[vehicleIndex];
}

// Vehicle matching algorithm
async function matchVehicles(materialWeight) {
  const vehicles = await readVehicles(); // Read from vehicles.csv
  const availableVehicles = vehicles.filter(v => v.status === 'Free'); // Filter by status='Free'
  
  if (!materialWeight || materialWeight <= 0) {
    return [];
  }
  
  // Filter vehicles with capacity >= materialWeight (vehicle can carry the material)
  const matchingVehicles = availableVehicles
    .filter(v => v.capacity_kg >= materialWeight)
    .map(v => {
      // Calculate utilization: how much of vehicle capacity is used
      // If weight is 5000kg and vehicle capacity is 7500kg, utilization = (5000/7500)*100 = 66.67%
      const utilization = (materialWeight / v.capacity_kg) * 100;
      return {
        ...v,
        utilizationPercentage: Math.min(utilization, 100),
        isOptimal: utilization >= 80 && utilization <= 100
      };
    })
    .sort((a, b) => {
      // Prioritize optimal matches (80-100%)
      if (a.isOptimal && !b.isOptimal) return -1;
      if (!a.isOptimal && b.isOptimal) return 1;
      // Then sort by utilization (descending - highest first)
      return b.utilizationPercentage - a.utilizationPercentage;
    });
  
  return matchingVehicles;
}

// Read all RFQs from CSV
function readRFQs() {
  return new Promise((resolve, reject) => {
    const rfqs = [];
    const RFQ_CSV_PATH = path.join(__dirname, '../rfqs.csv');
    
    if (!fs.existsSync(RFQ_CSV_PATH)) {
      return resolve([]);
    }

    fs.createReadStream(RFQ_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        if (row.rfqId) {
          rfqs.push(row);
        }
      })
      .on('end', () => {
        resolve(rfqs);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Get RFQs by user ID
async function getRFQsByUserId(userId) {
  const rfqs = await readRFQs();
  return rfqs.filter(rfq => rfq.userId === userId);
}

// Get RFQ by ID
async function getRFQById(rfqId) {
  const rfqs = await readRFQs();
  return rfqs.find(rfq => rfq.rfqId === rfqId) || null;
}

// Get RFQs by status
async function getRFQsByStatus(status) {
  const rfqs = await readRFQs();
  return rfqs.filter(rfq => rfq.status === status);
}

// Write RFQ to CSV
async function writeRFQ(rfq) {
  const rfqs = await readRFQs();
  
  // Generate sequential RFQ ID
  let maxRfqId = 0;
  if (rfqs.length > 0) {
    maxRfqId = Math.max(...rfqs.map(r => parseInt(r.rfqId) || 0));
  }
  const newRfqId = maxRfqId + 1;
  
  const newRFQ = {
    rfqId: newRfqId.toString(),
    userId: rfq.userId,
    source: rfq.source,
    destination: rfq.destination,
    materialWeight: rfq.materialWeight.toString(),
    materialType: rfq.materialType,
    vehicleId: rfq.vehicleId || '',
    vehicle_number: rfq.vehicle_number || '',
    status: rfq.status || 'PENDING_APPROVAL',
    totalCost: rfq.totalCost ? rfq.totalCost.toString() : '0',
    createdAt: rfq.createdAt || new Date().toISOString(),
    approvedBy: rfq.approvedBy || '',
    approvedAt: rfq.approvedAt || '',
    rejectedAt: rfq.rejectedAt || '',
    rejectionReason: rfq.rejectionReason || '',
    startedAt: rfq.startedAt || '',
    completedAt: rfq.completedAt || ''
  };
  
  rfqs.push(newRFQ);
  
  // Read existing data
  const users = await readUsers();
  
  // Write all data back - we'll use a simple append approach
  // Read existing file content
  let existingContent = '';
  if (fs.existsSync(CSV_FILE_PATH)) {
    existingContent = fs.readFileSync(CSV_FILE_PATH, 'utf8');
  }
  
  // Append new RFQ
  const csvLine = `${newRFQ.rfqId},${newRFQ.userId},${newRFQ.source},${newRFQ.destination},${newRFQ.materialWeight},${newRFQ.materialType},${newRFQ.vehicleId || ''},${newRFQ.vehicle_number || ''},${newRFQ.status},${newRFQ.totalCost},${newRFQ.createdAt},${newRFQ.approvedBy || ''},${newRFQ.approvedAt || ''},${newRFQ.rejectedAt || ''},${newRFQ.rejectionReason || ''},${newRFQ.startedAt || ''},${newRFQ.completedAt || ''}\n`;
  
  // For now, we'll use a different approach - create a separate RFQs CSV
  // This is simpler than trying to mix data types in one CSV
  const RFQ_CSV_PATH = path.join(__dirname, '../rfqs.csv');
  
  if (!fs.existsSync(RFQ_CSV_PATH)) {
    const headers = 'rfqId,userId,source,destination,materialWeight,materialType,vehicleId,vehicle_number,status,totalCost,createdAt,approvedBy,approvedAt,rejectedAt,rejectionReason,startedAt,completedAt\n';
    fs.writeFileSync(RFQ_CSV_PATH, headers, 'utf8');
  }
  
  const rfqCsvWriter = createCsvWriter({
    path: RFQ_CSV_PATH,
    header: [
      { id: 'rfqId', title: 'rfqId' },
      { id: 'userId', title: 'userId' },
      { id: 'source', title: 'source' },
      { id: 'destination', title: 'destination' },
      { id: 'materialWeight', title: 'materialWeight' },
      { id: 'materialType', title: 'materialType' },
      { id: 'vehicleId', title: 'vehicleId' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'status', title: 'status' },
      { id: 'totalCost', title: 'totalCost' },
      { id: 'createdAt', title: 'createdAt' },
      { id: 'approvedBy', title: 'approvedBy' },
      { id: 'approvedAt', title: 'approvedAt' },
      { id: 'rejectedAt', title: 'rejectedAt' },
      { id: 'rejectionReason', title: 'rejectionReason' },
      { id: 'startedAt', title: 'startedAt' },
      { id: 'completedAt', title: 'completedAt' }
    ]
  });
  
  await rfqCsvWriter.writeRecords(rfqs);
  return newRFQ;
}

// Update RFQ status
async function updateRFQStatus(rfqId, status, updateData = {}) {
  const rfqs = await readRFQs();
  const rfqIndex = rfqs.findIndex(r => r.rfqId === rfqId);
  
  if (rfqIndex === -1) {
    throw new Error('RFQ not found');
  }
  
  rfqs[rfqIndex] = {
    ...rfqs[rfqIndex],
    status,
    ...updateData
  };
  
  // Write back
  const RFQ_CSV_PATH = path.join(__dirname, '../rfqs.csv');
  const rfqCsvWriter = createCsvWriter({
    path: RFQ_CSV_PATH,
    header: [
      { id: 'rfqId', title: 'rfqId' },
      { id: 'userId', title: 'userId' },
      { id: 'source', title: 'source' },
      { id: 'destination', title: 'destination' },
      { id: 'materialWeight', title: 'materialWeight' },
      { id: 'materialType', title: 'materialType' },
      { id: 'vehicleId', title: 'vehicleId' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'status', title: 'status' },
      { id: 'totalCost', title: 'totalCost' },
      { id: 'createdAt', title: 'createdAt' },
      { id: 'approvedBy', title: 'approvedBy' },
      { id: 'approvedAt', title: 'approvedAt' },
      { id: 'rejectedAt', title: 'rejectedAt' },
      { id: 'rejectionReason', title: 'rejectionReason' },
      { id: 'startedAt', title: 'startedAt' },
      { id: 'completedAt', title: 'completedAt' }
    ]
  });
  
  await rfqCsvWriter.writeRecords(rfqs);
  return rfqs[rfqIndex];
}

// Helper function to parse trip_segments JSON string to array
function parseTripSegments(segmentsString) {
  if (!segmentsString || segmentsString.trim() === '' || segmentsString === 'null') {
    return [];
  }
  try {
    return JSON.parse(segmentsString);
  } catch (error) {
    console.error('Error parsing trip_segments:', error);
    return [];
  }
}

// Helper function to stringify trip_segments array to JSON string
function stringifyTripSegments(segmentsArray) {
  if (!segmentsArray || !Array.isArray(segmentsArray)) {
    return '[]';
  }
  try {
    return JSON.stringify(segmentsArray);
  } catch (error) {
    console.error('Error stringifying trip_segments:', error);
    return '[]';
  }
}

// Factory locations list (must match vendors.csv)
const FACTORY_LOCATIONS = [
  'IAF unit-1',
  'IAF unit-2',
  'IAF unit-3',
  'IAF unit-4',
  'Soliflex unit-1',
  'Soliflex unit-2',
  'Soliflex unit-3',
  'Soliflex unit-4'
];

// Helper function to check if a location is a factory
function isFactoryLocation(location) {
  if (!location || typeof location !== 'string') {
    return false;
  }
  // Normalize location name (trim whitespace, case-insensitive)
  const normalizedLocation = location.trim();
  return FACTORY_LOCATIONS.some(factory => 
    factory.toLowerCase() === normalizedLocation.toLowerCase()
  );
}

// Calculate order category based on trip segments
function calculateOrderCategory(tripSegments) {
  if (!tripSegments || tripSegments.length === 0) {
    return 'Client/Vendor Order'; // Default if no segments
  }
  
  // Parse segments if they're a string
  let segments = tripSegments;
  if (typeof tripSegments === 'string') {
    try {
      segments = parseTripSegments(tripSegments);
    } catch (error) {
      console.error('Error parsing segments for category:', error);
      return 'Client/Vendor Order';
    }
  }
  
  if (!Array.isArray(segments)) {
    return 'Client/Vendor Order';
  }
  
  // Check if ALL segments use only factory locations
  const allLocations = new Set();
  segments.forEach(segment => {
    if (segment.source) allLocations.add(segment.source);
    if (segment.destination) allLocations.add(segment.destination);
  });
  
  // Check if all locations are factories
  const allAreFactories = Array.from(allLocations).every(location => 
    FACTORY_LOCATIONS.includes(location)
  );
  
  return allAreFactories ? 'Internal Transfer' : 'Client/Vendor Order';
}

// Read vendors from vendors.csv with all pricing columns
function readVendorsWithPricing() {
  return new Promise((resolve, reject) => {
    const vendors = [];
    const VENDORS_CSV_PATH = path.join(__dirname, '../vendors.csv');
    
    if (!fs.existsSync(VENDORS_CSV_PATH)) {
      return resolve([]);
    }

    let rowIndex = 0;
    fs.createReadStream(VENDORS_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        rowIndex++;
        // Note: CSV column names may have spaces - handle them
        const vendorNameRaw = row['Vender Place'] || row['Vender Place '] || '';
        const vendorName = vendorNameRaw ? vendorNameRaw.trim() : '';
        const slNumber = row['S/L'] || rowIndex.toString();
        
        if (vendorName && vendorName !== '') {
          vendors.push({
            vendorId: slNumber.toString(),
            vendor_name: vendorName,
            name: vendorName, // For backward compatibility
            kl: row['KL'] || '',
            pick_up_by_sol_below_3000_kgs: row['Pick_up_by_sol_below_3000_kgs'] || '0',
            dropped_by_vendor_below_3000_kgs: row['Dropped_by_vendor_below_3000_kgs'] || '0',
            pick_up_by_sol_between_3000_to_5999_kgs: row['Pick_up_by_sol_between_3000_to_5999_kgs'] || '0',
            dropped_by_vendor_below_5999_kgs: row['Dropped_by_vendor_below_5999_kgs'] || '0',
            pick_up_by_sol_above_6000_kgs: row['Pick_up_by_sol_above_6000_kgs'] || '0',
            dropped_by_vendor_above_6000_kgs: row['Dropped_by_vendor_above_6000_kgs'] || '0',
            toll_charges: row['Toll charges'] || row['Toll charges '] || '0'
          });
        }
      })
      .on('end', () => {
        resolve(vendors);
      })
      .on('error', (error) => {
        console.error('Error reading vendors.csv:', error);
        reject(error);
      });
  });
}

// Get weight bracket based on material weight
function getWeightBracket(materialWeight) {
  if (materialWeight < 0) {
    throw new Error('Material weight must be >= 0');
  }
  if (materialWeight < 3000) {
    return 'below_3000';
  } else if (materialWeight < 6000) {
    return '3000_5999';
  } else {
    return 'above_6000';
  }
}

// Calculate invoice rate based on source location and material weight
// For Multiple Trip: Use calculateInvoiceRateForSegment() which checks both source and destination
async function calculateInvoiceRate(sourceLocation, materialWeight, destinationLocation = null, tripType = null) {
  try {
    // Validate inputs
    if (!sourceLocation || sourceLocation.trim() === '') {
      throw new Error('Source location is required');
    }
    if (materialWeight < 0) {
      throw new Error('Material weight must be >= 0');
    }

    // If destination is provided, use segment-specific logic (for Multiple Trip)
    // USER REQUEST: For Multiple Trip, force Drop rates (forceDropRates = true)
    if (destinationLocation && destinationLocation.trim() !== '') {
      const forceDropRates = tripType === 'Multiple-Trip-Vendor';
      return await calculateInvoiceRateForSegment(sourceLocation, destinationLocation, materialWeight, forceDropRates);
    }

    // Normalize source location (trim, case-insensitive)
    const normalizedSource = sourceLocation.trim();
    
    // Determine if source is factory or vendor FIRST
    const isFactory = FACTORY_LOCATIONS.some(factory => 
      factory.toLowerCase() === normalizedSource.toLowerCase()
    );

    let vendor = null;
    
    if (!isFactory) {
      // Read vendors with pricing data only if not a factory
      const vendors = await readVendorsWithPricing();
      
      // Find matching vendor (case-insensitive)
      vendor = vendors.find(v => 
        v.vendor_name.toLowerCase() === normalizedSource.toLowerCase()
      );

      if (!vendor) {
        throw new Error(`Vendor not found: ${sourceLocation}`);
      }
    } else {
      // For factories, we need to read vendors.csv to get pricing columns
      // Factories might not be in the vendor list, but pricing structure is same
      // We'll use a dummy lookup - but actually, factories likely aren't in vendors.csv
      // So we'll need to handle this case: for factories, pricing might come from a different source
      // For now, let's check if factory is in vendors.csv as well
      const vendors = await readVendorsWithPricing();
      vendor = vendors.find(v => 
        v.vendor_name.toLowerCase() === normalizedSource.toLowerCase()
      );
      // If factory not in vendors.csv, we'll still use the pricing columns structure
      // The pricing columns exist for all entries, so we can use any vendor entry structure
      // Actually, wait - if it's a factory and not in vendors.csv, we can't get pricing
      // Let me assume factories ARE in vendors.csv with the same structure
      if (!vendor) {
        throw new Error(`Factory location not found in vendors.csv: ${sourceLocation}`);
      }
    }

    // Get weight bracket
    const weightBracket = getWeightBracket(materialWeight);

    // Select appropriate column based on source type and weight bracket
    // Part 1: Verify data type coercion - all values must be parsed as integers
    let invoiceAmount = 0;
    let tollCharges = 0;

    if (isFactory) {
      // Factory locations (Soliflex picks up)
      // Part 1: Ensure proper type coercion - parse as integer with radix
      switch (weightBracket) {
        case 'below_3000':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_below_3000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case '3000_5999':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_between_3000_to_5999_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case 'above_6000':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_above_6000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
      }
    } else {
      // Vendor locations (vendor drops)
      // Part 1: Ensure proper type coercion - parse as integer with radix
      switch (weightBracket) {
        case 'below_3000':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_below_3000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case '3000_5999':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_below_5999_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case 'above_6000':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_above_6000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
      }
    }

    // Get toll charges (only for vendors, factories typically don't have toll charges)
    // Part 1: Ensure proper type coercion - parse as integer with radix
    if (vendor && !isFactory) {
      tollCharges = parseInt(vendor.toll_charges || '0', 10);
      if (isNaN(tollCharges)) tollCharges = 0;
    }

    // Part 1: Log calculation details for debugging
    console.log(`[Rate Calculation] Source-only: ${sourceLocation}`);
    console.log(`  Source Type: ${isFactory ? 'Factory (Pick)' : 'Vendor (Drop)'}`);
    console.log(`  Weight: ${materialWeight} kg (Bracket: ${weightBracket})`);
    console.log(`  Vendor: ${vendor?.vendor_name || 'N/A'}`);
    console.log(`  Invoice Amount: ₹${invoiceAmount}`);
    console.log(`  Toll Charges: ₹${tollCharges}`);

    return {
      invoice_amount: invoiceAmount,
      toll_charges: tollCharges
    };
  } catch (error) {
    console.error('Error calculating invoice rate:', error);
    throw error;
  }
}

// Calculate invoice rate for a segment based on source, destination, and material weight
// Part 1: Multiple Trip Pick & Drop Logic
// - Factory → Vendor or Vendor → Vendor: Apply Pick rates (pick_up_by_sol_*)
// - Vendor → Factory: Apply Drop rates (dropped_by_vendor_*)
// USER REQUEST: For Multiple Trip, ALWAYS use Drop rates (dropped_by_vendor_*) for all segments
async function calculateInvoiceRateForSegment(sourceLocation, destinationLocation, materialWeight, forceDropRates = false) {
  try {
    // Validate inputs
    if (!sourceLocation || sourceLocation.trim() === '') {
      throw new Error('Source location is required');
    }
    if (!destinationLocation || destinationLocation.trim() === '') {
      throw new Error('Destination location is required');
    }
    if (materialWeight < 0) {
      throw new Error('Material weight must be >= 0');
    }

    // Normalize locations (trim, case-insensitive)
    const normalizedSource = sourceLocation.trim();
    const normalizedDestination = destinationLocation.trim();
    
    // Determine if source and destination are factories
    const isSourceFactory = FACTORY_LOCATIONS.some(factory => 
      factory.toLowerCase() === normalizedSource.toLowerCase()
    );
    const isDestFactory = FACTORY_LOCATIONS.some(factory => 
      factory.toLowerCase() === normalizedDestination.toLowerCase()
    );

    // Read vendors with pricing data
    const vendors = await readVendorsWithPricing();
    
    // CRITICAL FIX: Log rate card data status
    console.log(`[Rate Calculation] Rate card records count: ${vendors.length}`);
    console.log(`[Rate Calculation] Sample vendors: ${vendors.slice(0, 3).map(v => v.vendor_name).join(', ')}`);
    
    // USER REQUEST: For Multiple Trip, ALWAYS use Drop rates (forceDropRates = true)
    // For other trip types, determine rate type based on source/destination
    let usePickRates = false;
    if (forceDropRates) {
      // Multiple Trip: Always use Drop rates
      usePickRates = false;
    } else {
      // CRITICAL FIX: For Pick rates (Factory → Vendor or Vendor → Vendor), use DESTINATION vendor
      // For Drop rates (Vendor → Factory), use SOURCE vendor
      // Determine rate type first
      if (isSourceFactory) {
        // Factory → Vendor: Use Pick rates
        usePickRates = true;
      } else if (isDestFactory) {
        // Vendor → Factory: Use Drop rates
        usePickRates = false;
      } else {
        // Vendor → Vendor: Use Pick rates
        usePickRates = true;
      }
    }
    
    // Find vendor based on rate type
    let vendor = null;
    if (usePickRates) {
      // Pick rates: Use DESTINATION vendor (where material is being picked up from)
      vendor = vendors.find(v => 
        v.vendor_name.toLowerCase() === normalizedDestination.toLowerCase()
      );
      
      // If destination not found, try source as fallback
      if (!vendor) {
        vendor = vendors.find(v => 
          v.vendor_name.toLowerCase() === normalizedSource.toLowerCase()
        );
      }
    } else {
      // Drop rates: Use DESTINATION vendor for Multiple Trip (where material is dropped)
      // CRITICAL FIX: For Multiple Trip, use DESTINATION vendor (not SOURCE) to get valid Drop rates
      // This ensures we get Drop rates from vendors (not factories which may have empty Drop columns)
      if (forceDropRates) {
        // Multiple Trip Drop rates: Use DESTINATION vendor (where material is being dropped)
        vendor = vendors.find(v => 
          v.vendor_name.toLowerCase() === normalizedDestination.toLowerCase()
        );
        
        // If destination not found (or destination is factory), try source as fallback
        if (!vendor) {
          vendor = vendors.find(v => 
            v.vendor_name.toLowerCase() === normalizedSource.toLowerCase()
          );
        }
        
        // CRITICAL FIX: Log vendor lookup for Multiple Trip
        console.log(`[Rate Calculation] Multiple Trip Drop Rate Lookup:`);
        console.log(`  Source: ${sourceLocation} (Factory: ${isSourceFactory})`);
        console.log(`  Destination: ${destinationLocation} (Factory: ${isDestFactory})`);
        console.log(`  Vendor found: ${vendor?.vendor_name || 'N/A'}`);
        console.log(`  Using Rate Column: Drop_Rate (dropped_by_vendor_*)`);
      } else {
        // Drop rates (non-Multiple Trip): Use SOURCE vendor (where material is being dropped by)
        vendor = vendors.find(v => 
          v.vendor_name.toLowerCase() === normalizedSource.toLowerCase()
        );
        
        // If source not found, try destination as fallback
        if (!vendor) {
          vendor = vendors.find(v => 
            v.vendor_name.toLowerCase() === normalizedDestination.toLowerCase()
          );
        }
      }
    }
    
    // CRITICAL FIX: Log vendor lookup details
    if (!vendor) {
      console.error(`[Rate Calculation] ERROR: Could not find vendor for:`);
      console.error(`  Source: ${sourceLocation}`);
      console.error(`  Destination: ${destinationLocation}`);
      console.error(`  Available vendors: ${vendors.map(v => v.vendor_name).join(', ')}`);
      throw new Error(`Location not found in vendors.csv: ${sourceLocation} or ${destinationLocation}`);
    }

    // Get weight bracket
    const weightBracket = getWeightBracket(materialWeight);

    // CRITICAL FIX: Log weight tier lookup
    console.log(`[Rate Calculation] Weight tier lookup:`);
    console.log(`  Material Weight: ${materialWeight} kg`);
    console.log(`  Weight Bracket: ${weightBracket}`);

    // Note: Rate type (Pick/Drop) is already determined above when finding the vendor
    // This ensures we use the correct vendor for pricing lookup

    // Calculate invoice amount based on rate type
    // Part 1: Verify data type coercion - all values must be parsed as integers
    let invoiceAmount = 0;
    let tollCharges = 0;

    if (usePickRates) {
      // Pick rates (pick_up_by_sol_*)
      // Part 1: Ensure proper type coercion - parse as integer with radix
      switch (weightBracket) {
        case 'below_3000':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_below_3000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case '3000_5999':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_between_3000_to_5999_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case 'above_6000':
          invoiceAmount = parseInt(vendor?.pick_up_by_sol_above_6000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
      }
    } else {
      // Drop rates (dropped_by_vendor_*)
      // CRITICAL FIX: Log Drop rate column values before parsing
      console.log(`[Rate Calculation] Drop Rate Column Values for ${vendor.vendor_name}:`);
      console.log(`  below_3000: ${vendor?.dropped_by_vendor_below_3000_kgs || 'N/A'}`);
      console.log(`  3000_5999: ${vendor?.dropped_by_vendor_below_5999_kgs || 'N/A'}`);
      console.log(`  above_6000: ${vendor?.dropped_by_vendor_above_6000_kgs || 'N/A'}`);
      
      // Part 1: Ensure proper type coercion - parse as integer with radix
      switch (weightBracket) {
        case 'below_3000':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_below_3000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case '3000_5999':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_below_5999_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
        case 'above_6000':
          invoiceAmount = parseInt(vendor?.dropped_by_vendor_above_6000_kgs || '0', 10);
          if (isNaN(invoiceAmount)) invoiceAmount = 0;
          break;
      }
      
      // CRITICAL FIX: Log if Drop rate is zero
      if (invoiceAmount === 0) {
        console.error(`[Rate Calculation] ERROR: Could not find rate for ${vendor.vendor_name} in ${weightBracket} tier using Drop_Rate`);
        const columnName = weightBracket === 'below_3000' ? 'dropped_by_vendor_below_3000_kgs' : 
                          weightBracket === '3000_5999' ? 'dropped_by_vendor_below_5999_kgs' : 
                          'dropped_by_vendor_above_6000_kgs';
        console.error(`  Raw value from CSV: ${vendor[columnName] || 'N/A'}`);
      }
    }

    // Get toll charges (only for vendors, factories typically don't have toll charges)
    // Part 1: Ensure proper type coercion - parse as integer with radix
    if (vendor && !isSourceFactory) {
      tollCharges = parseInt(vendor.toll_charges || '0', 10);
      if (isNaN(tollCharges)) tollCharges = 0;
    }

    // Rate calculation completed

    return {
      invoice_amount: invoiceAmount,
      toll_charges: tollCharges
    };
  } catch (error) {
    console.error('Error calculating invoice rate for segment:', error);
    throw error;
  }
}

// Calculate order totals from trip segments
// Part 1: Multiple Trip - ALL segments contribute to totals (cumulative sum)
// Part 3: Round Trip - Only chargeable segments contribute to totals
// - Initial Round Trip (2 segments): Only Segment 1 contributes (Segment 2 has invoice_amount = 0)
// - Amended Round Trip (3+ segments): Only Segment 1 and final segment contribute (middle segments are display-only)
function calculateOrderTotals(tripSegments, orderTripType = null) {
  let totalWeight = 0;
  let totalInvoiceAmount = 0;
  let totalTollCharges = 0;
  
  let segments = [];
  if (Array.isArray(tripSegments)) {
    segments = tripSegments;
  } else if (typeof tripSegments === 'string') {
    try {
      const parsed = JSON.parse(tripSegments);
      if (Array.isArray(parsed)) {
        segments = parsed;
      }
    } catch (e) {
      console.error('Error parsing trip_segments in calculateOrderTotals:', e);
      return { total_weight: 0, total_invoice_amount: 0, total_toll_charges: 0 };
    }
  }
  
  // Check if this is a Round Trip order
  const isRoundTrip = orderTripType === 'Round-Trip-Vendor';
  const isMultipleTrip = orderTripType === 'Multiple-Trip-Vendor';
  
  if (isRoundTrip && segments.length >= 2) {
    // Part 3: Round Trip logic: Only chargeable segments contribute
    if (segments.length === 2) {
      // Initial Round Trip: Only Segment 1 (A → B) contributes
      // Segment 2 (B → A) has invoice_amount = 0 and does not contribute
      const segment1 = segments[0];
      totalWeight += parseInt(segment1.material_weight || '0') || 0;
      totalInvoiceAmount += parseInt(segment1.invoice_amount || '0') || 0;
      totalTollCharges += parseInt(segment1.toll_charges || '0') || 0;
      
      console.log(`[Round Trip Totals] Initial Round Trip (2 segments):`);
      console.log(`  Segment 1 (chargeable): Weight: ${segment1.material_weight} kg, Invoice: ₹${segment1.invoice_amount}`);
      console.log(`  Segment 2 (non-chargeable): Weight: ${segments[1].material_weight} kg, Invoice: ₹${segments[1].invoice_amount} (excluded)`);
    } else if (segments.length >= 3) {
      // Amended Round Trip: Only Segment 1 (A → B) and final segment (C → A) contribute
      // Middle segments (B → C) are display-only and do not contribute
      const segment1 = segments[0]; // Segment 1: A → B (chargeable)
      const finalSegment = segments[segments.length - 1]; // Final segment: C → A (chargeable)
      
      totalWeight += parseInt(segment1.material_weight || '0') || 0;
      totalInvoiceAmount += parseInt(segment1.invoice_amount || '0') || 0;
      totalTollCharges += parseInt(segment1.toll_charges || '0') || 0;
      
      totalWeight += parseInt(finalSegment.material_weight || '0') || 0;
      totalInvoiceAmount += parseInt(finalSegment.invoice_amount || '0') || 0;
      totalTollCharges += parseInt(finalSegment.toll_charges || '0') || 0;
      
      console.log(`[Round Trip Totals] Amended Round Trip (${segments.length} segments):`);
      console.log(`  Segment 1 (chargeable): Weight: ${segment1.material_weight} kg, Invoice: ₹${segment1.invoice_amount}`);
      for (let i = 1; i < segments.length - 1; i++) {
        console.log(`  Segment ${i + 1} (display-only): Weight: ${segments[i].material_weight} kg, Invoice: ₹${segments[i].invoice_amount} (excluded)`);
      }
      console.log(`  Segment ${segments.length} (chargeable): Weight: ${finalSegment.material_weight} kg, Invoice: ₹${finalSegment.invoice_amount}`);
    }
  } else {
    // Part 1: Multiple Trip and Single Trip: ALL segments contribute (cumulative sum)
    // Part 1: This ensures Multiple Trip totals = sum of ALL segment weights, invoices, and tolls
    segments.forEach((segment, index) => {
      const segmentWeight = parseInt(segment.material_weight || '0') || 0;
      const segmentInvoice = parseInt(segment.invoice_amount || '0') || 0;
      const segmentToll = parseInt(segment.toll_charges || '0') || 0;
      
      totalWeight += segmentWeight;
      totalInvoiceAmount += segmentInvoice;
      totalTollCharges += segmentToll;
      
      // Part 1: Log for Multiple Trip to show cumulative addition
      if (isMultipleTrip) {
        console.log(`[Multiple Trip Totals] Segment ${index + 1}: ${segment.source} → ${segment.destination} (Weight: ${segmentWeight} kg, Invoice: ₹${segmentInvoice}, Toll: ₹${segmentToll}) - CONTRIBUTES`);
      }
    });
    
    // Part 1: Log final totals for Multiple Trip
    if (isMultipleTrip && segments.length > 0) {
      console.log(`[Multiple Trip Totals] Final totals: Total Weight: ${totalWeight} kg, Total Invoice: ₹${totalInvoiceAmount}, Total Toll: ₹${totalTollCharges}`);
      console.log(`  All ${segments.length} segments contribute to totals (cumulative sum)`);
    }
  }
  
  return {
    total_weight: totalWeight,
    total_invoice_amount: totalInvoiceAmount,
    total_toll_charges: totalTollCharges
  };
}

// Read all orders from orders.csv
function readOrders() {
  return new Promise((resolve, reject) => {
    const orders = [];
    const ORDERS_CSV_PATH = path.join(__dirname, '../orders.csv');
    
    if (!fs.existsSync(ORDERS_CSV_PATH)) {
      return resolve([]);
    }

    fs.createReadStream(ORDERS_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        if (row.order_id) {
          // Parse trip_segments if present, or create from source/destination for backward compatibility
          if (!row.trip_segments || row.trip_segments.trim() === '') {
            // Create segment from existing source/destination for backward compatibility
            const segment = {
              segment_id: 1,
              source: row.source || '',
              destination: row.destination || '',
              material_weight: parseInt(row.material_weight) || 0,
              material_type: row.material_type || '',
              segment_status: row.order_status || 'Open'
            };
            row.trip_segments = JSON.stringify([segment]);
          }
          // Ensure is_amended and original_trip_type have defaults
          if (!row.is_amended) row.is_amended = 'No';
          if (!row.original_trip_type) row.original_trip_type = row.trip_type || 'Single-Trip-Vendor';
          // Ensure amendment audit trail fields have defaults
          if (!row.amendment_requested_by) row.amendment_requested_by = '';
          if (!row.amendment_requested_department) row.amendment_requested_department = '';
          if (!row.amendment_requested_at) row.amendment_requested_at = '';
          // Calculate order_category if missing
          if (!row.order_category && row.trip_segments) {
            row.order_category = calculateOrderCategory(row.trip_segments);
          }
          if (!row.order_category) row.order_category = 'Client/Vendor Order';
          
          // Calculate totals if missing (backward compatibility)
          if ((!row.total_weight || !row.total_invoice_amount || !row.total_toll_charges) && row.trip_segments) {
            const rowTripType = row.original_trip_type || row.trip_type || 'Single-Trip-Vendor';
            const totals = calculateOrderTotals(row.trip_segments, rowTripType);
            if (!row.total_weight) row.total_weight = totals.total_weight.toString();
            if (!row.total_invoice_amount) row.total_invoice_amount = totals.total_invoice_amount.toString();
            if (!row.total_toll_charges) row.total_toll_charges = totals.total_toll_charges.toString();
          }
          
          orders.push(row);
        }
      })
      .on('end', () => {
        resolve(orders);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Get next order ID (finds highest order_id and increments)
async function getNextOrderId() {
  const orders = await readOrders();
  
  if (orders.length === 0) {
    return 'Order-1000';
  }
  
  // Extract numeric part from order_id (e.g., "Order-1005" -> 1005)
  let maxNumber = 999; // Start from 999 so first order is Order-1000
  
  orders.forEach(order => {
    if (order.order_id) {
      const match = order.order_id.match(/Order-(\d+)/);
      if (match) {
        const num = parseInt(match[1], 10);
        if (num > maxNumber) {
          maxNumber = num;
        }
      }
    }
  });
  
  return `Order-${maxNumber + 1}`;
}

// Write order to orders.csv
async function writeOrder(order) {
  const orders = await readOrders();
  
  // Ensure trip_segments is a JSON string
  if (typeof order.trip_segments === 'object' || Array.isArray(order.trip_segments)) {
    order.trip_segments = stringifyTripSegments(order.trip_segments);
  }
  if (!order.trip_segments || order.trip_segments.trim() === '') {
    order.trip_segments = '[]';
  }
  
  // Ensure is_amended and original_trip_type have defaults
  if (!order.is_amended || order.is_amended.trim() === '') order.is_amended = 'No';
  if (!order.original_trip_type || order.original_trip_type.trim() === '') {
    order.original_trip_type = order.trip_type || 'Single-Trip-Vendor';
  }
  
  // Calculate order_category if missing
  if (!order.order_category || order.order_category.trim() === '') {
    order.order_category = calculateOrderCategory(order.trip_segments);
  }
  
  // Calculate and store totals from trip_segments
  // For Round Trip: Only chargeable segments contribute (Segment 1 and final segment after amendment)
  const orderTripType = order.original_trip_type || order.trip_type || 'Single-Trip-Vendor';
  const totals = calculateOrderTotals(order.trip_segments, orderTripType);
  order.total_weight = order.total_weight || totals.total_weight.toString();
  order.total_invoice_amount = order.total_invoice_amount || totals.total_invoice_amount.toString();
  order.total_toll_charges = order.total_toll_charges || totals.total_toll_charges.toString();
  
  // For backward compatibility: set source/destination from first/last segment
  if (order.trip_segments && order.trip_segments !== '[]') {
    try {
      const segments = parseTripSegments(order.trip_segments);
      if (segments.length > 0) {
        order.source = order.source || segments[0].source || '';
        order.destination = order.destination || segments[segments.length - 1].destination || '';
      }
    } catch (error) {
      console.error('Error parsing segments for backward compatibility:', error);
    }
  }
  
  // Ensure original totals fields have defaults if not set
  if (!order.original_total_weight) order.original_total_weight = '';
  if (!order.original_total_invoice_amount) order.original_total_invoice_amount = '';
  if (!order.original_total_toll_charges) order.original_total_toll_charges = '';
  if (!order.original_segment_count) order.original_segment_count = '';
  
  // Ensure vehicle fields default to empty string if null/undefined to prevent CSV formatting errors
  if (!order.vehicle_id || order.vehicle_id === null || order.vehicle_id === undefined) order.vehicle_id = '';
  if (!order.vehicle_number || order.vehicle_number === null || order.vehicle_number === undefined) order.vehicle_number = '';
  
  // Ensure auditing fields have defaults if not set
  if (!order.approved_timestamp) order.approved_timestamp = '';
  if (!order.approved_by_member) order.approved_by_member = '';
  if (!order.approved_by_department) order.approved_by_department = '';
  if (!order.vehicle_started_at_timestamp) order.vehicle_started_at_timestamp = '';
  if (!order.vehicle_started_from_location) order.vehicle_started_from_location = '';
  if (!order.security_entry_timestamp) order.security_entry_timestamp = '';
  if (!order.security_entry_member_name) order.security_entry_member_name = '';
  if (!order.security_entry_checkpoint_location) order.security_entry_checkpoint_location = '';
  if (!order.stores_validation_timestamp) order.stores_validation_timestamp = '';
  if (!order.vehicle_exited_timestamp) order.vehicle_exited_timestamp = '';
  if (!order.exit_approved_by_timestamp) order.exit_approved_by_timestamp = '';
  if (!order.exit_approved_by_member_name) order.exit_approved_by_member_name = '';
  
  // Check if order already exists (update) or is new
  const existingIndex = orders.findIndex(o => o.order_id === order.order_id);
  
  if (existingIndex >= 0) {
    orders[existingIndex] = order;
  } else {
    orders.push(order);
  }
  
  const ORDERS_CSV_PATH = path.join(__dirname, '../orders.csv');
  
  const ordersWriter = createCsvWriter({
    path: ORDERS_CSV_PATH,
    header: [
      { id: 'order_id', title: 'order_id' },
      { id: 'user_id', title: 'user_id' },
      { id: 'source', title: 'source' },
      { id: 'destination', title: 'destination' },
      { id: 'material_weight', title: 'material_weight' },
      { id: 'material_type', title: 'material_type' },
      { id: 'trip_type', title: 'trip_type' },
      { id: 'vehicle_id', title: 'vehicle_id' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'order_status', title: 'order_status' },
      { id: 'created_at', title: 'created_at' },
      { id: 'creator_department', title: 'creator_department' },
      { id: 'creator_user_id', title: 'creator_user_id' }, // CRITICAL FIX: Track creator user ID
      { id: 'creator_name', title: 'creator_name' }, // Track creator's full name
      { id: 'trip_segments', title: 'trip_segments' },
      { id: 'is_amended', title: 'is_amended' },
      { id: 'original_trip_type', title: 'original_trip_type' },
      { id: 'order_category', title: 'order_category' },
      { id: 'total_weight', title: 'total_weight' },
      { id: 'total_invoice_amount', title: 'total_invoice_amount' },
      { id: 'total_toll_charges', title: 'total_toll_charges' },
      // Amendment audit trail fields
      { id: 'amendment_requested_by', title: 'amendment_requested_by' },
      { id: 'amendment_requested_department', title: 'amendment_requested_department' },
      { id: 'amendment_requested_at', title: 'amendment_requested_at' },
      { id: 'last_amended_by_user_id', title: 'last_amended_by_user_id' }, // CRITICAL FIX: Track last amendment user ID
      { id: 'last_amended_timestamp', title: 'last_amended_timestamp' }, // CRITICAL FIX: Track last amendment timestamp
      { id: 'amendment_history', title: 'amendment_history' }, // Amendment history (JSON array)
      // Original totals before amendment (for approval summary)
      { id: 'original_total_weight', title: 'original_total_weight' },
      { id: 'original_total_invoice_amount', title: 'original_total_invoice_amount' },
      { id: 'original_total_toll_charges', title: 'original_total_toll_charges' },
      { id: 'original_segment_count', title: 'original_segment_count' },
      // Order lifecycle auditing fields
      { id: 'approved_timestamp', title: 'approved_timestamp' },
      { id: 'approved_by_member', title: 'approved_by_member' },
      { id: 'approved_by_department', title: 'approved_by_department' },
      { id: 'vehicle_started_at_timestamp', title: 'vehicle_started_at_timestamp' },
      { id: 'vehicle_started_from_location', title: 'vehicle_started_from_location' },
      { id: 'security_entry_timestamp', title: 'security_entry_timestamp' },
      { id: 'security_entry_member_name', title: 'security_entry_member_name' },
      { id: 'security_entry_checkpoint_location', title: 'security_entry_checkpoint_location' },
      { id: 'stores_validation_timestamp', title: 'stores_validation_timestamp' },
      { id: 'vehicle_exited_timestamp', title: 'vehicle_exited_timestamp' },
      { id: 'exit_approved_by_timestamp', title: 'exit_approved_by_timestamp' },
      { id: 'exit_approved_by_member_name', title: 'exit_approved_by_member_name' }
    ]
  });
  
  await ordersWriter.writeRecords(orders);
  return order;
}

// Get order by ID
async function getOrderById(orderId) {
  const orders = await readOrders();
  return orders.find(o => o.order_id === orderId) || null;
}

// Update order status
async function updateOrderStatus(orderId, newStatus, updateData = {}) {
  const orders = await readOrders();
  const orderIndex = orders.findIndex(o => o.order_id === orderId);
  
  if (orderIndex === -1) {
    throw new Error('Order not found');
  }
  
  orders[orderIndex] = {
    ...orders[orderIndex],
    order_status: newStatus,
    ...updateData
  };
  
  // If status is Completed or Cancelled, free the truck (case-insensitive check)
  const normalizedStatus = (newStatus || '').toUpperCase().trim();
  if (normalizedStatus === 'COMPLETED' || normalizedStatus === 'CANCELLED' || normalizedStatus === 'CANCELED') {
    const vehicleId = orders[orderIndex].vehicle_id;
    if (vehicleId) {
      await updateVehicleStatus(vehicleId, 'Free');
    }
  }
  
  // Write back to CSV
  const ORDERS_CSV_PATH = path.join(__dirname, '../orders.csv');
  const ordersWriter = createCsvWriter({
    path: ORDERS_CSV_PATH,
    header: [
      { id: 'order_id', title: 'order_id' },
      { id: 'user_id', title: 'user_id' },
      { id: 'source', title: 'source' },
      { id: 'destination', title: 'destination' },
      { id: 'material_weight', title: 'material_weight' },
      { id: 'material_type', title: 'material_type' },
      { id: 'trip_type', title: 'trip_type' },
      { id: 'vehicle_id', title: 'vehicle_id' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'order_status', title: 'order_status' },
      { id: 'created_at', title: 'created_at' },
      { id: 'creator_department', title: 'creator_department' },
      { id: 'creator_user_id', title: 'creator_user_id' }, // CRITICAL FIX: Track creator user ID
      { id: 'creator_name', title: 'creator_name' }, // Track creator's full name
      { id: 'trip_segments', title: 'trip_segments' },
      { id: 'is_amended', title: 'is_amended' },
      { id: 'original_trip_type', title: 'original_trip_type' },
      { id: 'order_category', title: 'order_category' },
      { id: 'total_weight', title: 'total_weight' },
      { id: 'total_invoice_amount', title: 'total_invoice_amount' },
      { id: 'total_toll_charges', title: 'total_toll_charges' },
      // Amendment audit trail fields
      { id: 'amendment_requested_by', title: 'amendment_requested_by' },
      { id: 'amendment_requested_department', title: 'amendment_requested_department' },
      { id: 'amendment_requested_at', title: 'amendment_requested_at' },
      { id: 'last_amended_by_user_id', title: 'last_amended_by_user_id' }, // CRITICAL FIX: Track last amendment user ID
      { id: 'last_amended_timestamp', title: 'last_amended_timestamp' }, // CRITICAL FIX: Track last amendment timestamp
      { id: 'amendment_history', title: 'amendment_history' }, // Amendment history (JSON array)
      // Original totals before amendment (for approval summary)
      { id: 'original_total_weight', title: 'original_total_weight' },
      { id: 'original_total_invoice_amount', title: 'original_total_invoice_amount' },
      { id: 'original_total_toll_charges', title: 'original_total_toll_charges' },
      { id: 'original_segment_count', title: 'original_segment_count' },
      // Order lifecycle auditing fields
      { id: 'approved_timestamp', title: 'approved_timestamp' },
      { id: 'approved_by_member', title: 'approved_by_member' },
      { id: 'approved_by_department', title: 'approved_by_department' },
      { id: 'vehicle_started_at_timestamp', title: 'vehicle_started_at_timestamp' },
      { id: 'vehicle_started_from_location', title: 'vehicle_started_from_location' },
      { id: 'security_entry_timestamp', title: 'security_entry_timestamp' },
      { id: 'security_entry_member_name', title: 'security_entry_member_name' },
      { id: 'security_entry_checkpoint_location', title: 'security_entry_checkpoint_location' },
      { id: 'stores_validation_timestamp', title: 'stores_validation_timestamp' },
      { id: 'vehicle_exited_timestamp', title: 'vehicle_exited_timestamp' },
      { id: 'exit_approved_by_timestamp', title: 'exit_approved_by_timestamp' },
      { id: 'exit_approved_by_member_name', title: 'exit_approved_by_member_name' }
    ]
  });
  
  await ordersWriter.writeRecords(orders);
  return orders[orderIndex];
}

// Migrate RFQs to Orders
async function migrateRFQsToOrders() {
  const rfqs = await readRFQs();
  const orders = [];
  let orderCounter = 1000; // Start from Order-1000
  
  // Status mapping: PENDING_APPROVAL→Open, APPROVED→In-Progress, IN_PROGRESS→En-Route, COMPLETED→Completed, REJECTED→Cancelled
  const statusMap = {
    'PENDING_APPROVAL': 'Open',
    'APPROVED': 'In-Progress',
    'IN_PROGRESS': 'En-Route',
    'COMPLETED': 'Completed',
    'REJECTED': 'Cancelled',
    'MODIFICATION_PENDING': 'Open'
  };
  
  for (const rfq of rfqs) {
    const order = {
      order_id: `Order-${orderCounter}`,
      user_id: rfq.userId || rfq.user_id || '',
      source: rfq.source || '',
      destination: rfq.destination || '',
      material_weight: rfq.materialWeight || rfq.material_weight || '0',
      material_type: rfq.materialType || rfq.material_type || '',
      trip_type: 'Single-Trip-Vendor', // Default trip type
      vehicle_id: rfq.vehicleId || rfq.vehicle_id || '',
      vehicle_number: rfq.vehicle_number || rfq.vehicleNumber || '',
      order_status: statusMap[rfq.status] || 'Open',
      created_at: rfq.createdAt || rfq.created_at || new Date().toISOString()
    };
    
    orders.push(order);
    orderCounter++;
  }
  
  // Write all migrated orders to orders.csv
  if (orders.length > 0) {
    const ORDERS_CSV_PATH = path.join(__dirname, '../orders.csv');
    const ordersWriter = createCsvWriter({
      path: ORDERS_CSV_PATH,
      header: [
        { id: 'order_id', title: 'order_id' },
        { id: 'user_id', title: 'user_id' },
        { id: 'source', title: 'source' },
        { id: 'destination', title: 'destination' },
        { id: 'material_weight', title: 'material_weight' },
        { id: 'material_type', title: 'material_type' },
        { id: 'trip_type', title: 'trip_type' },
        { id: 'vehicle_id', title: 'vehicle_id' },
        { id: 'vehicle_number', title: 'vehicle_number' },
        { id: 'order_status', title: 'order_status' },
        { id: 'created_at', title: 'created_at' }
      ]
    });
    
    await ordersWriter.writeRecords(orders);
    console.log(`Migrated ${orders.length} RFQs to Orders`);
  }
  
  return orders;
}

// Department constants for workflow
const SECURITY_DEPARTMENTS = [
  'Security-Factory 1',
  'Security-Factory 2',
  'Security-Factory 3',
  'Security-Factory 4'
];

const STORES_DEPARTMENTS = [
  'Stores IAF UNit-I/ Soliflex unit-I',
  'Stores Unit-IV/ Soliflex unit-II',
  'Soliflex Unit-III',
  'Fabric IAF unit-1 / Soliflex unit-1',
  'Fabric Soliflex unit-III',
  'Fabric Unit-IV/ Soliflex unit-II'
];

// Initialize workflow steps for a segment
// CRITICAL FIX: Create 6 stages - 3 for origin location, 3 for destination location
function initializeSegmentWorkflow(segment, location) {
  const originLocation = segment.source || '';
  const destinationLocation = segment.destination || '';
  
  // Origin location stages (Stages 1-3)
  const originStages = [
    {
      stage: 'SECURITY_ENTRY',
      status: 'PENDING',
      location: originLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 0 // Position in workflow sequence
    },
    {
      stage: 'STORES_VERIFICATION',
      status: 'PENDING',
      location: originLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 1
    },
    {
      stage: 'SECURITY_EXIT',
      status: 'PENDING',
      location: originLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 2
    }
  ];
  
  // Destination location stages (Stages 4-6)
  const destinationStages = [
    {
      stage: 'SECURITY_ENTRY',
      status: 'PENDING',
      location: destinationLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 3
    },
    {
      stage: 'STORES_VERIFICATION',
      status: 'PENDING',
      location: destinationLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 4
    },
    {
      stage: 'SECURITY_EXIT',
      status: 'PENDING',
      location: destinationLocation,
      approved_by: '',
      department: '',
      timestamp: Date.now(),
      comments: '',
      stage_index: 5
    }
  ];
  
  // Combine origin and destination stages (6 total)
  return [...originStages, ...destinationStages];
}

// Check if user can perform workflow action
function canPerformWorkflowAction(userDepartment, userRole, stage, action) {
  // CRITICAL FIX: SUPER_USER absolute override - can perform ANY action on ANY stage
  if (userRole === 'SUPER_USER') {
    console.log(`[canPerformWorkflowAction] SUPER_USER override - allowing ${action} on ${stage}`);
    return true;
  }

  // CRITICAL FIX: Admin department override for APPROVE/REJECT actions
  const normalizedDepartment = (userDepartment || '').toLowerCase().trim();
  const normalizedAction = (action || '').toUpperCase().trim();
  
  if (normalizedAction === 'APPROVE' || normalizedAction === 'REJECT') {
    if (normalizedDepartment === 'admin' || normalizedDepartment.includes('admin') ||
        normalizedDepartment === 'accounts team' || normalizedDepartment.includes('accounts') ||
        normalizedDepartment.includes('account')) {
      console.log(`[canPerformWorkflowAction] Admin/Account override - allowing ${action} on ${stage}`);
      return true;
    }
  }

  if (action === 'CANCEL') {
    // Only Admin/Accounts can cancel
    return userRole === 'SUPER_USER' || userRole === 'APPROVAL_MANAGER' ||
           normalizedDepartment === 'admin' || normalizedDepartment.includes('admin') ||
           normalizedDepartment === 'accounts team' || normalizedDepartment.includes('accounts');
  }

  if (action === 'REVOKE') {
    // Admin/Accounts can revoke any rejection
    return userRole === 'SUPER_USER' || userRole === 'APPROVAL_MANAGER' ||
           normalizedDepartment === 'admin' || normalizedDepartment.includes('admin') ||
           normalizedDepartment === 'accounts team' || normalizedDepartment.includes('accounts');
  }

  const isStoresStage = stage === 'STORES_VERIFICATION';
  const isSecurityRole = SECURITY_DEPARTMENTS.includes(userDepartment);
  const isStoresRole = STORES_DEPARTMENTS.includes(userDepartment);

  if (isStoresStage) {
    // Only Stores/Fabric can interact with Verification stage
    return isStoresRole;
  } else {
    // Only Security can interact with Entry/Exit stages
    return isSecurityRole;
  }
}

// Check if a workflow stage is currently active (can be approved/rejected)
// CRITICAL FIX: Updated to handle 6 stages (3 origin + 3 destination) by position/index
function isStageActive(segment, stage, orderStatus, location) {
  // Order must be En-Route
  if (orderStatus !== 'En-Route') {
    return false;
  }

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

  // Sort workflow steps by stage_index to ensure correct order
  workflowSteps.sort((a, b) => {
    const indexA = a.stage_index !== undefined ? a.stage_index : 999;
    const indexB = b.stage_index !== undefined ? b.stage_index : 999;
    return indexA - indexB;
  });

  // Find the current stage by both stage name AND location
  const currentStage = workflowSteps.find(ws => 
    ws.stage === stage && 
    (!location || ws.location === location)
  );
  
  if (!currentStage || currentStage.status !== 'PENDING') {
    return false;
  }

  // Get current stage index (0-5 for 6 stages)
  const currentStageIndex = currentStage.stage_index !== undefined ? currentStage.stage_index : 
    workflowSteps.indexOf(currentStage);

  // First stage (index 0): Active if order is En-Route and no prior rejection
  if (currentStageIndex === 0) {
    return true;
  }

  // Check if any prior stage is REJECTED (blocking condition)
  for (let i = 0; i < currentStageIndex; i++) {
    const priorStage = workflowSteps[i];
    if (priorStage && priorStage.status === 'REJECTED') {
      return false;
    }
  }

  // Sequential activation: Stage N is active only if Stage N-1 is APPROVED
  const precedingStage = workflowSteps[currentStageIndex - 1];
  if (!precedingStage) {
    return false;
  }

  // Current stage is active if preceding stage is APPROVED or COMPLETED
  const precedingStatus = (precedingStage.status || '').toUpperCase().trim();
  return precedingStatus === 'APPROVED' || precedingStatus === 'COMPLETED';
}

// CRITICAL FIX: Check if entire order is rejected (at least one stage in any segment is REJECTED)
function isOrderRejected(order, segments) {
  // Check if order status is already REJECTED or CANCELLED
  const normalizedStatus = (order.order_status || '').toUpperCase().trim();
  if (normalizedStatus === 'REJECTED' || normalizedStatus === 'CANCELLED' || normalizedStatus === 'CANCELED') {
    return true;
  }
  
  // Check all segments and all steps for a REJECTED status
  for (const segment of segments) {
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
    
    for (const step of workflowSteps) {
      const stepStatus = (step.status || '').toUpperCase().trim();
      if (stepStatus === 'REJECTED' || stepStatus === 'CANCELLED' || stepStatus === 'CANCELED') {
        return true;
      }
    }
  }
  
  return false;
}

// CRITICAL FIX: Check if entire order is fully completed (all stages in all segments are APPROVED/COMPLETED)
// Updated to handle 6 stages per segment (3 origin + 3 destination)
function isOrderCompleted(order, segments) {
  // If order is already rejected, it cannot be completed
  if (isOrderRejected(order, segments)) {
    return false;
  }
  
  // If no segments, consider it incomplete
  if (!segments || segments.length === 0) {
    return false;
  }
  
  // Order is completed only if every single workflow step across all segments 
  // has a status of 'APPROVED' or 'COMPLETED'
  for (const segment of segments) {
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
    
    // If segment has no workflow, check if order is in terminal state
    if (workflowSteps.length === 0) {
      const normalizedStatus = (order.order_status || '').toUpperCase().trim();
      if (normalizedStatus !== 'COMPLETED') {
        return false;
      }
      continue;
    }
    
    // Sort workflow steps by stage_index to ensure correct order
    workflowSteps.sort((a, b) => {
      const indexA = a.stage_index !== undefined ? a.stage_index : 999;
      const indexB = b.stage_index !== undefined ? b.stage_index : 999;
      return indexA - indexB;
    });
    
    // CRITICAL FIX: Check that all stages are APPROVED or COMPLETED
    // For new format: expect 6 stages (indices 0-5) per segment
    // For old format: accept 3 stages (backward compatibility)
    const expectedStageCount = 6;
    
    // If workflow has old format (3 stages), check all 3
    if (workflowSteps.length < expectedStageCount) {
      // Old format: check if all existing stages are APPROVED/COMPLETED
      for (const step of workflowSteps) {
        const status = (step.status || '').toUpperCase().trim();
        if (status !== 'APPROVED' && status !== 'COMPLETED') {
          return false;
        }
      }
    } else {
      // New format: check all 6 stages (by position/index)
      for (let i = 0; i < expectedStageCount; i++) {
        const step = workflowSteps[i];
        if (!step) {
          return false;
        }
        const status = (step.status || '').toUpperCase().trim();
        if (status !== 'APPROVED' && status !== 'COMPLETED') {
          return false;
        }
      }
    }
  }
  
  return true;
}

// Write all users to CSV (for bulk updates)
async function writeAllUsers(users) {
  initializeCsvFile();
  
  const csvWriter = createCsvWriter({
    path: CSV_FILE_PATH,
    header: [
      { id: 'userId', title: 'userId' },
      { id: 'fullName', title: 'fullName' },
      { id: 'passwordHash', title: 'passwordHash' },
      { id: 'department', title: 'department' },
      { id: 'role', title: 'role' }
    ]
  });

  await csvWriter.writeRecords(users);
}

// Write all vendors to CSV (for bulk updates)
async function writeAllVendors(vendors) {
  const VENDORS_CSV_PATH = path.join(__dirname, '../vendors.csv');
  
  const vendorsWriter = createCsvWriter({
    path: VENDORS_CSV_PATH,
    header: [
      { id: 'S/L', title: 'S/L' },
      { id: 'Vender Place', title: 'Vender Place' },
      { id: 'KL', title: 'KL' },
      { id: 'Pick_up_by_sol_below_3000_kgs', title: 'Pick_up_by_sol_below_3000_kgs' },
      { id: 'Dropped_by_vendor_below_3000_kgs', title: 'Dropped_by_vendor_below_3000_kgs' },
      { id: 'Pick_up_by_sol_between_3000_to_5999_kgs', title: 'Pick_up_by_sol_between_3000_to_5999_kgs' },
      { id: 'Dropped_by_vendor_below_5999_kgs', title: 'Dropped_by_vendor_below_5999_kgs' },
      { id: 'Pick_up_by_sol_above_6000_kgs', title: 'Pick_up_by_sol_above_6000_kgs' },
      { id: 'Dropped_by_vendor_above_6000_kgs', title: 'Dropped_by_vendor_above_6000_kgs' },
      { id: 'Toll charges', title: 'Toll charges' }
    ]
  });

  // Convert vendors array to CSV format
  const csvVendors = vendors.map((v, index) => ({
    'S/L': (index + 1).toString(),
    'Vender Place': v.vendor_name || '',
    'KL': v.kl || '',
    'Pick_up_by_sol_below_3000_kgs': v.pick_up_by_sol_below_3000_kgs || '0',
    'Dropped_by_vendor_below_3000_kgs': v.dropped_by_vendor_below_3000_kgs || '0',
    'Pick_up_by_sol_between_3000_to_5999_kgs': v.pick_up_by_sol_between_3000_to_5999_kgs || '0',
    'Dropped_by_vendor_below_5999_kgs': v.dropped_by_vendor_below_5999_kgs || '0',
    'Pick_up_by_sol_above_6000_kgs': v.pick_up_by_sol_above_6000_kgs || '0',
    'Dropped_by_vendor_above_6000_kgs': v.dropped_by_vendor_above_6000_kgs || '0',
    'Toll charges': v.toll_charges || '0'
  }));

  await vendorsWriter.writeRecords(csvVendors);
}

// Write all vehicles to CSV (for bulk updates)
async function writeAllVehicles(vehicles) {
  const VEHICLES_CSV_PATH = path.join(__dirname, '../vehicles.csv');
  
  const vehiclesWriter = createCsvWriter({
    path: VEHICLES_CSV_PATH,
    header: [
      { id: 'vehicleId', title: 'vehicleId' },
      { id: 'vehicle_number', title: 'vehicle_number' },
      { id: 'type', title: 'type' },
      { id: 'capacity_kg', title: 'capacity_kg' },
      { id: 'vehicle_type', title: 'vehicle_type' },
      { id: 'vendor_vehicle', title: 'vendor_vehicle' },
      { id: 'status', title: 'status' }
    ]
  });

  await vehiclesWriter.writeRecords(vehicles);
}

// Initialize notifications CSV file with headers if it doesn't exist
function initializeNotificationsCsvFile() {
  if (!fs.existsSync(NOTIFICATIONS_CSV_PATH)) {
    const headers = 'notification_id,order_id,recipient_department,notification_type,message,status,created_at,related_user_id\n';
    fs.writeFileSync(NOTIFICATIONS_CSV_PATH, headers, 'utf8');
  }
}

// Read all notifications from CSV
function readNotifications() {
  return new Promise((resolve, reject) => {
    const notifications = [];
    
    if (!fs.existsSync(NOTIFICATIONS_CSV_PATH)) {
      return resolve([]);
    }

    fs.createReadStream(NOTIFICATIONS_CSV_PATH)
      .pipe(csv())
      .on('data', (row) => {
        if (row.notification_id && row.notification_id.trim() !== '') {
          notifications.push(row);
        }
      })
      .on('end', () => {
        resolve(notifications);
      })
      .on('error', (error) => {
        reject(error);
      });
  });
}

// Write notification to CSV
async function writeNotification(notification) {
  initializeNotificationsCsvFile();
  
  const notifications = await readNotifications();
  
  // Generate sequential notification ID
  let maxNotificationId = 0;
  if (notifications.length > 0) {
    maxNotificationId = Math.max(...notifications.map(n => parseInt(n.notification_id) || 0));
  }
  const newNotificationId = maxNotificationId + 1;

  const newNotification = {
    notification_id: newNotificationId.toString(),
    order_id: notification.orderId || '',
    recipient_department: notification.recipientDepartment || '',
    notification_type: notification.notificationType || 'ORDER_CREATED',
    message: notification.message || '',
    status: notification.status || 'unread',
    created_at: notification.createdAt || new Date().toISOString(),
    related_user_id: notification.relatedUserId || ''
  };

  notifications.push(newNotification);

  const notificationsWriter = createCsvWriter({
    path: NOTIFICATIONS_CSV_PATH,
    header: [
      { id: 'notification_id', title: 'notification_id' },
      { id: 'order_id', title: 'order_id' },
      { id: 'recipient_department', title: 'recipient_department' },
      { id: 'notification_type', title: 'notification_type' },
      { id: 'message', title: 'message' },
      { id: 'status', title: 'status' },
      { id: 'created_at', title: 'created_at' },
      { id: 'related_user_id', title: 'related_user_id' }
    ]
  });

  await notificationsWriter.writeRecords(notifications);
  return newNotification;
}

// Get notifications by department
async function getNotificationsByDepartment(department) {
  const notifications = await readNotifications();
  return notifications.filter(n => n.recipient_department === department);
}

// Mark notification as read
async function markNotificationAsRead(notificationId) {
  const notifications = await readNotifications();
  const notificationIndex = notifications.findIndex(n => n.notification_id === notificationId);
  
  if (notificationIndex === -1) {
    throw new Error('Notification not found');
  }
  
  notifications[notificationIndex].status = 'read';
  
  const notificationsWriter = createCsvWriter({
    path: NOTIFICATIONS_CSV_PATH,
    header: [
      { id: 'notification_id', title: 'notification_id' },
      { id: 'order_id', title: 'order_id' },
      { id: 'recipient_department', title: 'recipient_department' },
      { id: 'notification_type', title: 'notification_type' },
      { id: 'message', title: 'message' },
      { id: 'status', title: 'status' },
      { id: 'created_at', title: 'created_at' },
      { id: 'related_user_id', title: 'related_user_id' }
    ]
  });
  
  await notificationsWriter.writeRecords(notifications);
  return notifications[notificationIndex];
}

// Get unread notification count for a department
async function getUnreadNotificationCount(department) {
  const notifications = await readNotifications();
  return notifications.filter(n => 
    n.recipient_department === department && 
    (n.status === 'unread' || n.status === '')
  ).length;
}

module.exports = {
  getISTTimestamp,
  initializeCsvFile,
  readUsers,
  writeUser,
  findUserByCredentials,
  getUserById,
  getDepartments,
  getRoleByDepartment,
  getVendors,
  getVehicles,
  matchVehicles,
  readRFQs,
  getRFQsByUserId,
  getRFQById,
  getRFQsByStatus,
  writeRFQ,
  updateRFQStatus,
  // New order functions
  readVehicles,
  writeVehicles,
  updateVehicleStatus,
  readOrders,
  writeOrder,
  getNextOrderId,
  updateOrderStatus,
  getOrderById,
  migrateRFQsToOrders,
  parseTripSegments,
  stringifyTripSegments,
  calculateOrderCategory,
  // Invoice rate calculation
  calculateInvoiceRate,
  getWeightBracket,
  // Order totals calculation
  calculateOrderTotals,
  // Factory location helper
  isFactoryLocation,
  // Workflow functions
  initializeSegmentWorkflow,
  canPerformWorkflowAction,
  isStageActive,
  isOrderRejected,
  isOrderCompleted,
  SECURITY_DEPARTMENTS,
  STORES_DEPARTMENTS,
  // Vendor pricing functions
  readVendorsWithPricing,
  writeAllUsers,
  writeAllVendors,
  writeAllVehicles,
  // Notification functions
  readNotifications,
  writeNotification,
  getNotificationsByDepartment,
  markNotificationAsRead,
  getUnreadNotificationCount
};

