require('dotenv').config();
const path = require('path');
const fs = require('fs');
const csv = require('csv-parser');
const { getPool } = require('./pool');

function readCsv(filePath) {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(filePath)) return resolve([]);
    const rows = [];
    fs.createReadStream(filePath)
      .pipe(csv())
      .on('data', (row) => rows.push(row))
      .on('end', () => resolve(rows))
      .on('error', reject);
  });
}

async function main() {
  const pool = getPool();

  const usersCsv = path.join(__dirname, '..', 'backend.csv');
  const vendorsCsv = path.join(__dirname, '..', 'vendors.csv');
  const vehiclesCsv = path.join(__dirname, '..', 'vehicles.csv');
  const rfqsCsv = path.join(__dirname, '..', 'rfqs.csv');
  const ordersCsv = path.join(__dirname, '..', 'orders.csv');
  const notificationsCsv = path.join(__dirname, '..', 'notifications.csv');

  const [users, vendors, vehicles, rfqs, orders, notifications] = await Promise.all([
    readCsv(usersCsv),
    readCsv(vendorsCsv),
    readCsv(vehiclesCsv),
    readCsv(rfqsCsv),
    readCsv(ordersCsv),
    readCsv(notificationsCsv),
  ]);

  const client = await pool.connect();
  try {
    await client.query('begin');

    // Insert users (preserve IDs)
    for (const u of users) {
      if (!u.userId) continue;
      await client.query(
        `insert into users (user_id, full_name, password_hash, department, role)
         values ($1,$2,$3,$4,$5)
         on conflict (user_id) do update
           set full_name = excluded.full_name,
               password_hash = excluded.password_hash,
               department = excluded.department,
               role = excluded.role`,
        [parseInt(u.userId, 10), u.fullName, u.passwordHash, u.department, u.role]
      );
    }
    if (users.length > 0) {
      const maxId = Math.max(...users.map((u) => parseInt(u.userId || '0', 10)));
      await client.query(`select setval(pg_get_serial_sequence('users','user_id'), $1, true)`, [maxId]);
    }

    // Vendors (vendors.csv uses "S/L" + "Vender Place")
    for (const v of vendors) {
      const vendorId = parseInt(v['S/L'] || v.vendorId || '0', 10);
      const name = (v['Vender Place'] || v['Vender Place '] || v.name || '').trim();
      if (!vendorId || !name) continue;
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
         ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         on conflict (vendor_id) do update
           set name = excluded.name,
               kl = excluded.kl,
               pick_up_by_sol_below_3000_kgs = excluded.pick_up_by_sol_below_3000_kgs,
               dropped_by_vendor_below_3000_kgs = excluded.dropped_by_vendor_below_3000_kgs,
               pick_up_by_sol_between_3000_to_5999_kgs = excluded.pick_up_by_sol_between_3000_to_5999_kgs,
               dropped_by_vendor_below_5999_kgs = excluded.dropped_by_vendor_below_5999_kgs,
               pick_up_by_sol_above_6000_kgs = excluded.pick_up_by_sol_above_6000_kgs,
               dropped_by_vendor_above_6000_kgs = excluded.dropped_by_vendor_above_6000_kgs,
               toll_charges = excluded.toll_charges`,
        [
          vendorId,
          name,
          v['KL'] || v.kl || '',
          v['Pick_up_by_sol_below_3000_kgs'] || '0',
          v['Dropped_by_vendor_below_3000_kgs'] || '0',
          v['Pick_up_by_sol_between_3000_to_5999_kgs'] || '0',
          v['Dropped_by_vendor_below_5999_kgs'] || '0',
          v['Pick_up_by_sol_above_6000_kgs'] || '0',
          v['Dropped_by_vendor_above_6000_kgs'] || '0',
          v['Toll charges'] || '0',
        ]
      );
    }

    // Vehicles
    for (const v of vehicles) {
      if (!v.vehicleId) continue;
      await client.query(
        `insert into vehicles (vehicle_id, vehicle_number, type, capacity_kg, vehicle_type, vendor_vehicle, status)
         values ($1,$2,$3,$4,$5,$6,$7)
         on conflict (vehicle_id) do update
           set vehicle_number = excluded.vehicle_number,
               type = excluded.type,
               capacity_kg = excluded.capacity_kg,
               vehicle_type = excluded.vehicle_type,
               vendor_vehicle = excluded.vendor_vehicle,
               status = excluded.status`,
        [
          parseInt(v.vehicleId, 10),
          v.vehicle_number,
          v.type || '',
          parseInt(v.capacity_kg || '0', 10) || 0,
          v.vehicle_type || '',
          v.vendor_vehicle || '',
          v.status || 'Free',
        ]
      );
    }

    // RFQs (preserve IDs)
    for (const r of rfqs) {
      if (!r.rfqId) continue;
      await client.query(
        `insert into rfqs (
           rfq_id, user_id, source, destination, material_weight, material_type,
           vehicle_id, vehicle_number, status, total_cost,
           created_at, approved_by, approved_at, rejected_at, rejection_reason, started_at, completed_at
         ) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
         on conflict (rfq_id) do update
           set user_id = excluded.user_id,
               source = excluded.source,
               destination = excluded.destination,
               material_weight = excluded.material_weight,
               material_type = excluded.material_type,
               vehicle_id = excluded.vehicle_id,
               vehicle_number = excluded.vehicle_number,
               status = excluded.status,
               total_cost = excluded.total_cost,
               created_at = excluded.created_at,
               approved_by = excluded.approved_by,
               approved_at = excluded.approved_at,
               rejected_at = excluded.rejected_at,
               rejection_reason = excluded.rejection_reason,
               started_at = excluded.started_at,
               completed_at = excluded.completed_at`,
        [
          parseInt(r.rfqId, 10),
          parseInt(r.userId, 10),
          r.source,
          r.destination,
          parseInt(r.materialWeight || '0', 10) || 0,
          r.materialType,
          r.vehicleId ? parseInt(r.vehicleId, 10) : null,
          r.vehicle_number || '',
          r.status,
          parseInt(r.totalCost || '0', 10) || 0,
          r.createdAt || null,
          r.approvedBy ? parseInt(r.approvedBy, 10) : null,
          r.approvedAt || null,
          r.rejectedAt || null,
          r.rejectionReason || null,
          r.startedAt || null,
          r.completedAt || null,
        ]
      );
    }
    if (rfqs.length > 0) {
      const maxId = Math.max(...rfqs.map((r) => parseInt(r.rfqId || '0', 10)));
      await client.query(`select setval(pg_get_serial_sequence('rfqs','rfq_id'), $1, true)`, [maxId]);
    }

    // Orders
    for (const o of orders) {
      if (!o.order_id) continue;
      await client.query(
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
        )
        on conflict (order_id) do update set
          user_id = excluded.user_id,
          source = excluded.source,
          destination = excluded.destination,
          material_weight = excluded.material_weight,
          material_type = excluded.material_type,
          trip_type = excluded.trip_type,
          vehicle_id = excluded.vehicle_id,
          vehicle_number = excluded.vehicle_number,
          order_status = excluded.order_status,
          created_at = excluded.created_at,
          creator_department = excluded.creator_department,
          creator_user_id = excluded.creator_user_id,
          creator_name = excluded.creator_name,
          trip_segments = excluded.trip_segments,
          is_amended = excluded.is_amended,
          original_trip_type = excluded.original_trip_type,
          order_category = excluded.order_category,
          total_weight = excluded.total_weight,
          total_invoice_amount = excluded.total_invoice_amount,
          total_toll_charges = excluded.total_toll_charges,
          amendment_requested_by = excluded.amendment_requested_by,
          amendment_requested_department = excluded.amendment_requested_department,
          amendment_requested_at = excluded.amendment_requested_at,
          last_amended_by_user_id = excluded.last_amended_by_user_id,
          last_amended_timestamp = excluded.last_amended_timestamp,
          amendment_history = excluded.amendment_history,
          original_total_weight = excluded.original_total_weight,
          original_total_invoice_amount = excluded.original_total_invoice_amount,
          original_total_toll_charges = excluded.original_total_toll_charges,
          original_segment_count = excluded.original_segment_count,
          approved_timestamp = excluded.approved_timestamp,
          approved_by_member = excluded.approved_by_member,
          approved_by_department = excluded.approved_by_department,
          vehicle_started_at_timestamp = excluded.vehicle_started_at_timestamp,
          vehicle_started_from_location = excluded.vehicle_started_from_location,
          security_entry_timestamp = excluded.security_entry_timestamp,
          security_entry_member_name = excluded.security_entry_member_name,
          security_entry_checkpoint_location = excluded.security_entry_checkpoint_location,
          stores_validation_timestamp = excluded.stores_validation_timestamp,
          vehicle_exited_timestamp = excluded.vehicle_exited_timestamp,
          exit_approved_by_timestamp = excluded.exit_approved_by_timestamp,
          exit_approved_by_member_name = excluded.exit_approved_by_member_name`,
        [
          o.order_id,
          parseInt(o.user_id, 10),
          o.source || '',
          o.destination || '',
          parseInt(o.material_weight || '0', 10) || 0,
          o.material_type || '',
          o.trip_type || '',
          o.vehicle_id ? parseInt(o.vehicle_id, 10) : null,
          o.vehicle_number || '',
          o.order_status || '',
          o.created_at || null,
          o.creator_department || '',
          o.creator_user_id ? parseInt(o.creator_user_id, 10) : null,
          o.creator_name || '',
          o.trip_segments || '[]',
          o.is_amended || 'No',
          o.original_trip_type || '',
          o.order_category || '',
          parseInt(o.total_weight || '0', 10) || 0,
          parseInt(o.total_invoice_amount || '0', 10) || 0,
          parseInt(o.total_toll_charges || '0', 10) || 0,
          o.amendment_requested_by || '',
          o.amendment_requested_department || '',
          o.amendment_requested_at || '',
          o.last_amended_by_user_id ? parseInt(o.last_amended_by_user_id, 10) : null,
          o.last_amended_timestamp || '',
          o.amendment_history || '',
          o.original_total_weight || '',
          o.original_total_invoice_amount || '',
          o.original_total_toll_charges || '',
          o.original_segment_count || '',
          o.approved_timestamp || '',
          o.approved_by_member || '',
          o.approved_by_department || '',
          o.vehicle_started_at_timestamp || '',
          o.vehicle_started_from_location || '',
          o.security_entry_timestamp || '',
          o.security_entry_member_name || '',
          o.security_entry_checkpoint_location || '',
          o.stores_validation_timestamp || '',
          o.vehicle_exited_timestamp || '',
          o.exit_approved_by_timestamp || '',
          o.exit_approved_by_member_name || '',
        ]
      );
    }

    // Notifications (preserve IDs)
    for (const n of notifications) {
      if (!n.notification_id) continue;
      await client.query(
        `insert into notifications (
           notification_id, order_id, recipient_department, notification_type, message, status, created_at, related_user_id
         ) values ($1,$2,$3,$4,$5,$6,$7,$8)
         on conflict (notification_id) do update
           set order_id = excluded.order_id,
               recipient_department = excluded.recipient_department,
               notification_type = excluded.notification_type,
               message = excluded.message,
               status = excluded.status,
               created_at = excluded.created_at,
               related_user_id = excluded.related_user_id`,
        [
          parseInt(n.notification_id, 10),
          n.order_id || '',
          n.recipient_department || '',
          n.notification_type || '',
          n.message || '',
          n.status || 'unread',
          n.created_at || null,
          n.related_user_id ? parseInt(n.related_user_id, 10) : null,
        ]
      );
    }
    if (notifications.length > 0) {
      const maxId = Math.max(...notifications.map((n) => parseInt(n.notification_id || '0', 10)));
      await client.query(`select setval(pg_get_serial_sequence('notifications','notification_id'), $1, true)`, [maxId]);
    }

    await client.query('commit');
    console.log('Seed completed from CSV files.');
  } catch (e) {
    await client.query('rollback');
    throw e;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});

