// Read-only diagnostic: finds rfqs.csv / orders.csv rows that reference a
// userId not present in backend.csv. Writes nothing, connects to nothing.
const path = require('path');
const fs = require('fs');
const csv = require('csv-parser');

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

function findConflictMarkers(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const lines = fs.readFileSync(filePath, 'utf8').split('\n');
  const hits = [];
  lines.forEach((line, i) => {
    if (/^(<<<<<<<|=======|>>>>>>>)/.test(line)) hits.push({ lineNo: i + 1, line: line.slice(0, 80) });
  });
  return hits;
}

async function main() {
  const dir = path.join(__dirname, '..');

  // Unresolved git merge conflicts can end up baked into these tracked CSVs
  // (as literally happened with orders.csv) since the live app also writes
  // to them. Check every tracked CSV before anything else.
  const trackedCsvs = ['backend.csv', 'vendors.csv', 'vehicles.csv', 'rfqs.csv', 'orders.csv', 'notifications.csv'];
  let anyMarkers = false;
  for (const name of trackedCsvs) {
    const hits = findConflictMarkers(path.join(dir, name));
    if (hits.length > 0) {
      anyMarkers = true;
      console.log(`CONFLICT MARKERS in ${name}:`);
      hits.forEach((h) => console.log(`  line ${h.lineNo}: ${h.line}`));
    }
  }
  console.log(anyMarkers ? '\n^ resolve the above before seeding.\n' : 'No conflict markers found in any tracked CSV.\n');

  const users = await readCsv(path.join(dir, 'backend.csv'));
  const rfqs = await readCsv(path.join(dir, 'rfqs.csv'));
  const orders = await readCsv(path.join(dir, 'orders.csv'));
  const notifications = await readCsv(path.join(dir, 'notifications.csv'));

  const validUserIds = new Set(users.map((u) => u.userId).filter(Boolean));
  console.log(`backend.csv has ${users.length} users, ids: ${[...validUserIds].join(', ')}`);

  const orphanRfqs = rfqs.filter((r) => r.userId && !validUserIds.has(r.userId));
  console.log(`\nrfqs.csv: ${rfqs.length} rows, ${orphanRfqs.length} with missing userId`);
  orphanRfqs.forEach((r) => console.log('  orphan rfq:', JSON.stringify(r)));

  const orderIssues = orders.filter((o) => {
    const bad = [];
    if (o.user_id && !validUserIds.has(o.user_id)) bad.push(`user_id=${o.user_id}`);
    if (o.creator_user_id && !validUserIds.has(o.creator_user_id)) bad.push(`creator_user_id=${o.creator_user_id}`);
    if (o.last_amended_by_user_id && !validUserIds.has(o.last_amended_by_user_id)) bad.push(`last_amended_by_user_id=${o.last_amended_by_user_id}`);
    o._bad = bad;
    return bad.length > 0;
  });
  console.log(`\norders.csv: ${orders.length} rows, ${orderIssues.length} with missing user reference`);
  orderIssues.forEach((o) => console.log(`  orphan order: order_id=${o.order_id} (${o._bad.join(', ')})`));

  // orders.user_id / rfqs.userId are required (NOT NULL) columns. Find rows
  // where the value is blank or not a valid integer -- these fail the
  // Postgres insert differently (invalid input syntax) than the FK checks
  // above. Report the full row plus creator_user_id as a possible fallback.
  const isBlankOrNonNumeric = (v) => !v || !/^\d+$/.test(String(v).trim());

  const badOrderUserIds = orders.filter((o) => isBlankOrNonNumeric(o.user_id));
  console.log(`\norders.csv: ${badOrderUserIds.length} row(s) with blank/non-numeric user_id`);
  badOrderUserIds.forEach((o) =>
    console.log(
      `  order_id=${o.order_id} user_id=${JSON.stringify(o.user_id)} creator_user_id=${JSON.stringify(o.creator_user_id)} creator_name=${JSON.stringify(o.creator_name)} created_at=${o.created_at}`
    )
  );

  const badRfqUserIds = rfqs.filter((r) => isBlankOrNonNumeric(r.userId));
  console.log(`\nrfqs.csv: ${badRfqUserIds.length} row(s) with blank/non-numeric userId`);
  badRfqUserIds.forEach((r) => console.log('  rfq:', JSON.stringify(r)));

  // notification_id is a required (NOT NULL) serial-backed int column too.
  const badNotificationIds = notifications.filter((n) => isBlankOrNonNumeric(n.notification_id));
  console.log(`\nnotifications.csv: ${notifications.length} rows, ${badNotificationIds.length} with blank/non-numeric notification_id`);
  badNotificationIds.forEach((n) => console.log('  notification:', JSON.stringify(n)));

  const badNotificationUserRefs = notifications.filter(
    (n) => n.related_user_id && !validUserIds.has(n.related_user_id)
  );
  console.log(`notifications.csv: ${badNotificationUserRefs.length} row(s) with related_user_id not in backend.csv`);
  badNotificationUserRefs.forEach((n) => console.log('  notification:', JSON.stringify(n)));
}

main().catch((err) => {
  console.error('Check failed:', err);
  process.exit(1);
});
