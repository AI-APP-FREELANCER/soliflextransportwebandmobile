const { Pool } = require('pg');

function buildPoolConfigFromEnv() {
  const host = process.env.PGHOST;
  const port = process.env.PGPORT ? parseInt(process.env.PGPORT, 10) : undefined;
  const database = process.env.PGDATABASE;
  const user = process.env.PGUSER;
  const password = process.env.PGPASSWORD;

  const sslmode = (process.env.PGSSLMODE || '').toLowerCase();
  const ssl =
    sslmode === 'require' || sslmode === 'verify-full' || sslmode === 'verify-ca'
      ? { rejectUnauthorized: false }
      : false;

  return {
    host,
    port,
    database,
    user,
    password,
    ssl,
    max: process.env.PGPOOL_MAX ? parseInt(process.env.PGPOOL_MAX, 10) : 10,
    idleTimeoutMillis: process.env.PGPOOL_IDLE_MS ? parseInt(process.env.PGPOOL_IDLE_MS, 10) : 30000,
    connectionTimeoutMillis: process.env.PGPOOL_CONN_TIMEOUT_MS
      ? parseInt(process.env.PGPOOL_CONN_TIMEOUT_MS, 10)
      : 10000,
  };
}

let pool;

function getPool() {
  if (!pool) {
    pool = new Pool(buildPoolConfigFromEnv());
  }
  return pool;
}

module.exports = {
  getPool,
};

