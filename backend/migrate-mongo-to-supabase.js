const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { MongoClient } = require('mongodb');
const { Pool } = require('pg');

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

const MONGO_URI =
  process.env.MONGO_MIGRATE_URI ||
  process.env.MONGO_CONNECTION_STRING ||
  'mongodb://127.0.0.1:27017/open_space_parking';
const DATABASE_URL = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL || '';
const MONGOD =
  process.env.MONGOD_PATH ||
  'C:\\Users\\HP\\develop\\mongodb\\bin\\mongod.exe';
const CONFIG =
  process.env.MONGOD_CONFIG ||
  'C:\\Users\\HP\\develop\\mongodb\\mongod.cfg';

function canConnectMongo() {
  return new Promise((resolve) => {
    const socket = net.connect({ host: '127.0.0.1', port: 27017 });
    socket.setTimeout(1500);
    socket.once('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.once('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.once('error', () => {
      socket.destroy();
      resolve(false);
    });
  });
}

async function waitForMongo(timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await canConnectMongo()) return true;
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

async function ensureLocalMongo() {
  if (await canConnectMongo()) {
    console.log('Local MongoDB already running on 127.0.0.1:27017');
    return;
  }
  if (!fs.existsSync(MONGOD) || !fs.existsSync(CONFIG)) {
    throw new Error(
      'Local MongoDB is not running. Start mongod, then run: npm run migrate:supabase',
    );
  }
  console.log('Starting local mongod so parking tickets can be copied...');
  const child = spawn(MONGOD, ['--config', CONFIG], {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });
  child.unref();
  if (!(await waitForMongo())) {
    throw new Error('MongoDB did not start on 127.0.0.1:27017');
  }
}

function convert(value) {
  if (value == null) return value;
  const bsonType = value && value._bsontype;
  if (typeof value.toHexString === 'function' && (bsonType === 'ObjectId' || bsonType === 'ObjectID')) {
    return { $oid: value.toHexString() };
  }
  if (value instanceof Date) return value.toISOString();
  if (bsonType === 'Decimal128' || (typeof value === 'object' && typeof value.toNumber === 'function')) {
    try {
      return Number(value.toString());
    } catch (_) {
      return value.toNumber();
    }
  }
  if (Array.isArray(value)) return value.map(convert);
  if (Buffer.isBuffer(value)) return value.toString('base64');
  if (typeof value === 'object') {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = convert(nested);
    }
    return out;
  }
  return value;
}

function docId(doc) {
  const raw = doc._id;
  if (raw && raw.$oid) return raw.$oid;
  if (typeof raw === 'string') return raw;
  if (raw && typeof raw.toHexString === 'function') return raw.toHexString();
  return String(raw);
}

function demoParkingDoc() {
  const now = new Date().toISOString();
  const submittedAt = '2026-08-10T06:57:00.000Z';
  return {
    ticketId: 'OSP-20260810-9430',
    ownerId: 'land-owner-yasin',
    requestType: 'build_parking',
    status: 'approved',
    documentsVerified: true,
    assignedEmployeeId: null,
    assignedEmployeeName: null,
    isDeleted: false,
    ownerDetails: {
      fullName: 'Yasin',
      email: 'aasin12@gmail.com',
      phone: '2345667567',
      address: 'madurai',
    },
    documents: {
      governmentIdPath: 'verified',
      propertyDocumentPath: 'verified',
      pattaPath: 'verified',
      propertyTaxPath: 'verified',
    },
    landDetails: {
      gpsLatitude: 13.052078844064647,
      gpsLongitude: 80.22914082796493,
      areaSqFt: 246,
      roadAccess: true,
      drainage: true,
      flood: false,
      boundary: true,
      cctv: false,
      landAddress: 'madurai',
    },
    parkingPreferences: {
      priority: 'medium',
      parkingType: 'tower_parking',
      numberOfCars: 6,
    },
    submittedAt,
    reviewedAt: now,
    createdAt: submittedAt,
    updatedAt: now,
  };
}

async function main() {
  if (!DATABASE_URL) {
    throw new Error('DATABASE_URL is missing in backend/.env');
  }

  await ensureLocalMongo();

  const mongo = new MongoClient(MONGO_URI);
  const pool = new Pool({
    connectionString: DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });

  await mongo.connect();
  const db = mongo.db();
  const names = (await db.listCollections().toArray())
    .map((c) => c.name)
    .filter((name) => !name.startsWith('system.'));

  console.log(`Copying ${names.length} Mongo collections → Supabase mongo_documents`);

  await pool.query(`
    create table if not exists mongo_documents (
      collection  text not null,
      id          text not null,
      doc         jsonb not null,
      created_at  timestamptz not null default now(),
      updated_at  timestamptz,
      primary key (collection, id)
    );
    alter table mongo_documents disable row level security;
  `);

  let copied = 0;
  for (const name of names) {
    const docs = await db.collection(name).find({}).toArray();
    let n = 0;
    for (const raw of docs) {
      const stored = convert(raw);
      if (!stored._id) continue;
      if (typeof stored._id === 'string') stored._id = { $oid: stored._id };
      if (stored.isDeleted == null) stored.isDeleted = false;
      const id = docId(stored);
      await pool.query(
        `insert into mongo_documents (collection, id, doc, updated_at)
         values ($1, $2, $3::jsonb, now())
         on conflict (collection, id)
         do update set doc = excluded.doc, updated_at = now()`,
        [name, id, JSON.stringify(stored)],
      );
      n += 1;
      copied += 1;
    }
    console.log(`  ${name}: ${n}`);
  }

  const requests = await pool.query(
    `select count(*)::int as n from mongo_documents where collection = 'land_owner_requests'`,
  );
  if (requests.rows[0].n === 0) {
    const { ObjectId } = require('mongodb');
    const stored = convert({ _id: new ObjectId(), ...demoParkingDoc() });
    await pool.query(
      `insert into mongo_documents (collection, id, doc, updated_at)
       values ('land_owner_requests', $1, $2::jsonb, now())
       on conflict (collection, id) do nothing`,
      [docId(stored), JSON.stringify(stored)],
    );
    console.log('No land_owner_requests in Mongo — seeded one verified nearby parking.');
  }

  const after = await pool.query(
    `select count(*)::int as n from mongo_documents where collection = 'land_owner_requests'`,
  );
  console.log(`Done. Copied ${copied} documents.`);
  console.log(`land_owner_requests in Supabase: ${after.rows[0].n}`);

  const { backfillNamedTables } = require('./pg_sync');
  await backfillNamedTables(pool);

  await mongo.close();
  await pool.end();
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
