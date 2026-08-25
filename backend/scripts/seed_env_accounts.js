/**
 * Upserts DEFAULT_ADMIN_* and DEFAULT_SECURITY_* from backend/.env into Postgres.
 * Usage: node scripts/seed_env_accounts.js
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { createPgDb } = require('../pg_store');

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const text = fs.readFileSync(filePath, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
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
    if (process.env[key] == null || process.env[key] === '') {
      process.env[key] = value;
    }
  }
}

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${password}::${salt}`).digest('hex');
}

function generateSalt() {
  return crypto.randomBytes(16).toString('base64url');
}

function phoneDigits(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function phoneLastFour(phone) {
  const digits = phoneDigits(phone);
  if (digits.length < 4) return '';
  return digits.slice(-4);
}

function normalizePhoneNumber(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  if (String(phone || '').trim().startsWith('+')) return `+${digits}`;
  return `+${digits}`;
}

async function upsertUser(users, doc) {
  const existing = await users.findOne({ email: doc.email });
  const now = new Date().toISOString();
  if (existing) {
    await users.updateOne(
      { email: doc.email },
      {
        $set: {
          ...doc,
          updatedAt: now,
          isDeleted: false,
        },
      },
    );
    return 'updated';
  }
  await users.insertOne({ ...doc, createdAt: now });
  return 'inserted';
}

async function main() {
  loadEnvFile(path.join(__dirname, '..', '.env'));
  const databaseUrl = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is missing in backend/.env');
  }

  const adminEmail = (process.env.DEFAULT_ADMIN_EMAIL || '').trim().toLowerCase();
  const adminPassword = process.env.DEFAULT_ADMIN_PASSWORD || '';
  const adminName = process.env.DEFAULT_ADMIN_NAME || 'Admin';
  if (!adminEmail || !adminPassword) {
    throw new Error('DEFAULT_ADMIN_EMAIL and DEFAULT_ADMIN_PASSWORD must be set in .env');
  }

  const securityEmail = (
    process.env.DEFAULT_SECURITY_EMAIL || 'security@openspace.local'
  )
    .trim()
    .toLowerCase();
  const securityName = process.env.DEFAULT_SECURITY_NAME || 'Gate Security';
  const securityPhone = normalizePhoneNumber(
    process.env.DEFAULT_SECURITY_PHONE || '9999999999',
  );

  const db = await createPgDb(databaseUrl);
  const users = db.collection('users');

  const adminSalt = generateSalt();
  const adminAction = await upsertUser(users, {
    email: adminEmail,
    displayName: adminName,
    role: 'admin',
    authProvider: 'password',
    passwordHash: hashPassword(adminPassword, adminSalt),
    passwordSalt: adminSalt,
  });

  const securitySalt = generateSalt();
  const securityPassword = phoneLastFour(securityPhone);
  const securityAction = await upsertUser(users, {
    email: securityEmail,
    phone: securityPhone,
    displayName: securityName,
    role: 'security',
    authProvider: 'password',
    passwordHash: hashPassword(securityPassword, securitySalt),
    passwordSalt: securitySalt,
  });

  const admin = await users.findOne({ email: adminEmail });
  const security = await users.findOne({ email: securityEmail });

  console.log(JSON.stringify({
    ok: true,
    database: 'Supabase PostgreSQL',
    admin: {
      action: adminAction,
      id: admin && (admin._id || admin.id),
      email: adminEmail,
      role: 'admin',
      table: 'public.users',
    },
    security: {
      action: securityAction,
      id: security && (security._id || security.id),
      email: securityEmail,
      phone: securityPhone,
      role: 'security',
      passwordHint: 'last 4 digits of phone',
      table: 'public.users',
    },
  }, null, 2));

  await db.pool.end();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
