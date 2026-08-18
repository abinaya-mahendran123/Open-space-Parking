const cors = require('cors');
const crypto = require('crypto');
const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { MongoClient, ObjectId } = require('mongodb');

const PORT = Number(process.env.PORT || 3000);
const MONGO_URI =
  process.env.MONGO_CONNECTION_STRING ||
  'mongodb://localhost:27017/open_space_parking';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '10mb' }));

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
  if (selectorMap.$query) {
    const query = selectorMap.$query;
    if (query.$and) return { $and: revive(query.$and) };
    return revive(query);
  }
  return revive(selectorMap);
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
  (process.env.DEFAULT_ADMIN_EMAIL || 'harisiv09@gmail.com').trim().toLowerCase();
const DEFAULT_ADMIN_PASSWORD = process.env.DEFAULT_ADMIN_PASSWORD || 'Hari@2006';
const DEFAULT_ADMIN_NAME = process.env.DEFAULT_ADMIN_NAME || 'Admin';

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${password}::${salt}`).digest('hex');
}

function generateSalt() {
  return crypto.randomBytes(16).toString('base64url');
}

async function seedDefaultAdmin(database) {
  const users = database.collection('users');
  const existing = await users.findOne({ email: DEFAULT_ADMIN_EMAIL });

  if (existing) {
    if (existing.role === 'admin') return;
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

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    mongoConnected: Boolean(db),
  });
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
    otpCodes.set(normalizedPhone, {
      hash: hashOtp(otp),
      expiresAt: Date.now() + 5 * 60 * 1000,
    });

    const message = `Your Open Space Parking verification code is ${otp}. Valid for 5 minutes.`;
    const result = await sendOtpSms({ to: normalizedPhone, body: message });

    res.json({
      ok: true,
      phone: normalizedPhone,
      devMode: result.simulated === true,
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

    const entry = otpCodes.get(normalizedPhone);
    if (!entry) {
      res.status(400).json({ error: 'OTP expired or not requested. Send a new code.' });
      return;
    }
    if (Date.now() > entry.expiresAt) {
      otpCodes.delete(normalizedPhone);
      res.status(400).json({ error: 'OTP expired. Request a new code.' });
      return;
    }
    if (hashOtp(otp) !== entry.hash) {
      res.status(400).json({ error: 'Invalid OTP. Please try again.' });
      return;
    }

    otpCodes.delete(normalizedPhone);
    res.json({ ok: true, phone: normalizedPhone, verified: true });
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
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_SMS_FROM;

  if (!sid || !token || !from) {
    console.log(`[OTP SMS dev mode] To: ${to}\n${body}`);
    return { simulated: true };
  }

  return sendSms({ to, body });
}

async function sendSms({ to, body }) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_SMS_FROM;

    if (!sid || !token || !from) {
      res.status(503).json({
        error:
          'SMS is not configured. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_SMS_FROM in the backend environment.',
        simulated: true,
      });
      return;
    }

  const auth = Buffer.from(`${sid}:${token}`).toString('base64');
  const params = new URLSearchParams({ To: to, From: from, Body: body });
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params,
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.message || 'SMS delivery failed.');
  }

  return { simulated: false, messageId: payload.sid };
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

async function start() {
  client = new MongoClient(MONGO_URI);
  await client.connect();
  db = client.db();
  await ensureIndexes(db);
  await seedDefaultAdmin(db);
  app.listen(PORT, () => {
    console.log(`Open Space Parking API listening on http://localhost:${PORT}`);
    console.log(`MongoDB: ${MONGO_URI}`);
  });
}

start().catch((error) => {
  console.error('Failed to start API server:', error);
  process.exit(1);
});
