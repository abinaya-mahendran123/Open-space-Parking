const cors = require('cors');
const crypto = require('crypto');
const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { MongoClient, ObjectId } = require('mongodb');
const { createPgDb } = require('./pg_store');
const {
  nearbyVerifiedListings,
  verifiedListingById,
  isEmployeeVerifiedListing,
} = require('./parking_listings');

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

const PORT = Number(process.env.PORT || 3000);
const DATABASE_URL =
  process.env.DATABASE_URL || process.env.SUPABASE_DB_URL || '';
const MONGO_URI =
  process.env.MONGO_CONNECTION_STRING ||
  (DATABASE_URL ? '' : 'mongodb://127.0.0.1:27017/open_space_parking');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '10mb' }));
app.use((error, _req, res, next) => {
  if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
    res.status(400).json({ error: 'Invalid JSON request body.' });
    return;
  }
  next(error);
});

const uploadDir = path.join(__dirname, 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const uploadStorage = multer.diskStorage({
  destination: uploadDir,
  filename: (_req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}-${safeName}`);
  },
});

const upload = multer({
  storage: uploadStorage,
  limits: { fileSize: 20 * 1024 * 1024 },
});

app.use('/uploads', express.static(uploadDir));

let db;
let client;

function revive(value) {
  if (value == null) return value;
  if (Array.isArray(value)) return value.map(revive);
  if (typeof value === 'object') {
    if (value.$oid && Object.keys(value).length === 1) {
      return new ObjectId(value.$oid);
    }
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = revive(nested);
    }
    return out;
  }
  return value;
}

function serialize(value) {
  if (value == null) return value;
  if (value instanceof ObjectId) {
    return { $oid: value.toHexString() };
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === 'object') {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = serialize(nested);
    }
    return out;
  }
  return value;
}

function parseSelector(selectorMap = {}) {
  if (!selectorMap || typeof selectorMap !== 'object') return {};
  const cloned = { ...selectorMap };
  const nestedQuery = cloned.$query;
  delete cloned.$query;
  delete cloned.$orderby;
  const fromQuery =
    nestedQuery && typeof nestedQuery === 'object' && Object.keys(nestedQuery).length
      ? revive(nestedQuery)
      : {};
  return { ...fromQuery, ...revive(cloned) };
}

function buildSearchFilter(query = {}) {
  const filter = revive({ ...(query.filters || {}) });
  if (!query.includeDeleted) {
    filter.isDeleted = { $ne: true };
  }
  const text = (query.textQuery || '').trim();
  if (text && Array.isArray(query.searchFields) && query.searchFields.length) {
    const regex = new RegExp(text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    filter.$or = query.searchFields.map((field) => ({ [field]: regex }));
  }
  return filter;
}

const DEFAULT_ADMIN_EMAIL =
  (process.env.DEFAULT_ADMIN_EMAIL || 'admin@openspace.local').trim().toLowerCase();
const DEFAULT_ADMIN_PASSWORD = process.env.DEFAULT_ADMIN_PASSWORD || 'Admin@1234';
const DEFAULT_ADMIN_NAME = process.env.DEFAULT_ADMIN_NAME || 'Admin';

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${password}::${salt}`).digest('hex');
}

function generateSalt() {
  return crypto.randomBytes(16).toString('base64url');
}

function asHexId(value) {
  if (value == null) return '';
  if (typeof value === 'string') {
    const match = value.match(/[a-fA-F0-9]{24}/);
    return match ? match[0] : value;
  }
  if (typeof value.toHexString === 'function') return value.toHexString();
  if (typeof value === 'object') {
    if (typeof value.$oid === 'string') return value.$oid;
    if (typeof value.oid === 'string') return value.oid;
  }
  return String(value);
}

async function findActiveUserByEmail(email) {
  return db.collection('users').findOne({
    email: String(email || '').trim().toLowerCase(),
    isDeleted: { $ne: true },
  });
}

function phoneDigits(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function phoneKey(phone) {
  return phoneDigits(phone).slice(-10);
}

async function findActiveUserByPhone(phone) {
  const lastTen = phoneKey(phone);
  if (!lastTen) return null;
  const users = await db
    .collection('users')
    .find({ isDeleted: { $ne: true } })
    .toArray();
  return (
    users.find((user) => phoneKey(user.phone) === lastTen) ||
    users.find((user) => phoneKey(user.email) === lastTen) ||
    null
  );
}

function sessionPayload(user) {
  const role = String(user.role || '');
  const normalized =
    role === 'vehicleOwner' ? 'vehicle_owner' :
    role === 'landOwner' ? 'land_owner' :
    role;
  return {
    userId: asHexId(user._id),
    email: user.email,
    displayName: user.displayName || '',
    role: normalized,
  };
}

async function authenticatePassword(email, password) {
  const user = await findActiveUserByEmail(email);
  if (!user || !user.passwordSalt || !user.passwordHash) {
    return { status: 401, error: 'Invalid credentials.' };
  }
  const computed = hashPassword(password, user.passwordSalt);
  if (computed !== user.passwordHash) {
    return { status: 401, error: 'Invalid credentials.' };
  }
  return { user };
}

async function seedDefaultAdmin(database) {
  const users = database.collection('users');
  const existing = await users.findOne({ email: DEFAULT_ADMIN_EMAIL });

  if (existing) {
    if (existing.role === 'admin' && existing.passwordHash && existing.passwordSalt) {
      return;
    }
    const salt = generateSalt();
    const hash = hashPassword(DEFAULT_ADMIN_PASSWORD, salt);
    await users.updateOne(
      { email: DEFAULT_ADMIN_EMAIL },
      {
        $set: {
          role: 'admin',
          displayName: existing.displayName || DEFAULT_ADMIN_NAME,
          passwordHash: hash,
          passwordSalt: salt,
          isDeleted: false,
          updatedAt: new Date().toISOString(),
        },
      },
    );
    console.log(`Default admin repaired: ${DEFAULT_ADMIN_EMAIL}`);
    return;
  }

  const salt = generateSalt();
  const hash = hashPassword(DEFAULT_ADMIN_PASSWORD, salt);

  await users.insertOne({
    email: DEFAULT_ADMIN_EMAIL,
    displayName: DEFAULT_ADMIN_NAME,
    role: 'admin',
    passwordHash: hash,
    passwordSalt: salt,
    createdAt: new Date().toISOString(),
  });

  console.log(`Default admin seeded: ${DEFAULT_ADMIN_EMAIL}`);
}

async function seedDefaultSecurity(database) {
  const users = database.collection('users');
  const email = (process.env.DEFAULT_SECURITY_EMAIL || 'security@openspace.local')
    .trim()
    .toLowerCase();
  const password = process.env.DEFAULT_SECURITY_PASSWORD || 'Security@1234';
  const name = process.env.DEFAULT_SECURITY_NAME || 'Gate Security';
  const phone = normalizePhoneNumber(
    process.env.DEFAULT_SECURITY_PHONE || '9999999999',
  );
  const now = new Date().toISOString();
  const salt = generateSalt();
  const hash = hashPassword(password, salt);

  await users.updateOne(
    { email },
    {
      $set: {
        email,
        phone,
        displayName: name,
        role: 'security',
        passwordHash: hash,
        passwordSalt: salt,
        isDeleted: false,
        updatedAt: now,
      },
      $setOnInsert: {
        createdAt: now,
      },
    },
    { upsert: true },
  );
  console.log(`Default security ready: ${email}`);
}

async function seedDemoParkingIfEmpty(database) {
  const requests = database.collection('land_owner_requests');
  const count = await requests.countDocuments({ isDeleted: { $ne: true } });
  if (count > 0) return;

  const now = new Date().toISOString();
  await requests.insertOne({
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
    submittedAt: '2026-08-10T06:57:00.000Z',
    reviewedAt: now,
    createdAt: '2026-08-10T06:57:00.000Z',
    updatedAt: now,
  });
  console.log('Seeded demo nearby parking (no land_owner_requests found).');
}

async function ensureIndexes(database) {
  const specs = [
    {
      collection: 'users',
      indexes: [
        { keys: { email: 1 }, unique: true, name: 'idx_users_email' },
        { keys: { phone: 1 }, unique: true, sparse: true, name: 'idx_users_phone' },
        { keys: { role: 1 }, name: 'idx_users_role' },
      ],
    },
    {
      collection: 'employees',
      indexes: [
        { keys: { email: 1 }, unique: true, name: 'idx_employees_email' },
      ],
    },
  ];

  for (const spec of specs) {
    const collection = database.collection(spec.collection);
    for (const index of spec.indexes) {
      const { keys, ...options } = index;
      await collection.createIndex(keys, options);
    }
  }
}

app.post('/api/auth/security-login', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    if (!email || !password) {
      res.status(400).json({ error: 'Invalid credentials.' });
      return;
    }

    const defaultEmail = (
      process.env.DEFAULT_SECURITY_EMAIL || 'security@openspace.local'
    )
      .trim()
      .toLowerCase();
    if (email === defaultEmail) {
      await seedDefaultSecurity(db);
    }

    const user = await db.collection('users').findOne({
      email,
      isDeleted: { $ne: true },
    });
    if (!user || !user.passwordSalt || !user.passwordHash) {
      res.status(401).json({ error: 'Invalid credentials.' });
      return;
    }

    const computed = hashPassword(password, user.passwordSalt);
    if (computed !== user.passwordHash) {
      res.status(401).json({ error: 'Invalid credentials.' });
      return;
    }
    if (user.role !== 'security') {
      res.status(403).json({ error: 'Only security staff can open the gate scanner.' });
      return;
    }

    res.json(sessionPayload(user));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/admin-login', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    if (!email || !password) {
      res.status(400).json({ error: 'Invalid credentials.' });
      return;
    }
    if (email === DEFAULT_ADMIN_EMAIL) {
      await seedDefaultAdmin(db);
    }
    const result = await authenticatePassword(email, password);
    if (result.error) {
      res.status(result.status).json({ error: result.error });
      return;
    }
    if (result.user.role !== 'admin') {
      res.status(403).json({ error: 'Only admins can login to admin portal.' });
      return;
    }
    res.json(sessionPayload(result.user));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/app-login', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    if (!email || !password) {
      res.status(400).json({ error: 'Invalid credentials.' });
      return;
    }
    const result = await authenticatePassword(email, password);
    if (result.error) {
      res.status(result.status).json({ error: result.error });
      return;
    }
    const role = result.user.role;
    if (role === 'employee') {
      res.status(403).json({ error: 'Employee must use employee portal login.' });
      return;
    }
    if (role === 'security') {
      res.status(403).json({ error: 'Security must use the security gate login.' });
      return;
    }
    res.json(sessionPayload(result.user));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    mongoConnected: Boolean(db),
    database: DATABASE_URL ? 'supabase' : 'mongodb',
    razorpay: RAZORPAY_DEMO ? 'demo' : 'live',
    companyAccountConfigured: Boolean(RAZORPAY_COMPANY_ACCOUNT_ID),
  });
});

