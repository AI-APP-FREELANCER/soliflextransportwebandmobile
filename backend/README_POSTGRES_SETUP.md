## PostgreSQL setup (DigitalOcean Managed DB)

### Important security note
- **Do not put DB credentials in the Flutter frontend.** Only the backend connects to Postgres.
- If a DB password has ever been pasted into chat (yours or an AI assistant's), **rotate it in DigitalOcean immediately** — treat it as compromised regardless of what else happens.

### Shared database, separate schema
This Postgres cluster/database is **shared with another app** (accommodation). That app owns tables in the `public` schema. This project never reads or writes `public` — all transport tables live in `transport_schema`, and `backend/db/pool.js` sets `search_path=transport_schema,public` on every connection so unqualified table names (`from users`, `from orders`, ...) resolve into `transport_schema` automatically. Nothing in this codebase needs to schema-qualify table names because of this.

### 1) Configure environment variables on the backend

Create `backend/.env` (do **not** commit it) based on `backend/.env.example` and set:

- `DATA_STORE=postgres`
- `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
- `PGSSLMODE=require`

### 2) Verify before touching anything (read-only)

```bash
npm run db:verify
```

This only reads: it prints the active `search_path`, lists schemas in the database, lists tables currently in `transport_schema` (if any) with row counts, and checks for table-name collisions in `public` (informational only — it never modifies `public`). Run this first, especially if a previous session may have already run migrations against this database, so you know the actual current state before proceeding.

### 3) Apply schema to the database

From `backend/`:

```bash
npm run db:migrate
```

This runs `backend/db/schema.sql`, which creates `transport_schema` (if it doesn't already exist) and the transport tables inside it. It never touches `public`.

### 4) Notes about data

If you want to preserve existing data from CSV files, seed after migrating:

```bash
npm run db:seed:csv
```

This reads `backend.csv`, `vendors.csv`, `vehicles.csv`, `rfqs.csv`, `orders.csv`, `notifications.csv` from the `backend/` folder and upserts them into `transport_schema` in Postgres.

### 5) Verify again

```bash
npm run db:verify
```

Row counts per table should now match what you'd expect from the CSVs. Compare against `wc -l backend/*.csv` (subtract 1 per file for the header row).

### 6) Start the backend

```bash
npm start
```

