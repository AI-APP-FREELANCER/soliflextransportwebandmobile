require('dotenv').config();
const { getPool } = require('./pool');

const TRANSPORT_TABLES = ['users', 'vendors', 'vehicles', 'rfqs', 'orders', 'notifications'];

async function main() {
  const pool = getPool();

  const searchPath = await pool.query('show search_path');
  console.log('search_path:', searchPath.rows[0].search_path);

  const schemas = await pool.query(
    `select schema_name from information_schema.schemata order by schema_name`
  );
  console.log(
    'schemas in database:',
    schemas.rows.map((r) => r.schema_name).join(', ')
  );

  const transportTables = await pool.query(
    `select table_name from information_schema.tables
      where table_schema = 'transport_schema'
      order by table_name`
  );
  console.log(
    'tables in transport_schema:',
    transportTables.rows.map((r) => r.table_name).join(', ') || '(none yet)'
  );

  for (const table of transportTables.rows.map((r) => r.table_name)) {
    const { rows } = await pool.query(`select count(*)::int as n from transport_schema.${table}`);
    console.log(`  transport_schema.${table}: ${rows[0].n} rows`);
  }

  // Read-only check that we are not colliding with the accommodation app's
  // tables in `public`. This never modifies anything.
  const publicCollisions = await pool.query(
    `select table_name from information_schema.tables
      where table_schema = 'public' and table_name = any($1)`,
    [TRANSPORT_TABLES]
  );
  if (publicCollisions.rowCount > 0) {
    console.log(
      'NOTE: public schema already has same-named table(s):',
      publicCollisions.rows.map((r) => r.table_name).join(', '),
      '-- these belong to the other app and this project does not touch them.'
    );
  } else {
    console.log('No table-name collisions with public schema.');
  }

  await pool.end();
}

main().catch((err) => {
  console.error('Verify failed:', err);
  process.exit(1);
});
