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

async function main() {
  const dir = path.join(__dirname, '..');
  const users = await readCsv(path.join(dir, 'backend.csv'));
  const rfqs = await readCsv(path.join(dir, 'rfqs.csv'));
  const orders = await readCsv(path.join(dir, 'orders.csv'));

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
}

main().catch((err) => {
  console.error('Check failed:', err);
  process.exit(1);
});