app.post('/api/parking/nearby', async (_req, res) => {
  try {
    if (!DATABASE_URL) {
      const docs = await db
        .collection('land_owner_requests')
        .find({ isDeleted: { $ne: true } })
        .toArray();
      res.json({
        documents: docs.filter(isEmployeeVerifiedListing).map(serialize),
      });
      return;
    }
    const documents = await nearbyVerifiedListings(db.pool);
    res.json({ documents: documents.map(serialize) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/parking/listing', async (req, res) => {
  try {
    const id = String(req.body?.id || '').trim();
    if (!id) {
      res.status(400).json({ error: 'id is required' });
      return;
    }
    if (!DATABASE_URL) {
      const doc = await db.collection('land_owner_requests').findOne({
        _id: new ObjectId(id),
        isDeleted: { $ne: true },
      });
      res.json({
        document: doc && isEmployeeVerifiedListing(doc) ? serialize(doc) : null,
      });
      return;
    }
    const document = await verifiedListingById(db.pool, id);
    res.json({ document: document ? serialize(document) : null });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/geocode', async (req, res) => {
  try {
    const query = String(req.query.q || '').trim();
    if (!query) {
      res.status(400).json({ error: 'Location name is required.' });
      return;
    }

    const url = new URL('https://nominatim.openstreetmap.org/search');
    url.searchParams.set('q', query);
    url.searchParams.set('format', 'json');
    url.searchParams.set('limit', '1');

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'OpenSpaceParking/1.0',
        Accept: 'application/json',
      },
    });

    if (!response.ok) {
      res.status(502).json({ error: 'Location lookup service unavailable.' });
      return;
    }

    const results = await response.json();
    if (!Array.isArray(results) || results.length === 0) {
      res.status(404).json({
        error:
          'Location not found. Try a more specific name (e.g. Anna Nagar, Chennai).',
      });
      return;
    }

    const match = results[0];
    res.json({
      latitude: Number(match.lat),
      longitude: Number(match.lon),
      displayName: match.display_name,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/reverse-geocode', async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lon = Number(req.query.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      res.status(400).json({ error: 'Valid latitude and longitude are required.' });
      return;
    }

    const url = new URL('https://nominatim.openstreetmap.org/reverse');
    url.searchParams.set('lat', String(lat));
    url.searchParams.set('lon', String(lon));
    url.searchParams.set('format', 'json');

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'OpenSpaceParking/1.0',
        Accept: 'application/json',
      },
    });

    if (!response.ok) {
      res.status(502).json({ error: 'Reverse geocoding service unavailable.' });
      return;
    }

    const match = await response.json();
    if (!match || typeof match !== 'object') {
      res.status(404).json({ error: 'Could not resolve address for this pin.' });
      return;
    }

    res.json({
      latitude: lat,
      longitude: lon,
      displayName: match.display_name || `${lat}, ${lon}`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const otpCodes = new Map();

function hashOtp(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

app.post('/api/auth/send-otp', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body.phone);
    if (!normalizedPhone) {
      res.status(400).json({ error: 'Enter a valid mobile number.' });
      return;
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));
    otpCodes.set(phoneKey(normalizedPhone), {
      hash: hashOtp(otp),
      expiresAt: Date.now() + 5 * 60 * 1000,
    });

    const message = `Your Open Space Parking verification code is ${otp}. Valid for 5 minutes.`;
    const result = await sendOtpSms({ to: normalizedPhone, body: message });

    res.json({
      ok: true,
      phone: normalizedPhone,
      devMode: result.simulated === true,
      otp: result.simulated === true ? otp : undefined,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/verify-otp', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body.phone);
    const otp = String(req.body.otp || '').trim();

    if (!normalizedPhone) {
      res.status(400).json({ error: 'Enter a valid mobile number.' });
      return;
    }
    if (!/^\d{6}$/.test(otp)) {
      res.status(400).json({ error: 'Enter the 6-digit OTP.' });
      return;
    }

    const entry = otpCodes.get(phoneKey(normalizedPhone));
    if (!entry) {
      res.status(400).json({ error: 'OTP expired or not requested. Send a new code.' });
      return;
    }
    if (Date.now() > entry.expiresAt) {
      otpCodes.delete(phoneKey(normalizedPhone));
      res.status(400).json({ error: 'OTP expired. Request a new code.' });
      return;
    }
    if (hashOtp(otp) !== entry.hash) {
      res.status(400).json({ error: 'Invalid OTP. Please try again.' });
      return;
    }

    otpCodes.delete(phoneKey(normalizedPhone));
    res.json({ ok: true, phone: normalizedPhone, verified: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/phone-login', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body?.phone);
    if (!normalizedPhone) {
      res.status(400).json({ error: 'Enter a valid mobile number.' });
      return;
    }

    const defaultSecurityPhone = normalizePhoneNumber(
      process.env.DEFAULT_SECURITY_PHONE || '9999999999',
    );
    if (phoneKey(normalizedPhone) === phoneKey(defaultSecurityPhone)) {
      await seedDefaultSecurity(db);
    }

    const user = await findActiveUserByPhone(normalizedPhone);
    if (!user) {
      res.status(404).json({
        error: 'No account found for this mobile number. Sign up first.',
      });
      return;
    }

    res.json(sessionPayload(user));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/phone-register', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body?.phone);
    const displayName = String(req.body?.displayName || '').trim();
    let role = String(req.body?.role || 'vehicle_owner').trim();
    if (role === 'vehicleOwner') role = 'vehicle_owner';
    if (role === 'landOwner') role = 'land_owner';

    if (!normalizedPhone) {
      res.status(400).json({ error: 'Enter a valid mobile number.' });
      return;
    }
    if (!displayName) {
      res.status(400).json({ error: 'Enter your full name.' });
      return;
    }
    if (role === 'admin' || role === 'employee' || role === 'security') {
      res.status(403).json({ error: 'This role cannot be self-registered.' });
      return;
    }
    if (role !== 'vehicle_owner' && role !== 'land_owner') {
      role = 'vehicle_owner';
    }

    const existing = await findActiveUserByPhone(normalizedPhone);
    if (existing) {
      res.status(409).json({
        error: 'An account with this mobile number already exists.',
      });
      return;
    }

    const now = new Date().toISOString();
    const user = {
      _id: new ObjectId(),
      email: `phone.${phoneDigits(normalizedPhone)}@openspace.local`,
      phone: normalizedPhone,
      displayName,
      role,
      authProvider: 'phone',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };
    await db.collection('users').insertOne(user);
    res.json(sessionPayload(user));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/google', async (req, res) => {
  try {
    const idToken = req.body.idToken;
    if (!idToken) {
      res.status(400).json({ error: 'Google sign-in token is required.' });
      return;
    }

    const expectedAudience =
      process.env.GOOGLE_WEB_CLIENT_ID ||
      process.env.GOOGLE_SERVER_CLIENT_ID ||
      '514956128372-a1aac5qlpe4s0i4ej0tqr6251m1uvb4k.apps.googleusercontent.com';

    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
    );
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || !payload.email || !payload.sub) {
      res.status(401).json({ error: 'Google sign-in could not be verified.' });
      return;
    }

    const audience = payload.aud;
    if (expectedAudience && audience && audience !== expectedAudience) {
      res.status(401).json({ error: 'Google token audience is invalid.' });
      return;
    }

    if (
      payload.email_verified !== 'true' &&
      payload.email_verified !== true
    ) {
      res.status(401).json({ error: 'Google email is not verified.' });
      return;
    }

    res.json({
      ok: true,
      email: payload.email,
      googleId: payload.sub,
      displayName: payload.name || String(payload.email).split('@')[0],
      emailVerified: true,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/notifications/ticket-assignment', async (req, res) => {
  try {
    const {
      phone,
      employeeName,
      ticketId,
      ownerName,
      ownerPhone,
      location,
      requestType,
    } = req.body;

    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      res.status(400).json({ error: 'Employee mobile number is required.' });
      return;
    }

    const message = [
      'Open Space Parking - New Ticket Assigned',
      `Hello ${employeeName || 'Employee'},`,
      `Ticket: ${ticketId || 'N/A'}`,
      `Type: ${formatRequestType(requestType)}`,
      `Owner: ${ownerName || 'Land Owner'} (${ownerPhone || 'N/A'})`,
      `Location: ${location || 'See employee portal'}`,
      'Please check your employee portal for full details.',
    ].join('\n');

    const result = await sendSms({ to: normalizedPhone, body: message });
    res.json({
      ok: true,
      phone: normalizedPhone,
      simulated: result.simulated === true,
      messageId: result.messageId || null,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function normalizePhoneNumber(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  if (String(phone || '').trim().startsWith('+')) {
    return `+${digits}`;
  }
  return `+${digits}`;
}

function formatRequestType(value) {
  if (!value) return 'Parking request';
  return String(value)
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

async function sendOtpSms({ to, body }) {
  console.log(`[OTP SMS dev mode] To: ${to}\n${body}`);
  return { simulated: true };
}

function isMsg91Configured() {
  const authKey = process.env.MSG91_AUTH_KEY || '';
  const sender = process.env.MSG91_SENDER_ID || '';
  const flowId = process.env.MSG91_FLOW_ID || '';
  const templateId = process.env.MSG91_TEMPLATE_ID || '';
  return authKey.trim().length > 0 && sender.trim().length > 0 && (flowId.trim().length > 0 || templateId.trim().length > 0);
}

async function sendSms({ to, body }) {
  const authKey = String(process.env.MSG91_AUTH_KEY || '').trim();
  const sender = String(process.env.MSG91_SENDER_ID || '').trim();
  const flowId = String(process.env.MSG91_FLOW_ID || '').trim();
  const templateId = String(process.env.MSG91_TEMPLATE_ID || '').trim();
  const route = String(process.env.MSG91_ROUTE || '4').trim();
  const otp = String(body).match(/\b(\d{4,8})\b/)?.[1] || '';
  const normalized = String(to || '').replace(/\D/g, '');

  if (!authKey || !sender || (!flowId && !templateId)) {
    throw new Error(
      'SMS is not configured. Set MSG91_AUTH_KEY, MSG91_SENDER_ID, and MSG91_FLOW_ID or MSG91_TEMPLATE_ID in backend/.env.',
    );
  }

  if (!normalized) {
    throw new Error('Recipient mobile number is invalid.');
  }

  if (flowId) {
    const flowResponse = await fetch('https://api.msg91.com/api/v5/flow/', {
      method: 'POST',
      headers: {
        authkey: authKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        flow_id: flowId,
        sender,
        route,
        recipients: [
          {
            mobiles: normalized,
            OTP: otp,
            MESSAGE: body,
          },
        ],
      }),
    });
    const payload = await flowResponse.json().catch(() => ({}));
    if (!flowResponse.ok) {
      throw new Error(payload.message || payload.type || 'MSG91 flow delivery failed.');
    }
    return {
      simulated: false,
      provider: 'msg91',
      messageId: payload.request_id || payload.message || null,
    };
  }

  const textResponse = await fetch('https://api.msg91.com/api/v2/sendsms', {
    method: 'POST',
    headers: {
      authkey: authKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender,
      route,
      country: '91',
      DLT_TE_ID: templateId,
      sms: [
        {
          message: body,
          to: [normalized],
        },
      ],
    }),
  });

  const payload = await textResponse.json().catch(() => ({}));
  if (!textResponse.ok) {
    throw new Error(payload.message || payload.type || 'MSG91 SMS delivery failed.');
  }

  return {
    simulated: false,
    provider: 'msg91',
    messageId: payload.request_id || payload.message || null,
  };
}

app.post('/api/uploads', upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded.' });
      return;
    }

    const host = req.get('host');
    const protocol = req.protocol;
    const url = `${protocol}://${host}/uploads/${req.file.filename}`;
    const extension = path.extname(req.file.originalname).slice(1).toLowerCase();

    res.json({
      url,
      publicId: req.file.filename,
      resourceType: 'raw',
      format: extension,
      fileName: req.file.originalname,
      bytes: req.file.size,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/uploads/:fileName', (req, res) => {
  try {
    const fileName = path.basename(req.params.fileName);
    const filePath = path.join(uploadDir, fileName);
    if (!fs.existsSync(filePath)) {
      res.status(404).json({ error: 'File not found.' });
      return;
    }
    fs.unlinkSync(filePath);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/find-one', async (req, res) => {
  try {
    const { collection, selector, includeDeleted = false } = req.body;
    const filter = parseSelector(selector);
    if (!includeDeleted) {
      filter.isDeleted = { $ne: true };
    }
    const doc = await db.collection(collection).findOne(filter);
    res.json({ document: doc ? serialize(doc) : null });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/find-many', async (req, res) => {
  try {
    const { collection, selector, includeDeleted = false } = req.body;
    const filter = parseSelector(selector);
    if (!includeDeleted) {
      filter.isDeleted = { $ne: true };
    }
    const docs = await db.collection(collection).find(filter).toArray();
    res.json({ documents: docs.map(serialize) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/find-paginated', async (req, res) => {
  try {
    const { collection, query = {} } = req.body;
    const filter = buildSearchFilter(query);
    const page = Number(query.page || 1);
    const pageSize = Number(query.pageSize || 20);
    const skip = (page - 1) * pageSize;
    const sortField = query.sortField || 'createdAt';
    const sortOrder = query.sortDescending === false ? 1 : -1;

    const col = db.collection(collection);
    const totalItems = await col.countDocuments(filter);
    const items = await col
      .find(filter)
      .sort({ [sortField]: sortOrder })
      .skip(skip)
      .limit(pageSize)
      .toArray();

    res.json({
      items: items.map(serialize),
      page,
      pageSize,
      totalItems,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/count', async (req, res) => {
  try {
    const { collection, selector, includeDeleted = false } = req.body;
    const filter = parseSelector(selector);
    if (!includeDeleted) {
      filter.isDeleted = { $ne: true };
    }
    const count = await db.collection(collection).countDocuments(filter);
    res.json({ count });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/insert-one', async (req, res) => {
  try {
    const { collection, document } = req.body;
    const doc = revive(document);
    if (!doc._id) {
      doc._id = new ObjectId();
    }
    const now = new Date().toISOString();
    doc.createdAt = doc.createdAt || now;
    doc.updatedAt = doc.updatedAt || now;
    if (doc.isDeleted == null) doc.isDeleted = false;

    await db.collection(collection).insertOne(doc);
    res.json({ document: serialize(doc), inserted: 1 });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/update-one', async (req, res) => {
  try {
    const { collection, selector, modifier } = req.body;
    const filter = parseSelector(selector);
    const update = revive(modifier?.map || modifier || {});

    const result = await db.collection(collection).updateOne(filter, update);
    res.json({
      matched: result.matchedCount,
      modified: result.modifiedCount,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/update-by-id', async (req, res) => {
  try {
    const { collection, id, updates = {} } = req.body;
    const filter = { _id: new ObjectId(id), isDeleted: { $ne: true } };
    const setDoc = { ...revive(updates), updatedAt: new Date().toISOString() };
    delete setDoc._id;
    delete setDoc.id;

    const result = await db
      .collection(collection)
      .updateOne(filter, { $set: setDoc });
    res.json({
      matched: result.matchedCount,
      modified: result.modifiedCount,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/soft-delete', async (req, res) => {
  try {
    const { collection, id } = req.body;
    const now = new Date().toISOString();
    const result = await db.collection(collection).updateOne(
      { _id: new ObjectId(id) },
      {
        $set: {
          isDeleted: true,
          deletedAt: now,
          updatedAt: now,
        },
      },
    );
    res.json({
      matched: result.matchedCount,
      modified: result.modifiedCount,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/restore', async (req, res) => {
  try {
    const { collection, id } = req.body;
    const now = new Date().toISOString();
    const result = await db.collection(collection).updateOne(
      { _id: new ObjectId(id) },
      {
        $set: { isDeleted: false, updatedAt: now },
        $unset: { deletedAt: '' },
      },
    );
    res.json({
      matched: result.matchedCount,
      modified: result.modifiedCount,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/hard-delete', async (req, res) => {
  try {
    const { collection, id } = req.body;
    const result = await db
      .collection(collection)
      .deleteOne({ _id: new ObjectId(id) });
    res.json({ removed: result.deletedCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/mongo/delete-one', async (req, res) => {
  try {
    const { collection, selector } = req.body;
    const filter = parseSelector(selector);
    const result = await db.collection(collection).deleteOne(filter);
    res.json({ removed: result.deletedCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';
const RAZORPAY_DEMO = !RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET;
const PLATFORM_COMMISSION_PERCENT = Number(
  process.env.PLATFORM_COMMISSION_PERCENT || 10,
);
const PLATFORM_ACCOUNT_NAME =
  process.env.PLATFORM_ACCOUNT_NAME || 'Media account (Open Space Parking)';
// Razorpay linked account ID that receives the 10% platform commission.
// Set this to your own acc_... ID for testing; replace with company account in production.
const RAZORPAY_COMPANY_ACCOUNT_ID =
  process.env.RAZORPAY_COMPANY_ACCOUNT_ID || '';

function amountToPaise(amount) {
  return Math.round(Number(amount) * 100);
}

function splitParkingPayment(amount) {
  const totalPaise = amountToPaise(amount);
  const commissionPaise = Math.round(
    (totalPaise * PLATFORM_COMMISSION_PERCENT) / 100,
  );
  const landOwnerPaise = totalPaise - commissionPaise;
  return {
    totalAmount: Number(amount),
    commissionPercent: PLATFORM_COMMISSION_PERCENT,
    platformAccountName: PLATFORM_ACCOUNT_NAME,
    platformAccountId: RAZORPAY_COMPANY_ACCOUNT_ID || null,
    platformCommission: commissionPaise / 100,
    landOwnerPayout: landOwnerPaise / 100,
    commissionPaise,
    landOwnerPaise,
  };
}

async function resolveLandOwnerPayout(booking) {
  let ownerId = booking.landOwnerId || null;
  if (!ownerId && booking.parkingListingId) {
    try {
      const listing = await db.collection('land_owner_requests').findOne({
        _id: new ObjectId(String(booking.parkingListingId)),
      });
      ownerId = listing?.ownerId || null;
    } catch (_) {
      ownerId = null;
    }
  }
  let payout = null;
  if (ownerId) {
    const profile = await db.collection('land_owner_profiles').findOne({
      ownerId: String(ownerId),
    });
    payout = profile?.payout || null;
  }
  return { ownerId, payout };
}

function razorpayAuthHeader() {
  return Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString(
    'base64',
  );
}

function verifyRazorpaySignature(orderId, paymentId, signature) {
  const secret = RAZORPAY_DEMO ? 'osp_demo_secret' : RAZORPAY_KEY_SECRET;
  const body = `${orderId}|${paymentId}`;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');
  return expected === signature;
}

async function markBookingPaid({
  bookingId,
  amount,
  razorpayOrderId,
  razorpayPaymentId,
  razorpaySignature,
  split,
}) {
  const now = new Date().toISOString();
  const paymentDoc = {
    bookingId,
    amount,
    method: 'Razorpay',
    status: 'paid',
    razorpayOrderId,
    razorpayPaymentId,
    razorpaySignature,
    split,
    createdAt: now,
  };
  const paymentResult = await db.collection('payments').insertOne(paymentDoc);
  await db.collection('bookings').updateOne(
    { _id: new ObjectId(bookingId) },
    {
      $set: {
        status: 'completed',
        paidAmount: amount,
        paymentId: razorpayPaymentId,
        paidAt: now,
        paymentMethod: 'Razorpay',
        split,
        updatedAt: now,
      },
    },
  );

  if (split?.landOwnerId) {
    await db.collection('notifications').insertOne({
      recipientId: split.landOwnerId,
      recipientType: 'land_owner',
      title: 'Parking payout',
      message:
        `₹${Number(split.landOwnerPayout || 0).toFixed(0)} credited toward your land-owner share ` +
        `(90%). Platform media account kept ₹${Number(split.platformCommission || 0).toFixed(0)}.`,
      isRead: false,
      createdAt: now,
    });
  }

  return paymentResult.insertedId;
}

app.post('/api/payments/razorpay/create-order', async (req, res) => {
  try {
    const { bookingId } = req.body || {};
    if (!bookingId) {
      return res.status(400).json({ error: 'bookingId is required' });
    }

    const booking = await db.collection('bookings').findOne({
      _id: new ObjectId(bookingId),
    });
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }
    if (booking.status !== 'active' || booking.amountDue == null || !booking.checkedOutAt) {
      return res.status(400).json({
        error: 'Booking is not ready for payment. Complete exit QR scan first.',
      });
    }

    const amount = Number(booking.amountDue);
    if (!Number.isFinite(amount) || amount < 1) {
      return res.status(400).json({
        error: 'No Razorpay charge for this session. Complete checkout in the app.',
      });
    }
    const splitAmounts = splitParkingPayment(amount);
    const { ownerId, payout } = await resolveLandOwnerPayout(booking);
    const linkedAccount = String(payout?.razorpayLinkedAccountId || '').trim();
    const canAutoTransfer = !RAZORPAY_DEMO && linkedAccount.startsWith('acc_');
    const split = {
      ...splitAmounts,
      landOwnerId: ownerId,
      landOwnerUpi: payout?.upiId || null,
      landOwnerAccountHolder: payout?.accountHolderName || null,
      razorpayLinkedAccountId: linkedAccount || null,
      settlementStatus: canAutoTransfer ? 'transfer_on_order' : 'pending_manual',
    };

    const amountPaise = splitAmounts.commissionPaise + splitAmounts.landOwnerPaise;
    const receipt = `osp_${booking.bookingRef || bookingId}`.slice(0, 40);

    let orderId;
    let keyId = RAZORPAY_KEY_ID;

    if (RAZORPAY_DEMO) {
      orderId = `order_demo_${Date.now()}`;
      keyId = 'rzp_test_demo';
    } else {
      const orderBody = {
        amount: amountPaise,
        currency: 'INR',
        receipt,
        notes: {
          bookingId,
          bookingRef: booking.bookingRef || '',
          platformCommission: String(split.platformCommission),
          landOwnerPayout: String(split.landOwnerPayout),
        },
      };
      const transfers = [];
      if (canAutoTransfer && split.landOwnerPaise >= 100) {
        transfers.push({
          account: linkedAccount,
          amount: split.landOwnerPaise,
          currency: 'INR',
          notes: { role: 'land_owner', bookingId },
        });
      }
      if (RAZORPAY_COMPANY_ACCOUNT_ID && split.commissionPaise >= 100) {
        transfers.push({
          account: RAZORPAY_COMPANY_ACCOUNT_ID,
          amount: split.commissionPaise,
          currency: 'INR',
          notes: { role: 'platform_commission', bookingId },
        });
      }
      if (transfers.length > 0) {
        orderBody.transfers = transfers;
      }
      const response = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${razorpayAuthHeader()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(orderBody),
      });
      const data = await response.json();
      if (!response.ok) {
        return res.status(502).json({
          error: data.error?.description || 'Could not create Razorpay order',
        });
      }
      orderId = data.id;
    }

    await db.collection('bookings').updateOne(
      { _id: new ObjectId(bookingId) },
      {
        $set: {
          razorpayOrderId: orderId,
          split,
          updatedAt: new Date().toISOString(),
        },
      },
    );

    res.json({
      keyId,
      orderId,
      amount,
      amountPaise,
      currency: 'INR',
      bookingId,
      bookingRef: booking.bookingRef,
      demo: RAZORPAY_DEMO,
      split,
      checkoutUrl:
        `/payments/razorpay/checkout?bookingId=${encodeURIComponent(bookingId)}&orderId=${encodeURIComponent(orderId)}`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/payments/razorpay/checkout', async (req, res) => {
  try {
    const bookingId = String(req.query.bookingId || '');
    const orderId = String(req.query.orderId || '');
    if (!bookingId || !orderId) {
      return res.status(400).send('Missing bookingId or orderId');
    }

    const booking = await db.collection('bookings').findOne({
      _id: new ObjectId(bookingId),
    });
    if (!booking) return res.status(404).send('Booking not found');

    const amount = Number(booking.amountDue || 0);
    const amountPaise = amountToPaise(amount);
    const keyId = RAZORPAY_DEMO ? 'rzp_test_demo' : RAZORPAY_KEY_ID;
    const demo = RAZORPAY_DEMO;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Razorpay Checkout</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 420px; margin: 40px auto; padding: 16px; }
    .amount { font-size: 2rem; font-weight: 700; }
    button { width: 100%; padding: 14px; margin-top: 16px; border: 0; border-radius: 10px; background: #0b72e7; color: #fff; font-size: 1rem; cursor: pointer; }
    .muted { color: #666; margin-top: 8px; }
  </style>
  ${demo ? '' : '<script src="https://checkout.razorpay.com/v1/checkout.js"></script>'}
</head>
<body>
  <h2>Pay parking fee</h2>
  <div class="amount">₹${amount.toFixed(0)}</div>
  <div class="muted">${booking.parkingName || 'Parking'} • Slot ${booking.assignedSlot || '-'}</div>
  <div class="muted">Session ${booking.sessionId || booking.bookingRef || bookingId}</div>
  <div class="muted">${Number(booking.actualDurationHours || 0).toFixed(2)} hrs</div>
  <div class="muted">10% media account · 90% land owner</div>
  <button id="payBtn">${demo ? 'Pay with Razorpay (Demo)' : 'Pay with Razorpay'}</button>
  <p id="status" class="muted"></p>
  <script>
    const bookingId = ${JSON.stringify(bookingId)};
    const orderId = ${JSON.stringify(orderId)};
    const amountPaise = ${amountPaise};
    const keyId = ${JSON.stringify(keyId)};
    const demo = ${demo ? 'true' : 'false'};
    const statusEl = document.getElementById('status');

    async function verifyPayment(payload) {
      statusEl.textContent = 'Confirming payment...';
      const res = await fetch('/api/payments/razorpay/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Verification failed');
      statusEl.textContent = 'Payment successful. You can return to the app.';
      document.getElementById('payBtn').disabled = true;
      document.getElementById('payBtn').textContent = 'Paid';
    }

    document.getElementById('payBtn').onclick = async function () {
      try {
        if (demo) {
          const paymentId = 'pay_demo_' + Date.now();
          const body = orderId + '|' + paymentId;
          const enc = new TextEncoder().encode('osp_demo_secret');
          const key = await crypto.subtle.importKey('raw', enc, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
          const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
          const signature = Array.from(new Uint8Array(sigBuf)).map(b => b.toString(16).padStart(2, '0')).join('');
          await verifyPayment({
            bookingId,
            razorpay_order_id: orderId,
            razorpay_payment_id: paymentId,
            razorpay_signature: signature,
          });
          return;
        }

        const options = {
          key: keyId,
          amount: amountPaise,
          currency: 'INR',
          name: 'Open Space Parking',
          description: 'Parking fee',
          order_id: orderId,
          handler: async function (response) {
            try {
              await verifyPayment({
                bookingId,
                razorpay_order_id: response.razorpay_order_id,
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_signature: response.razorpay_signature,
              });
            } catch (e) {
              statusEl.textContent = e.message || 'Payment verification failed';
            }
          },
        };
        const rzp = new Razorpay(options);
        rzp.open();
      } catch (e) {
        statusEl.textContent = e.message || 'Payment failed';
      }
    };
  </script>
</body>
</html>`);
  } catch (error) {
    res.status(500).send(error.message);
  }
});

app.post('/api/payments/razorpay/verify', async (req, res) => {
  try {
    const {
      bookingId,
      razorpay_order_id: orderId,
      razorpay_payment_id: paymentId,
      razorpay_signature: signature,
    } = req.body || {};

    if (!bookingId || !orderId || !paymentId || !signature) {
      return res.status(400).json({ error: 'Missing payment verification fields' });
    }

    if (!verifyRazorpaySignature(orderId, paymentId, signature)) {
      return res.status(400).json({ error: 'Invalid Razorpay signature' });
    }

    const booking = await db.collection('bookings').findOne({
      _id: new ObjectId(bookingId),
    });
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }
    if (booking.status === 'completed' && booking.paidAt) {
      return res.json({ ok: true, alreadyPaid: true });
    }
    if (booking.status !== 'active' || booking.amountDue == null) {
      return res.status(400).json({ error: 'Booking is not payable' });
    }

    const split =
      booking.split ||
      (await (async () => {
        const amounts = splitParkingPayment(Number(booking.amountDue));
        const { ownerId, payout } = await resolveLandOwnerPayout(booking);
        return {
          ...amounts,
          landOwnerId: ownerId,
          landOwnerUpi: payout?.upiId || null,
          settlementStatus: 'pending_manual',
        };
      })());

    await markBookingPaid({
      bookingId,
      amount: Number(booking.amountDue),
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
      split,
    });

    res.json({ ok: true, bookingId, paymentId });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

async function start() {
  if (DATABASE_URL) {
    db = await createPgDb(DATABASE_URL);
    console.log('Database: Supabase PostgreSQL');
  } else {
    client = new MongoClient(MONGO_URI);
    await client.connect();
    db = client.db();
    await ensureIndexes(db);
    console.log('Database: MongoDB');
  }
  await seedDefaultAdmin(db);
  await seedDefaultSecurity(db);
  await seedDemoParkingIfEmpty(db);
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Open Space Parking API listening on http://0.0.0.0:${PORT}`);
    console.log(`Phone/emulator: use http://<this-pc-lan-ip>:${PORT}`);
  });
}

start().catch((error) => {
  console.error('Failed to start API server:', error);
  process.exit(1);
});
