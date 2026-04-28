const { getPool } = require('../db/pool');
const csvLogic = require('./csvDatabaseService');

// NOTE: We reuse non-I/O business logic helpers from csvDatabaseService
// (e.g., role mapping, order totals, workflow helpers) to keep behavior identical.

async function ensureSchema() {
  // Schema creation is handled by `backend/db/schema.sql` (run via migrate script).
  // We keep this as a no-op to match the CSV service interface.
  return true;
}

// -----------------------
// Users / Auth
// -----------------------
async function initializeCsvFile() {
  // Keep compatibility with existing startup call in authRoutes.
  return ensureSchema();
}

async function readUsers() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select user_id as "userId",
            full_name as "fullName",
            password_hash as "passwordHash",
            department,
            role
       from users
      order by user_id asc`
  );
  return rows;
}

async function writeUser(user) {
  const pool = getPool();

  // Enforce unique (fullName, department) like CSV behavior
  const existing = await pool.query(
    `select 1
       from users
      where lower(full_name) = lower($1)
        and lower(department) = lower($2)
      limit 1`,
    [user.fullName, user.department]
  );
  if (existing.rowCount > 0) {
    throw new Error(
      'User with this name already exists in this department. Please use a unique identifier or variation (e.g., adding a middle initial, employee ID, or a number) to differentiate your user name.'
    );
  }

  const role = getRoleByDepartment(user.department);

  const { rows } = await pool.query(
    `insert into users (full_name, password_hash, department, role)
     values ($1, $2, $3, $4)
     returning user_id as "userId",
               full_name as "fullName",
               password_hash as "passwordHash",
               department,
               role`,
    [user.fullName, user.passwordHash, user.department, role]
  );
  return rows[0];
}

async function findUserByCredentials(fullName, department) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select user_id as "userId",
            full_name as "fullName",
            password_hash as "passwordHash",
            department,
            role
       from users
      where lower(full_name) = lower($1)
        and lower(department) = lower($2)
      limit 1`,
    [fullName, department]
  );
  return rows[0] || null;
}

async function getUserById(userId) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select user_id as "userId",
            full_name as "fullName",
            password_hash as "passwordHash",
            department,
            role
       from users
      where user_id = $1`,
    [parseInt(userId, 10)]
  );
  return rows[0] || null;
}

function getDepartments() {
  // Keep static list identical to CSV service for now.
  return csvLogic.getDepartments();
}

function getRoleByDepartment(department) {
  return csvLogic.getRoleByDepartment(department);
}

// -----------------------
// Vendors
// -----------------------
async function getVendors() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select vendor_id as "vendorId", name
       from vendors
      order by vendor_id asc`
  );
  return rows;
}

async function readVendorsWithPricing() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select vendor_id as "vendorId",
            name as "vendor_name",
            kl,
            pick_up_by_sol_below_3000_kgs,
            dropped_by_vendor_below_3000_kgs,
            pick_up_by_sol_between_3000_to_5999_kgs,
            dropped_by_vendor_below_5999_kgs,
            pick_up_by_sol_above_6000_kgs,
            dropped_by_vendor_above_6000_kgs,
            toll_charges
       from vendors
      order by vendor_id asc`
  );
  return rows;
}

async function writeAllVendors(vendors) {
  // Used by adminRoutes. We do a replace-all in a transaction.
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('delete from vendors');
    for (const v of vendors) {
      await client.query(
        `insert into vendors (
           vendor_id, name, kl,
           pick_up_by_sol_below_3000_kgs,
           dropped_by_vendor_below_3000_kgs,
           pick_up_by_sol_between_3000_to_5999_kgs,
           dropped_by_vendor_below_5999_kgs,
           pick_up_by_sol_above_6000_kgs,
           dropped_by_vendor_above_6000_kgs,
           toll_charges
         ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [
          parseInt(v.vendorId || v.vendor_id || v['S/L'] || 0, 10) || null,
          v.name || v.vendor_name || v['Vender Place'] || '',
          v.kl || '',
          v.pick_up_by_sol_below_3000_kgs || '0',
          v.dropped_by_vendor_below_3000_kgs || '0',
          v.pick_up_by_sol_between_3000_to_5999_kgs || '0',
          v.dropped_by_vendor_below_5999_kgs || '0',
          v.pick_up_by_sol_above_6000_kgs || '0',
          v.dropped_by_vendor_above_6000_kgs || '0',
          v.toll_charges || v['Toll charges'] || '0',
        ]
      );
    }
    await client.query('commit');
  } catch (e) {
    await client.query('rollback');
    throw e;
  } finally {
    client.release();
  }
}

