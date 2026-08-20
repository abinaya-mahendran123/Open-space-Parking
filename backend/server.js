const cors = require('cors');
const crypto = require('crypto');
const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { MongoClient, ObjectId } = require('mongodb');
const { createPgDb } = require('./pg_store');
const {
  attachSessionToken,
  requireAuth,
  requireRole,
  parseCorsOrigins,
} = require('./auth_jwt');
const {
  startParkingSession,
  scanParkingQr,
  findBookingByQr,
} = require('./booking_service');
const {
  nearbyVerifiedListings,
  verifiedListingById,
  isEmployeeVerifiedListing,
  isPublicParkingListing,
} = require('./parking_listings');
const { recommendNearbyParking } = require('./parking_recommendations');
const { extractGovernmentIdDetails } = require('./government_id_ocr');
const { handleAuthUrl, handleExchange, handleFetchDocument } = require('./digilocker');
const { handleSendOtp, handleVerifyOtp, verifyOtpToken } = require('./otp_service');

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
const corsOrigins = parseCorsOrigins();
app.use(
  cors(
    corsOrigins
      ? {
          origin(origin, callback) {
            if (!origin || corsOrigins.includes(origin)) {
              callback(null, true);
              return;
            }
            callback(new Error('Not allowed by CORS'));
          },
          credentials: true,
        }
      : { origin: true },
  ),
);
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

