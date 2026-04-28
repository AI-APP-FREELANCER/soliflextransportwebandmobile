require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { getPool } = require('./pool');

async function main() {
  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');
  const pool = getPool();
  await pool.query(sql);
  await pool.end();
  console.log('Postgres schema applied successfully.');
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});