// -----------------------
// Vehicles
// -----------------------
async function readVehicles() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select vehicle_id as "vehicleId",
            vehicle_number as "vehicle_number",
            type,
            capacity_kg,
            vehicle_type,
            vendor_vehicle,
            status,
            (status = 'Booked') as "is_busy"
       from vehicles
      order by vehicle_id asc`
  );
  return rows.map((r) => ({
    ...r,
    vehicleId: r.vehicleId.toString(),
    capacity_kg: parseInt(r.capacity_kg, 10) || 0,
  }));
}

async function getVehicles(filterBusy = null) {
  let vehicles = await readVehicles();
  if (filterBusy !== null) {
    vehicles = vehicles.filter((v) => v.is_busy === filterBusy);
  }
  return vehicles;
}

async function writeAllVehicles(vehicles) {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('delete from vehicles');
    for (const v of vehicles) {
      await client.query(
        `insert into vehicles (
           vehicle_id, vehicle_number, type, capacity_kg, vehicle_type, vendor_vehicle, status
         ) values ($1,$2,$3,$4,$5,$6,$7)`,
        [
          parseInt(v.vehicleId || v.vehicle_id || 0, 10) || null,
          v.vehicle_number,
          v.type || '',
          parseInt(v.capacity_kg, 10) || 0,
          v.vehicle_type || '',
          v.vendor_vehicle || '',
          v.status || 'Free',
        ]
      );
    }
    await client.query('commit');
  } catch (e) {
    await client.query('rollback');
    throw e;
  } finally {
    client.release();
  }
}

async function updateVehicleStatus(vehicleId, status) {
  const pool = getPool();
  const { rows } = await pool.query(
    `update vehicles
        set status = $2
      where vehicle_id = $1
      returning vehicle_id as "vehicleId",
                vehicle_number as "vehicle_number",
                type,
                capacity_kg,
                vehicle_type,
                vendor_vehicle,
                status`,
    [parseInt(vehicleId, 10), status]
  );
  if (rows.length === 0) throw new Error('Vehicle not found');
  return {
    ...rows[0],
    vehicleId: rows[0].vehicleId.toString(),
    is_busy: rows[0].status === 'Booked',
  };
}

async function matchVehicles(materialWeight) {
  // Reuse CSV matching semantics: only "Free" vehicles qualify.
  const vehicles = await readVehicles();
  const availableVehicles = vehicles.filter((v) => v.status === 'Free');
  return csvLogic.matchVehiclesFromList
    ? csvLogic.matchVehiclesFromList(availableVehicles, materialWeight)
    : // Fallback: reuse same algorithm inline (kept minimal)
      availableVehicles
        .filter((v) => v.capacity_kg >= materialWeight)
        .map((v) => {
          const utilization = (materialWeight / v.capacity_kg) * 100;
          return {
            ...v,
            utilizationPercentage: Math.min(utilization, 100),
            isOptimal: utilization >= 80 && utilization <= 100,
          };
        })
        .sort((a, b) => {
          if (a.isOptimal && !b.isOptimal) return -1;
          if (!a.isOptimal && b.isOptimal) return 1;
          return b.utilizationPercentage - a.utilizationPercentage;
        });
}

// -----------------------
// RFQs
// -----------------------
async function readRFQs() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select rfq_id as "rfqId",
            user_id as "userId",
            source,
            destination,
            material_weight as "materialWeight",
            material_type as "materialType",
            vehicle_id as "vehicleId",
            vehicle_number as "vehicle_number",
            status,
            total_cost as "totalCost",
            created_at as "createdAt",
            approved_by as "approvedBy",
            approved_at as "approvedAt",
            rejected_at as "rejectedAt",
            rejection_reason as "rejectionReason",
            started_at as "startedAt",
            completed_at as "completedAt"
       from rfqs
      order by rfq_id asc`
  );
  return rows.map((r) => ({
    ...r,
    rfqId: r.rfqId.toString(),
    userId: r.userId.toString(),
    materialWeight: r.materialWeight?.toString?.() ?? (r.materialWeight || ''),
    totalCost: r.totalCost?.toString?.() ?? (r.totalCost || '0'),
    vehicleId: r.vehicleId ? r.vehicleId.toString() : '',
    vehicle_number: r.vehicle_number || '',
  }));
}