function phoneLastFour(phone) {
  const digits = phoneDigits(phone);
  if (digits.length < 4) return '';
  return digits.slice(-4);
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

async function findEmployeeByPhone(phone) {
  const lastTen = phoneKey(phone);
  if (!lastTen) return null;
  const employees = await db.collection('employees').find({}).toArray();
  return employees.find((employee) => phoneKey(employee.phone) === lastTen) || null;
}

function employeeSessionPayload(employee) {
  return attachSessionToken({
    userId: asHexId(employee._id),
    email: employee.email || '',
    displayName: employee.fullName || employee.displayName || '',
    role: 'employee',
  });
}

function sessionPayload(user) {
  const role = String(user.role || '');
  const normalized =
    role === 'vehicleOwner' ? 'vehicle_owner' :
    role === 'landOwner' ? 'land_owner' :
    role;
  return attachSessionToken({
    userId: asHexId(user._id),
    email: user.email,
    displayName: user.displayName || '',
    role: normalized,
  });
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
  const name = process.env.DEFAULT_SECURITY_NAME || 'Gate Security';
  const phone = normalizePhoneNumber(
    process.env.DEFAULT_SECURITY_PHONE || '9999999999',
  );
  // Password rule: last 4 digits of the security phone number.
  const password = phoneLastFour(phone);
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
  console.log(`Default security ready: ${email} / phone ${phone}`);
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
    {
      collection: 'bookings',
      indexes: [
        { keys: { parkingListingId: 1 }, name: 'idx_bookings_listing' },
        { keys: { qrPayload: 1 }, name: 'idx_bookings_qr' },
        { keys: { bookingRef: 1 }, name: 'idx_bookings_ref' },
        { keys: { vehicleOwnerId: 1 }, name: 'idx_bookings_owner' },
      ],
    },
    {
      collection: 'notifications',
      indexes: [
        { keys: { recipientId: 1 }, name: 'idx_notifications_recipient' },
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
    const phone = normalizePhoneNumber(req.body?.phone || req.body?.email);
    const password = String(req.body?.password || '');
    if (!phone || !password) {
      res.status(400).json({ error: 'Enter mobile number and password.' });
      return;
    }

    const expectedPassword = phoneLastFour(phone);
    if (!expectedPassword || password !== expectedPassword) {
      res.status(401).json({ error: 'Invalid credentials.' });
      return;
    }

    const defaultPhone = normalizePhoneNumber(
      process.env.DEFAULT_SECURITY_PHONE || '9999999999',
    );
    if (phoneKey(phone) === phoneKey(defaultPhone)) {
      await seedDefaultSecurity(db);
    }

    const user = await findActiveUserByPhone(phone);
    if (!user || user.role !== 'security') {
      res.status(403).json({
        error: 'Only registered security staff can open the gate scanner.',
      });
      return;
    }

    // Keep stored hash in sync with the last-4 rule.
    const salt = user.passwordSalt || generateSalt();
    const hash = hashPassword(expectedPassword, salt);
    if (
      !user.passwordSalt ||
      !user.passwordHash ||
      user.passwordHash !== hash
    ) {
      await db.collection('users').updateOne(
        { _id: user._id },
        {
          $set: {
            passwordHash: hash,
            passwordSalt: salt,
            phone,
            updatedAt: new Date().toISOString(),
          },
        },
      );
      user.passwordHash = hash;
      user.passwordSalt = salt;
      user.phone = phone;
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

app.post('/api/auth/register', async (req, res) => {
  try {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const displayName = String(req.body?.displayName || '').trim();
    let role = String(req.body?.role || 'vehicle_owner').trim();
    if (role === 'vehicleOwner') role = 'vehicle_owner';
    if (role === 'landOwner') role = 'land_owner';

    if (!email || !password || !displayName) {
      res.status(400).json({ error: 'Email, password, and display name are required.' });
      return;
    }
    if (role === 'admin' || role === 'employee' || role === 'security') {
      res.status(403).json({ error: 'This role cannot be self-registered.' });
      return;
    }
    if (role !== 'vehicle_owner' && role !== 'land_owner') {
      role = 'vehicle_owner';
    }

    const existing = await findActiveUserByEmail(email);
    if (existing) {
      res.status(409).json({ error: 'An account with this email already exists.' });
      return;
    }

    const salt = generateSalt();
    const hash = hashPassword(password, salt);
    const now = new Date().toISOString();
    const user = {
      _id: new ObjectId(),
      email,
      displayName,
      role,
      passwordHash: hash,
      passwordSalt: salt,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };
    await db.collection('users').insertOne(user);

    if (role === 'land_owner') {
      await db.collection('land_owner_profiles').insertOne({
        _id: new ObjectId(),
        ownerId: asHexId(user._id),
        ownerDetails: {
          fullName: displayName,
          phone: '',
          email,
          address: '',
        },
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      });
    } else {
      await db.collection('vehicle_owner_profiles').insertOne({
        _id: new ObjectId(),
        vehicleOwnerId: asHexId(user._id),
        fullName: displayName,
        email,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      });
    }

    res.json(sessionPayload(user));
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

// ── Backend OTP (no Firebase billing required) ─────────────────────────────
app.post('/api/auth/otp/send', handleSendOtp);
app.post('/api/auth/otp/verify', handleVerifyOtp);

// ── DigiLocker property document verification ──────────────────────────────
app.get('/api/digilocker/auth-url', handleAuthUrl);
app.post('/api/digilocker/exchange', handleExchange);
app.post('/api/digilocker/fetch-document', handleFetchDocument);

app.post('/api/ocr/government-id', async (req, res) => {
  try {
    const { frontUrl, backUrl, idType } = req.body || {};
    const extracted = await extractGovernmentIdDetails({
      frontUrl,
      backUrl,
      idType,
    });
    res.json(extracted);
  } catch (error) {
    const message = error?.message || 'Could not extract details from ID images.';
    const status = message.includes('required') || message.includes('Unsupported') ? 400 : 500;
    res.status(status).json({ error: message });
  }
});

async function handleParkingNearby(req, res) {
  try {
    const query = { ...(req.query || {}), ...(req.body || {}) };
    const latitude = Number(query.latitude);
    const longitude = Number(query.longitude);
    const radiusKm = Number(query.radius ?? query.radiusKm ?? 25);
    const vehicleOwnerId = String(
      query.vehicleOwnerId || query.vehicle_id || '',
    ).trim();

    const hasRecommendationParams =
      Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      !(latitude === 0 && longitude === 0);

    if (hasRecommendationParams || vehicleOwnerId) {
      const result = await recommendNearbyParking(db, {
        latitude,
        longitude,
        radiusKm,
        vehicleOwnerId: vehicleOwnerId || null,
      });
      res.json({
        recommendations: result.recommendations,
        vehicle: result.vehicle,
        meta: result.meta,
      });
      return;
    }

    if (!DATABASE_URL) {
      const docs = await db
        .collection('land_owner_requests')
        .find({ isDeleted: { $ne: true } })
        .toArray();
      res.json({
        documents: docs.filter(isPublicParkingListing).map(serialize),
      });
      return;
    }
    const documents = await nearbyVerifiedListings(db.pool);
    res.json({ documents: documents.map(serialize) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

app.get('/api/parking/nearby', handleParkingNearby);
app.post('/api/parking/nearby', handleParkingNearby);

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
        document: doc && isPublicParkingListing(doc) ? serialize(doc) : null,
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

app.post('/api/auth/check-account', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body?.phone);
    if (!normalizedPhone) {
      res.status(400).json({ error: 'Please enter a valid mobile number.' });
      return;
    }

    const employee = await findEmployeeByPhone(normalizedPhone);
    if (employee) {
      if (employee.isActive !== true) {
        res.status(403).json({
          error:
            'This employee account is currently inactive. Please contact the administrator.',
        });
        return;
      }
      res.json({ accountType: 'employee' });
      return;
    }

    const defaultSecurityPhone = normalizePhoneNumber(
      process.env.DEFAULT_SECURITY_PHONE || '9999999999',
    );
    if (phoneKey(normalizedPhone) === phoneKey(defaultSecurityPhone)) {
      await seedDefaultSecurity(db);
      res.json({ accountType: 'security' });
      return;
    }

    const user = await findActiveUserByPhone(normalizedPhone);
    if (user?.role === 'security') {
      res.json({ accountType: 'security' });
      return;
    }

    res.json({ accountType: 'user' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/auth/employee-phone-login', async (req, res) => {
  try {
    const normalizedPhone = normalizePhoneNumber(req.body?.phone);
    const password = String(req.body?.password || '');

    if (!normalizedPhone) {
      res.status(400).json({ error: 'Please enter a valid mobile number.' });
      return;
    }
    if (!password) {
      res.status(400).json({ error: 'Password is required.' });
      return;
    }

    const employee = await findEmployeeByPhone(normalizedPhone);
    if (!employee) {
      res.status(401).json({ error: 'Incorrect password. Please try again.' });
      return;
    }
    if (employee.isActive !== true) {
      res.status(403).json({
        error:
          'This employee account is currently inactive. Please contact the administrator.',
      });
      return;
    }
    if (!employee.passwordSalt || !employee.passwordHash) {
      res.status(401).json({
        error: 'Employee login is not configured. Contact your administrator.',
      });
      return;
    }

    const computed = hashPassword(password, employee.passwordSalt);
    if (computed !== employee.passwordHash) {
      res.status(401).json({ error: 'Incorrect password. Please try again.' });
      return;
    }

    res.json(employeeSessionPayload(employee));
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

    const employee = await findEmployeeByPhone(normalizedPhone);
    if (employee) {
      res.status(403).json({
        error: 'This mobile number is registered as an employee. Sign in with your employee password.',
      });
      return;
    }

    const verifiedPhone = await verifyPhoneToken(req.body?.idToken, req.body?.otpToken);
    if (!verifiedPhone || phoneKey(verifiedPhone) !== phoneKey(normalizedPhone)) {
      res.status(401).json({ error: 'Phone verification failed. Please try again.' });
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
    res.status(error.statusCode || 500).json({ error: error.message });
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

    const employee = await findEmployeeByPhone(normalizedPhone);
    if (employee) {
      res.status(403).json({
        error: 'This mobile number belongs to an employee account and cannot be self-registered.',
      });
      return;
    }

    const verifiedPhone = await verifyPhoneToken(req.body?.idToken, req.body?.otpToken);
    if (!verifiedPhone || phoneKey(verifiedPhone) !== phoneKey(normalizedPhone)) {
      res.status(401).json({ error: 'Phone verification failed. Please try again.' });
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
    res.status(error.statusCode || 500).json({ error: error.message });
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
      '794049298844-v8f8okbjfb4memdcjugcpqfd58tk71j0.apps.googleusercontent.com';

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

/**
 * Accepts either:
 *  - otpToken: our custom HMAC token from /api/auth/otp/verify (no billing needed)
 *  - idToken: Firebase phone auth token (requires Blaze plan)
 * Returns the verified phone number or null.
 */
async function verifyPhoneToken(idToken, otpToken) {
  // Prefer our custom token — no Firebase billing required
  if (otpToken) {
    const phone = verifyOtpToken(String(otpToken).trim());
    if (phone) return normalizePhoneNumber(phone);
  }
  // Fall back to Firebase token if provided
  if (idToken) {
    try {
      return await verifyFirebasePhoneToken(idToken);
    } catch {
      return null;
    }
  }
  return null;
}

async function verifyFirebasePhoneToken(idToken) {
  const token = String(idToken || '').trim();
  if (!token) {
    const error = new Error('Firebase ID token is required.');
    error.statusCode = 401;
    throw error;
  }

  const apiKey = String(
    process.env.FIREBASE_WEB_API_KEY || process.env.FIREBASE_API_KEY || '',
  ).trim();
  if (!apiKey) {
    const error = new Error(
      'FIREBASE_WEB_API_KEY is not set. Phone login requires Firebase.',
    );
    error.statusCode = 500;
    throw error;
  }

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: token }),
    },
  );
  const payload = await response.json().catch(() => ({}));
  const phone = payload.users?.[0]?.phoneNumber;
  if (!response.ok || !phone) {
    const error = new Error(
      payload.error?.message || 'Firebase phone verification failed.',
    );
    error.statusCode = 401;
    throw error;
  }
  return normalizePhoneNumber(phone);
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

const { sendPushNotification, isConfigured: isFcmConfigured } = require('./fcm_push');

app.post('/api/notifications/push', requireAuth, async (req, res) => {
  try {
    const {
      recipientId,
      recipientType,
      title,
      body,
      route,
      referenceId,
    } = req.body || {};

    if (!recipientId || !recipientType) {
      res.status(400).json({ error: 'recipientId and recipientType are required.' });
      return;
    }
    if (!title || !body) {
      res.status(400).json({ error: 'title and body are required.' });
      return;
    }

    const result = await sendPushNotification({
      db,
      recipientId: String(recipientId),
      recipientType: String(recipientType),
      title: String(title),
      body: String(body),
      route: route ? String(route) : undefined,
      referenceId: referenceId ? String(referenceId) : undefined,
    });

    res.json({ ok: true, ...result, configured: isFcmConfigured() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post(
  '/api/bookings/start-session',
  requireAuth,
  requireRole('vehicle_owner'),
  async (req, res) => {
    try {
      const parkingListingId = String(req.body?.parkingListingId || '').trim();
      const vehicleNumber = String(req.body?.vehicleNumber || '');
      const vehicleModel = req.body?.vehicleModel;

      if (!parkingListingId || !vehicleNumber.trim()) {
        res.status(400).json({ error: 'parkingListingId and vehicleNumber are required.' });
        return;
      }

      const document = await startParkingSession(db, {
        vehicleOwnerId: req.auth.userId,
        parkingListingId,
        vehicleNumber,
        vehicleModel,
      });
      res.json({ document: serialize(document) });
    } catch (error) {
      res.status(error.statusCode || 500).json({ error: error.message });
    }
  },
);

app.get(
  '/api/security/booking-by-qr',
  requireAuth,
  requireRole('security'),
  async (req, res) => {
    try {
      const qr = String(req.query?.qr || req.query?.code || '').trim();
      if (!qr) {
        res.status(400).json({ error: 'qr is required.' });
        return;
      }
      const doc = await findBookingByQr(db, qr);
      res.json({ document: doc ? serialize(doc) : null });
    } catch (error) {
      res.status(error.statusCode || 500).json({ error: error.message });
    }
  },
);

app.post(
  '/api/security/scan-qr',
  requireAuth,
  requireRole('security'),
  async (req, res) => {
    try {
      const qrPayload = String(req.body?.qrPayload || req.body?.qr || '').trim();
      if (!qrPayload) {
        res.status(400).json({ error: 'qrPayload is required.' });
        return;
      }
      const document = await scanParkingQr(db, qrPayload);
      res.json({ document: serialize(document) });
    } catch (error) {
      res.status(error.statusCode || 500).json({ error: error.message });
    }
  },
);

const mongoRouter = express.Router();
mongoRouter.use(requireAuth);

mongoRouter.post('/find-one', async (req, res) => {
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

mongoRouter.post('/find-many', async (req, res) => {
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

mongoRouter.post('/find-paginated', async (req, res) => {
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

mongoRouter.post('/count', async (req, res) => {
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

mongoRouter.post('/insert-one', async (req, res) => {
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

mongoRouter.post('/update-one', async (req, res) => {
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

mongoRouter.post('/update-by-id', async (req, res) => {
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

mongoRouter.post('/soft-delete', async (req, res) => {
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

mongoRouter.post('/restore', async (req, res) => {
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

mongoRouter.post('/hard-delete', async (req, res) => {
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

mongoRouter.post('/delete-one', async (req, res) => {
  try {
    const { collection, selector } = req.body;
    const filter = parseSelector(selector);
    const result = await db.collection(collection).deleteOne(filter);
    res.json({ removed: result.deletedCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.use('/api/mongo', mongoRouter);

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
    client = new MongoClient(MONGO_URI, {
      maxPoolSize: 20,
      serverSelectionTimeoutMS: 5000,
    });
    await client.connect();
    db = client.db();
    db.pool = null;
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
