## PostgreSQL setup (DigitalOcean Managed DB)

### Important security note
- **Do not put DB credentials in the Flutter frontend.** Only the backend connects to Postgres.
- You pasted credentials in chat; **rotate that password** in DigitalOcean after you finish setup.

### 1) Configure environment variables on the backend

Create `backend/.env` (do **not** commit it) based on `backend/.env.example` and set:

- `DATA_STORE=postgres`
- `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
- `PGSSLMODE=require`

### 2) Apply schema to the database

From `backend/`:

```bash
npm run db:migrate
```

This runs `backend/db/schema.sql` against the configured database.

### 3) Start the backend

```bash
npm start
```

### 4) Notes about data

This adds schema + connectivity. If you want to preserve existing data from CSV files, you can seed:

```bash
npm run db:seed:csv
```

This reads `backend.csv`, `vendors.csv`, `vehicles.csv`, `rfqs.csv`, `orders.csv`, `notifications.csv` from the `backend/` folder and upserts them into Postgres.