async function getRFQsByUserId(userId) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select rfq_id as "rfqId",
            user_id as "userId",
            source,
            destination,
            material_weight as "materialWeight",
            material_type as "materialType",
            vehicle_id as "vehicleId",
            vehicle_number as "vehicle_number",
            status,
            total_cost as "totalCost",
            created_at as "createdAt",
            approved_by as "approvedBy",
            approved_at as "approvedAt",
            rejected_at as "rejectedAt",
            rejection_reason as "rejectionReason",
            started_at as "startedAt",
            completed_at as "completedAt"
       from rfqs
      where user_id = $1
      order by rfq_id asc`,
    [parseInt(userId, 10)]
  );
  return rows.map((r) => ({
    ...r,
    rfqId: r.rfqId.toString(),
    userId: r.userId.toString(),
    vehicleId: r.vehicleId ? r.vehicleId.toString() : '',
  }));
}

async function getRFQById(rfqId) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select rfq_id as "rfqId",
            user_id as "userId",
            source,
            destination,
            material_weight as "materialWeight",
            material_type as "materialType",
            vehicle_id as "vehicleId",
            vehicle_number as "vehicle_number",
            status,
            total_cost as "totalCost",
            created_at as "createdAt",
            approved_by as "approvedBy",
            approved_at as "approvedAt",
            rejected_at as "rejectedAt",
            rejection_reason as "rejectionReason",
            started_at as "startedAt",
            completed_at as "completedAt"
       from rfqs
      where rfq_id = $1`,
    [parseInt(rfqId, 10)]
  );
  if (rows.length === 0) return null;
  const r = rows[0];
  return {
    ...r,
    rfqId: r.rfqId.toString(),
    userId: r.userId.toString(),
    vehicleId: r.vehicleId ? r.vehicleId.toString() : '',
  };
}

