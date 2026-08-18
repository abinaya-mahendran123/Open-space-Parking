const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const { backfillNamedTables } = require('./pg_sync');

(function loadLocalEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const raw of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
})();

async function main() {
  const pool = new Pool({
    connectionString: process.env.DATABASE_URL || process.env.SUPABASE_DB_URL,
    ssl: { rejectUnauthorized: false },
  });
  await backfillNamedTables(pool);
  const counts = await pool.query(`
    select 'users' as table, count(*)::int as n from users
    union all select 'bookings', count(*)::int from bookings
    union all select 'payments', count(*)::int from payments
    union all select 'land_owner_requests', count(*)::int from land_owner_requests
    union all select 'vehicle_owner_profiles', count(*)::int from vehicle_owner_profiles
    union all select 'notifications', count(*)::int from notifications
    order by 1
  `);
  for (const row of counts.rows) {
    console.log(`${row.table}: ${row.n}`);
  }
  await pool.end();
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