async function getRFQsByStatus(status) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select rfq_id as "rfqId",
            user_id as "userId",
            source,
            destination,
            material_weight as "materialWeight",
            material_type as "materialType",
            vehicle_id as "vehicleId",
            vehicle_number as "vehicle_number",
            status,
            total_cost as "totalCost",
            created_at as "createdAt",
            approved_by as "approvedBy",
            approved_at as "approvedAt",
            rejected_at as "rejectedAt",
            rejection_reason as "rejectionReason",
            started_at as "startedAt",
            completed_at as "completedAt"
       from rfqs
      where status = $1
      order by rfq_id asc`,
    [status]
  );
  return rows.map((r) => ({
    ...r,
    rfqId: r.rfqId.toString(),
    userId: r.userId.toString(),
    vehicleId: r.vehicleId ? r.vehicleId.toString() : '',
  }));
}

async function writeRFQ(rfq) {
  const pool = getPool();
  const { rows } = await pool.query(
    `insert into rfqs (
        user_id, source, destination, material_weight, material_type,
        vehicle_id, vehicle_number, status, total_cost,
        created_at, approved_by, approved_at, rejected_at, rejection_reason, started_at, completed_at
     ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,
               $10,$11,$12,$13,$14,$15,$16)
     returning rfq_id as "rfqId"`,
    [
      parseInt(rfq.userId, 10),
      rfq.source,
      rfq.destination,
      parseInt(rfq.materialWeight, 10) || 0,
      rfq.materialType,
      rfq.vehicleId ? parseInt(rfq.vehicleId, 10) : null,
      rfq.vehicle_number || '',
      rfq.status || 'PENDING_APPROVAL',
      parseInt(rfq.totalCost, 10) || 0,
      rfq.createdAt || new Date().toISOString(),
      rfq.approvedBy || null,
      rfq.approvedAt || null,
      rfq.rejectedAt || null,
      rfq.rejectionReason || null,
      rfq.startedAt || null,
      rfq.completedAt || null,
    ]
  );
  return getRFQById(rows[0].rfqId);
}

async function updateRFQStatus(rfqId, status, extraFields = {}) {
  const pool = getPool();
  const fields = {
    status,
    approved_by: extraFields.approvedBy ? parseInt(extraFields.approvedBy, 10) : null,
    approved_at: extraFields.approvedAt || null,
    rejected_at: extraFields.rejectedAt || null,
    rejection_reason: extraFields.rejectionReason || null,
    started_at: extraFields.startedAt || null,
    completed_at: extraFields.completedAt || null,
  };

  await pool.query(
    `update rfqs
        set status = $2,
            approved_by = coalesce($3, approved_by),
            approved_at = coalesce($4, approved_at),
            rejected_at = coalesce($5, rejected_at),
            rejection_reason = coalesce($6, rejection_reason),
            started_at = coalesce($7, started_at),
            completed_at = coalesce($8, completed_at)
      where rfq_id = $1`,
    [
      parseInt(rfqId, 10),
      fields.status,
      fields.approved_by,
      fields.approved_at,
      fields.rejected_at,
      fields.rejection_reason,
      fields.started_at,
      fields.completed_at,
    ]
  );
  return getRFQById(rfqId);
}

// -----------------------
// Orders (core persistence)
// -----------------------
async function readOrders() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select order_id as "order_id",
            user_id as "user_id",
            source,
            destination,
            material_weight as "material_weight",
            material_type as "material_type",
            trip_type as "trip_type",
            vehicle_id as "vehicle_id",
            vehicle_number as "vehicle_number",
            order_status as "order_status",
            created_at as "created_at",
            creator_department as "creator_department",
            creator_user_id as "creator_user_id",
            creator_name as "creator_name",
            trip_segments as "trip_segments",
            is_amended as "is_amended",
            original_trip_type as "original_trip_type",
            order_category as "order_category",
            total_weight as "total_weight",
            total_invoice_amount as "total_invoice_amount",
            total_toll_charges as "total_toll_charges",
            amendment_requested_by as "amendment_requested_by",
            amendment_requested_department as "amendment_requested_department",
            amendment_requested_at as "amendment_requested_at",
            last_amended_by_user_id as "last_amended_by_user_id",
            last_amended_timestamp as "last_amended_timestamp",
            amendment_history as "amendment_history",
            original_total_weight as "original_total_weight",
            original_total_invoice_amount as "original_total_invoice_amount",
            original_total_toll_charges as "original_total_toll_charges",
            original_segment_count as "original_segment_count",
            approved_timestamp as "approved_timestamp",
            approved_by_member as "approved_by_member",
            approved_by_department as "approved_by_department",
            vehicle_started_at_timestamp as "vehicle_started_at_timestamp",
            vehicle_started_from_location as "vehicle_started_from_location",
            security_entry_timestamp as "security_entry_timestamp",
            security_entry_member_name as "security_entry_member_name",
            security_entry_checkpoint_location as "security_entry_checkpoint_location",
            stores_validation_timestamp as "stores_validation_timestamp",
            vehicle_exited_timestamp as "vehicle_exited_timestamp",
            exit_approved_by_timestamp as "exit_approved_by_timestamp",
            exit_approved_by_member_name as "exit_approved_by_member_name"
       from orders
      order by created_at desc nulls last, order_id desc`
  );

  return rows.map((o) => ({
    ...o,
    // Keep parity with CSV strings
    material_weight: o.material_weight?.toString?.() ?? (o.material_weight || ''),
    total_weight: o.total_weight?.toString?.() ?? (o.total_weight || ''),
    total_invoice_amount: o.total_invoice_amount?.toString?.() ?? (o.total_invoice_amount || ''),
    total_toll_charges: o.total_toll_charges?.toString?.() ?? (o.total_toll_charges || ''),
    vehicle_id: o.vehicle_id ? o.vehicle_id.toString() : '',
    creator_user_id: o.creator_user_id ? o.creator_user_id.toString() : '',
    last_amended_by_user_id: o.last_amended_by_user_id ? o.last_amended_by_user_id.toString() : '',
  }));
}

async function getNextOrderId() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select max((regexp_match(order_id, 'Order-(\\d+)'))[1]::int) as max_num
       from orders`
  );
  const maxNum = rows[0]?.max_num ?? null;
  if (maxNum === null) return 'Order-1000';
  return `Order-${maxNum + 1}`;
}

async function getOrderById(orderId) {
  const pool = getPool();
  const { rows } = await pool.query(`select * from orders where order_id = $1`, [orderId]);
  if (rows.length === 0) return null;
  // Return in same shape as readOrders row mapper
  const all = await readOrders();
  return all.find((o) => o.order_id === orderId) || null;
}

async function writeOrder(order) {
  const pool = getPool();

  // Keep CSV defaults/derivations using shared logic
  if (typeof order.trip_segments === 'object' || Array.isArray(order.trip_segments)) {
    order.trip_segments = csvLogic.stringifyTripSegments(order.trip_segments);
  }
  if (!order.trip_segments || order.trip_segments.trim() === '') order.trip_segments = '[]';

  if (!order.is_amended || order.is_amended.trim() === '') order.is_amended = 'No';
  if (!order.original_trip_type || order.original_trip_type.trim() === '') {
    order.original_trip_type = order.trip_type || 'Single-Trip-Vendor';
  }
  if (!order.order_category || order.order_category.trim() === '') {
    order.order_category = csvLogic.calculateOrderCategory(order.trip_segments);
  }
  const orderTripType = order.original_trip_type || order.trip_type || 'Single-Trip-Vendor';
  const totals = csvLogic.calculateOrderTotals(order.trip_segments, orderTripType);
  order.total_weight = order.total_weight || totals.total_weight.toString();
  order.total_invoice_amount = order.total_invoice_amount || totals.total_invoice_amount.toString();
  order.total_toll_charges = order.total_toll_charges || totals.total_toll_charges.toString();

  if (!order.vehicle_id) order.vehicle_id = '';
  if (!order.vehicle_number) order.vehicle_number = '';

  const existing = await pool.query(`select 1 from orders where order_id = $1`, [order.order_id]);
  if (existing.rowCount === 0) {
    await pool.query(
      `insert into orders (
        order_id, user_id, source, destination, material_weight, material_type,
        trip_type, vehicle_id, vehicle_number, order_status, created_at,
        creator_department, creator_user_id, creator_name,
        trip_segments, is_amended, original_trip_type, order_category,
        total_weight, total_invoice_amount, total_toll_charges,
        amendment_requested_by, amendment_requested_department, amendment_requested_at,
        last_amended_by_user_id, last_amended_timestamp, amendment_history,
        original_total_weight, original_total_invoice_amount, original_total_toll_charges, original_segment_count,
        approved_timestamp, approved_by_member, approved_by_department,
        vehicle_started_at_timestamp, vehicle_started_from_location,
        security_entry_timestamp, security_entry_member_name, security_entry_checkpoint_location,
        stores_validation_timestamp, vehicle_exited_timestamp,
        exit_approved_by_timestamp, exit_approved_by_member_name
      ) values (
        $1,$2,$3,$4,$5,$6,
        $7,$8,$9,$10,$11,
        $12,$13,$14,
        $15,$16,$17,$18,
        $19,$20,$21,
        $22,$23,$24,
        $25,$26,$27,
        $28,$29,$30,$31,
        $32,$33,$34,
        $35,$36,
        $37,$38,$39,
        $40,$41,
        $42,$43,
        $44,$45
      )`,
      [
        order.order_id,
        parseInt(order.user_id, 10),
        order.source || '',
        order.destination || '',
        parseInt(order.material_weight, 10) || 0,
        order.material_type || '',
        order.trip_type || '',
        order.vehicle_id ? parseInt(order.vehicle_id, 10) : null,
        order.vehicle_number || '',
        order.order_status || 'Open',
        order.created_at || new Date().toISOString(),
        order.creator_department || '',
        order.creator_user_id ? parseInt(order.creator_user_id, 10) : null,
        order.creator_name || '',
        order.trip_segments,
        order.is_amended || 'No',
        order.original_trip_type || '',
        order.order_category || '',
        parseInt(order.total_weight, 10) || 0,
        parseInt(order.total_invoice_amount, 10) || 0,
        parseInt(order.total_toll_charges, 10) || 0,
        order.amendment_requested_by || '',
        order.amendment_requested_department || '',
        order.amendment_requested_at || '',
        order.last_amended_by_user_id ? parseInt(order.last_amended_by_user_id, 10) : null,
        order.last_amended_timestamp || '',
        order.amendment_history || '',
        order.original_total_weight || '',
        order.original_total_invoice_amount || '',
        order.original_total_toll_charges || '',
        order.original_segment_count || '',
        order.approved_timestamp || '',
        order.approved_by_member || '',
        order.approved_by_department || '',
        order.vehicle_started_at_timestamp || '',
        order.vehicle_started_from_location || '',
        order.security_entry_timestamp || '',
        order.security_entry_member_name || '',
        order.security_entry_checkpoint_location || '',
        order.stores_validation_timestamp || '',
        order.vehicle_exited_timestamp || '',
        order.exit_approved_by_timestamp || '',
        order.exit_approved_by_member_name || '',
      ]
    );
  } else {
    await pool.query(
      `update orders
          set user_id = $2,
              source = $3,
              destination = $4,
              material_weight = $5,
              material_type = $6,
              trip_type = $7,
              vehicle_id = $8,
              vehicle_number = $9,
              order_status = $10,
              creator_department = $11,
              creator_user_id = $12,
              creator_name = $13,
              trip_segments = $14,
              is_amended = $15,
              original_trip_type = $16,
              order_category = $17,
              total_weight = $18,
              total_invoice_amount = $19,
              total_toll_charges = $20,
              amendment_requested_by = $21,
              amendment_requested_department = $22,
              amendment_requested_at = $23,
              last_amended_by_user_id = $24,
              last_amended_timestamp = $25,
              amendment_history = $26,
              original_total_weight = $27,
              original_total_invoice_amount = $28,
              original_total_toll_charges = $29,
              original_segment_count = $30,
              approved_timestamp = $31,
              approved_by_member = $32,
              approved_by_department = $33,
              vehicle_started_at_timestamp = $34,
              vehicle_started_from_location = $35,
              security_entry_timestamp = $36,
              security_entry_member_name = $37,
              security_entry_checkpoint_location = $38,
              stores_validation_timestamp = $39,
              vehicle_exited_timestamp = $40,
              exit_approved_by_timestamp = $41,
              exit_approved_by_member_name = $42
        where order_id = $1`,
      [
        order.order_id,
        parseInt(order.user_id, 10),
        order.source || '',
        order.destination || '',
        parseInt(order.material_weight, 10) || 0,
        order.material_type || '',
        order.trip_type || '',
        order.vehicle_id ? parseInt(order.vehicle_id, 10) : null,
        order.vehicle_number || '',
        order.order_status || 'Open',
        order.creator_department || '',
        order.creator_user_id ? parseInt(order.creator_user_id, 10) : null,
        order.creator_name || '',
        order.trip_segments,
        order.is_amended || 'No',
        order.original_trip_type || '',
        order.order_category || '',
        parseInt(order.total_weight, 10) || 0,
        parseInt(order.total_invoice_amount, 10) || 0,
        parseInt(order.total_toll_charges, 10) || 0,
        order.amendment_requested_by || '',
        order.amendment_requested_department || '',
        order.amendment_requested_at || '',
        order.last_amended_by_user_id ? parseInt(order.last_amended_by_user_id, 10) : null,
        order.last_amended_timestamp || '',
        order.amendment_history || '',
        order.original_total_weight || '',
        order.original_total_invoice_amount || '',
        order.original_total_toll_charges || '',
        order.original_segment_count || '',
        order.approved_timestamp || '',
        order.approved_by_member || '',
        order.approved_by_department || '',
        order.vehicle_started_at_timestamp || '',
        order.vehicle_started_from_location || '',
        order.security_entry_timestamp || '',
        order.security_entry_member_name || '',
        order.security_entry_checkpoint_location || '',
        order.stores_validation_timestamp || '',
        order.vehicle_exited_timestamp || '',
        order.exit_approved_by_timestamp || '',
        order.exit_approved_by_member_name || '',
      ]
    );
  }

  return getOrderById(order.order_id);
}

async function updateOrderStatus(orderId, status, extraFields = {}) {
  const order = await getOrderById(orderId);
  if (!order) throw new Error('Order not found');
  order.order_status = status;
  // Apply any field overrides passed by existing codepaths
  Object.assign(order, extraFields);
  return writeOrder(order);
}

// -----------------------
// Notifications
// -----------------------
function getISTTimestamp() {
  return csvLogic.getISTTimestamp();
}

async function readNotifications() {
  const pool = getPool();
  const { rows } = await pool.query(
    `select notification_id as "notification_id",
            order_id as "order_id",
            recipient_department as "recipient_department",
            notification_type as "notification_type",
            message,
            status,
            created_at as "created_at",
            related_user_id as "related_user_id"
       from notifications
      order by notification_id desc`
  );
  return rows.map((n) => ({
    ...n,
    notification_id: n.notification_id.toString(),
    related_user_id: n.related_user_id ? n.related_user_id.toString() : '',
  }));
}

async function writeNotification(notification) {
  const pool = getPool();
  const { rows } = await pool.query(
    `insert into notifications (
        order_id, recipient_department, notification_type, message, status, created_at, related_user_id
     ) values ($1,$2,$3,$4,$5,$6,$7)
     returning notification_id as "notification_id"`,
    [
      notification.orderId || notification.order_id || '',
      notification.recipientDepartment || notification.recipient_department || '',
      notification.notificationType || notification.notification_type || '',
      notification.message || '',
      notification.status || 'unread',
      notification.createdAt || notification.created_at || getISTTimestamp(),
      notification.relatedUserId ? parseInt(notification.relatedUserId, 10) : null,
    ]
  );
  const id = rows[0].notification_id;
  const all = await readNotifications();
  return all.find((n) => n.notification_id === id.toString()) || null;
}

async function getNotificationsByDepartment(department) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select notification_id as "notification_id",
            order_id as "order_id",
            recipient_department as "recipient_department",
            notification_type as "notification_type",
            message,
            status,
            created_at as "created_at",
            related_user_id as "related_user_id"
       from notifications
      where recipient_department = $1
      order by notification_id desc`,
    [department]
  );
  return rows.map((n) => ({
    ...n,
    notification_id: n.notification_id.toString(),
    related_user_id: n.related_user_id ? n.related_user_id.toString() : '',
  }));
}

async function markNotificationAsRead(notificationId) {
  const pool = getPool();
  await pool.query(`update notifications set status = 'read' where notification_id = $1`, [
    parseInt(notificationId, 10),
  ]);
  const all = await readNotifications();
  return all.find((n) => n.notification_id === notificationId.toString()) || null;
}

async function getUnreadNotificationCount(department) {
  const pool = getPool();
  const { rows } = await pool.query(
    `select count(*)::int as count
       from notifications
      where recipient_department = $1
        and (status = 'unread' or status = '')`,
    [department]
  );
  return rows[0]?.count ?? 0;
}

// -----------------------
// Shared business logic passthroughs
// -----------------------
const passthrough = [
  'parseTripSegments',
  'stringifyTripSegments',
  'calculateOrderCategory',
  'calculateInvoiceRate',
  'getWeightBracket',
  'calculateOrderTotals',
  'isFactoryLocation',
  'initializeSegmentWorkflow',
  'canPerformWorkflowAction',
  'isStageActive',
  'isOrderRejected',
  'isOrderCompleted',
  'SECURITY_DEPARTMENTS',
  'STORES_DEPARTMENTS',
];

for (const key of passthrough) {
  module.exports[key] = csvLogic[key];
}

module.exports.ensureSchema = ensureSchema;
module.exports.initializeCsvFile = initializeCsvFile;
module.exports.readUsers = readUsers;
module.exports.writeUser = writeUser;
module.exports.findUserByCredentials = findUserByCredentials;
module.exports.getUserById = getUserById;
module.exports.getDepartments = getDepartments;
module.exports.getRoleByDepartment = getRoleByDepartment;
module.exports.getVendors = getVendors;
module.exports.readVendorsWithPricing = readVendorsWithPricing;
module.exports.writeAllVendors = writeAllVendors;
module.exports.readVehicles = readVehicles;
module.exports.getVehicles = getVehicles;
module.exports.writeAllVehicles = writeAllVehicles;
module.exports.updateVehicleStatus = updateVehicleStatus;
module.exports.matchVehicles = matchVehicles;
module.exports.readRFQs = readRFQs;
module.exports.getRFQsByUserId = getRFQsByUserId;
module.exports.getRFQById = getRFQById;
module.exports.getRFQsByStatus = getRFQsByStatus;
module.exports.writeRFQ = writeRFQ;
module.exports.updateRFQStatus = updateRFQStatus;
module.exports.readOrders = readOrders;
module.exports.getNextOrderId = getNextOrderId;
module.exports.writeOrder = writeOrder;
module.exports.updateOrderStatus = updateOrderStatus;
module.exports.getOrderById = getOrderById;
module.exports.getISTTimestamp = getISTTimestamp;
module.exports.readNotifications = readNotifications;
module.exports.writeNotification = writeNotification;
module.exports.getNotificationsByDepartment = getNotificationsByDepartment;
module.exports.markNotificationAsRead = markNotificationAsRead;
module.exports.getUnreadNotificationCount = getUnreadNotificationCount;

