const crypto = require('crypto');
const { ObjectId } = require('mongodb');
const { sendPushNotification } = require('./fcm_push');
const {
  verifiedListingById,
  isPublicParkingListing,
} = require('./parking_listings');
const {
  slotsFromLandArea,
  resolveCapacity: resolveParkingCapacity,
} = require('./parking_slots');

const ACTIVE_SLOT_STATUSES = ['confirmed', 'active'];
/** Entry QR must be scanned within this window or the booking is cancelled. */
const QR_ENTRY_VALIDITY_MS = Number(
  process.env.QR_ENTRY_VALIDITY_MS || 2 * 60 * 60 * 1000,
);
const listingLocks = new Map();

function qrExpiresAtFrom(createdAt) {
  const startMs = new Date(createdAt || Date.now()).getTime();
  return new Date(startMs + QR_ENTRY_VALIDITY_MS).toISOString();
}

function isEntryQrExpired(booking, now = new Date()) {
  if (!booking) return false;
  if (booking.checkedInAt) return false;
  const status = String(booking.status || '');
  if (status !== 'confirmed') return false;
  const expires =
    booking.qrExpiresAt ||
    qrExpiresAtFrom(booking.createdAt || booking.startDateTime);
  return now.getTime() > new Date(expires).getTime();
}

function generateBookingRef() {
  const now = new Date();
  const datePart = [
    now.getUTCFullYear(),
    String(now.getUTCMonth() + 1).padStart(2, '0'),
    String(now.getUTCDate()).padStart(2, '0'),
  ].join('');
  const random = Math.floor(Math.random() * 9000) + 1000;
  return `BK-${datePart}-${random}`;
}

function generateSessionId() {
  const now = new Date();
  const datePart = [
    now.getUTCFullYear(),
    String(now.getUTCMonth() + 1).padStart(2, '0'),
    String(now.getUTCDate()).padStart(2, '0'),
  ].join('');
  const random = Math.floor(Math.random() * 9000) + 1000;
  return `PS-${datePart}-${random}`;
}

function normalizePlate(plate) {
  return String(plate || '').trim().toUpperCase();
}

function isValidPlate(plate) {
  if (!plate) return false;
  return /^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{1,3}\s?\d{1,4}$/.test(plate);
}

async function withListingLock(db, parkingListingId, fn) {
  const pool = db.pool;
  if (pool) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [
        parkingListingId,
      ]);
      const result = await fn();
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  const previous = listingLocks.get(parkingListingId) || Promise.resolve();
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const chain = previous.then(() => gate);
  listingLocks.set(parkingListingId, chain);
  try {
    return await fn();
  } finally {
    release();
    if (listingLocks.get(parkingListingId) === chain) {
      listingLocks.delete(parkingListingId);
    }
  }
}

async function getListing(db, listingId) {
  const id = String(listingId || '').trim();
  if (!id) return null;

  if (db.pool) {
    const doc = await verifiedListingById(db.pool, id);
    return doc && isPublicParkingListing(doc) ? doc : null;
  }

  const doc = await db.collection('land_owner_requests').findOne({
    _id: new ObjectId(id),
    isDeleted: { $ne: true },
  });
  return doc && isPublicParkingListing(doc) ? doc : null;
}

function listingCapacity(listing) {
  const prefs = listing?.parkingPreferences || {};
  const land = listing?.landDetails || {};
  const requestType = String(listing?.requestType || '').toLowerCase();
  if (requestType === 'build_parking') {
    return resolveParkingCapacity({
      requestType: 'build_parking',
      storedNumberOfCars:
        Number(prefs.numberOfCars) ||
        Number(prefs.numberOfSlots) ||
        Number(listing?.capacity) ||
        Number(listing?.numberOfCars) ||
        0,
    });
  }

  const stored =
    Number(prefs.numberOfCars) ||
    Number(prefs.numberOfSlots) ||
    Number(listing?.capacity) ||
    Number(listing?.numberOfCars) ||
    0;
  if (Number.isFinite(stored) && stored > 0) return Math.floor(stored);

  const areaSqFt = Number(land.areaSqFt) || 0;
  if (areaSqFt > 0) {
    return slotsFromLandArea(areaSqFt);
  }
  return 10;
}

function listingHourlyRate(listing) {
  if (!listing) return 0;
  const prefs = listing.parkingPreferences || {};
  const candidates = [
    listing.hourlyRate,
    listing.verifiedHourlyRate,
    listing.amountPerHour,
    listing.parkingFee,
    prefs.hourlyRate,
    prefs.amountPerHour,
    prefs.parkingFee,
  ];
  for (const value of candidates) {
    const rate = Number(value);
    if (Number.isFinite(rate) && rate > 0) return rate;
  }
  return 0;
}

/**
 * Trusted hourly rate for billing — listing (land owner) only.
 * Never trust booking.hourlyRate (clients can write Mongo fields).
 */
function resolveHourlyRate(_booking, listing) {
  const fromListing = listingHourlyRate(listing);
  if (fromListing > 0) return fromListing;
  // Last resort so sessions are never billed ₹0 when rate was never saved.
  const fallback = Number(process.env.DEFAULT_PARKING_HOURLY_RATE || 60);
  return Number.isFinite(fallback) && fallback > 0 ? fallback : 60;
}

function computeBill(checkedInAt, checkedOutAt, hourlyRate) {
  const start = new Date(checkedInAt);
  const end = new Date(checkedOutAt);
  let minutes = Math.floor((end.getTime() - start.getTime()) / 60000);
  if (!Number.isFinite(minutes) || minutes < 1) minutes = 1;
  let billedHours = Math.ceil((minutes / 60) * 100) / 100;
  if (billedHours < 0.25) billedHours = 0.25;
  const rate = Number(hourlyRate) > 0 ? Number(hourlyRate) : 0;
  const amountDue = Math.ceil(billedHours * rate * 100) / 100;
  return { minutes, billedHours, amountDue, hourlyRate: rate };
}

/**
 * Always recompute fee from listing rate × check-in/out.
 * Ignores any client-tampered booking.amountDue / booking.hourlyRate.
 * Skips paid/completed bookings.
 */
async function ensureBillForCheckout(db, booking) {
  if (!booking?.checkedInAt || !booking?.checkedOutAt) return booking;
  if (booking.paidAt || String(booking.status || '') === 'completed') {
    return booking;
  }

  const listing = await getListing(db, booking.parkingListingId);
  const hourlyRate = resolveHourlyRate(null, listing);
  const { billedHours, amountDue } = computeBill(
    booking.checkedInAt,
    booking.checkedOutAt,
    hourlyRate,
  );
  if (!(amountDue > 0)) {
    const error = new Error(
      'Could not calculate parking fee. Set an hourly rate for this parking space.',
    );
    error.statusCode = 400;
    throw error;
  }

  const setDoc = {
    hourlyRate,
    amountDue,
    totalPrice: amountDue,
    actualDurationHours: billedHours,
    durationHours: billedHours,
    updatedAt: new Date().toISOString(),
  };

  // Skip write if already correct (avoids noisy updates).
  const sameRate = Number(booking.hourlyRate) === hourlyRate;
  const sameDue = Number(booking.amountDue) === amountDue;
  const sameHours = Number(booking.actualDurationHours) === billedHours;
  if (sameRate && sameDue && sameHours) {
    return { ...booking, ...setDoc };
  }

  await updateBookingDoc(
    db,
    booking,
    booking.qrPayload || booking.bookingRef,
    setDoc,
  );
  return { ...booking, ...setDoc };
}

function listingDisplayName(listing) {
  return (
    listing.parkingName ||
    listing.landDetails?.landAddress ||
    listing.landAddress ||
    'Parking'
  );
}

async function countActiveBookings(db, parkingListingId) {
  const bookings = await db
    .collection('bookings')
    .find({
      parkingListingId: String(parkingListingId),
      isDeleted: { $ne: true },
    })
    .toArray();

  return bookings.filter((doc) =>
    ACTIVE_SLOT_STATUSES.includes(String(doc.status || '')),
  ).length;
}

async function allocateNextSlot(db, parkingListingId, capacity) {
  const safeCapacity = Math.max(1, Number(capacity) || 10);
  const bookings = await db
    .collection('bookings')
    .find({
      parkingListingId: String(parkingListingId),
      isDeleted: { $ne: true },
    })
    .toArray();

  const used = new Set();
  for (const doc of bookings) {
    const status = String(doc.status || '');
    if (!ACTIVE_SLOT_STATUSES.includes(status)) continue;
    const slot = Number(doc.assignedSlot);
    if (Number.isFinite(slot) && slot > 0) used.add(slot);
  }

  for (let slot = 1; slot <= safeCapacity; slot += 1) {
    if (!used.has(slot)) return slot;
  }
  const error = new Error('No parking slots available right now.');
  error.statusCode = 409;
  throw error;
}

/** Assign an FCFS slot when an older booking was saved without one. */
async function ensureAssignedSlot(db, booking) {
  if (!booking) return booking;
  const existing = Number(booking.assignedSlot);
  if (Number.isFinite(existing) && existing > 0) return booking;

  const status = String(booking.status || '');
  if (!ACTIVE_SLOT_STATUSES.includes(status) && status !== 'awaiting_payment') {
    return booking;
  }

  const listing = await getListing(db, booking.parkingListingId);
  const capacity = listing ? listingCapacity(listing) : 10;
  const slot = await allocateNextSlot(db, booking.parkingListingId, capacity);
  const now = new Date().toISOString();
  await db.collection('bookings').updateOne(
    { _id: booking._id },
    {
      $set: {
        assignedSlot: slot,
        updatedAt: now,
      },
    },
  );
  booking.assignedSlot = slot;
  booking.updatedAt = now;
  return booking;
}

async function insertNotification(db, { recipientId, recipientType, title, message }) {
  const now = new Date().toISOString();
  await db.collection('notifications').insertOne({
    _id: new ObjectId(),
    recipientId: String(recipientId),
    recipientType,
    title,
    message,
    isRead: false,
    createdAt: now,
    updatedAt: now,
  });

  await sendPushNotification({
    db,
    recipientId: String(recipientId),
    recipientType,
    title,
    body: message,
  }).catch(() => {});
}

async function findBookingByQr(db, qrPayload) {
  const code = String(qrPayload || '').trim();
  if (!code) return null;

  let doc = await db.collection('bookings').findOne({
    qrPayload: code,
    isDeleted: { $ne: true },
  });
  if (!doc) {
    doc = await db.collection('bookings').findOne({
      bookingRef: code,
      isDeleted: { $ne: true },
    });
  }
  if (!doc) return null;
  return ensureAssignedSlot(db, doc);
}

async function startParkingSession(db, { vehicleOwnerId, parkingListingId, vehicleNumber, vehicleModel }) {
  const plate = normalizePlate(vehicleNumber);
  if (!isValidPlate(plate)) {
    const error = new Error('Enter a valid vehicle number (e.g. TN 09 AB 1234).');
    error.statusCode = 400;
    throw error;
  }

  // Cancel any entry QRs that already timed out before assigning a new slot.
  await expireUnscannedEntryQrBookings(db);

  const existingLive = await findLiveEntryQrBooking(db, vehicleOwnerId);
  if (existingLive) {
    const error = new Error(
      'You already have an active parking QR. Show it at the gate or wait until it expires (2 hours).',
    );
    error.statusCode = 409;
    error.existingBookingId = String(existingLive._id?.$oid || existingLive._id || '');
    throw error;
  }

  const listing = await getListing(db, parkingListingId);
  if (!listing) {
    const error = new Error('Parking space is no longer available.');
    error.statusCode = 404;
    throw error;
  }

  const capacity = listingCapacity(listing);

  return withListingLock(db, String(parkingListingId), async () => {
    const activeCount = await countActiveBookings(db, parkingListingId);
    if (activeCount >= capacity) {
      const error = new Error('No slots available at this parking.');
      error.statusCode = 409;
      throw error;
    }

    const slot = await allocateNextSlot(db, parkingListingId, capacity);
    const bookingRef = generateBookingRef();
    const now = new Date().toISOString();
    const qrExpiresAt = qrExpiresAtFrom(now);
    const placeholderEnd = qrExpiresAt;
    const hourlyRate = resolveHourlyRate(null, listing);
    const parkingName = listingDisplayName(listing);

    const document = {
      _id: new ObjectId(),
      bookingRef,
      vehicleOwnerId: String(vehicleOwnerId),
      parkingListingId: String(parkingListingId),
      ticketId: String(listing.ticketId || listing._id?.$oid || listing._id || ''),
      parkingType: String(listing.parkingPreferences?.parkingType || listing.parkingType || ''),
      vehicleNumber: plate,
      vehicleModel: vehicleModel ? String(vehicleModel).trim() : null,
      startDateTime: now,
      endDateTime: placeholderEnd,
      durationHours: QR_ENTRY_VALIDITY_MS / (60 * 60 * 1000),
      hourlyRate,
      totalPrice: 0,
      status: 'confirmed',
      parkingAddress: listing.landDetails?.landAddress || listing.landAddress || null,
      parkingName,
      assignedSlot: slot,
      qrPayload: bookingRef,
      qrExpiresAt,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    };

    await db.collection('bookings').insertOne(document);

    await insertNotification(db, {
      recipientId: vehicleOwnerId,
      recipientType: 'vehicle_owner',
      title: 'Slot Assigned',
      message: `Slot ${slot} assigned (FCFS). Show QR (${bookingRef}) to security within 2 hours to start parking.`,
    });

    return ensureAssignedSlot(db, document);
  });
}

async function findLiveEntryQrBooking(db, vehicleOwnerId) {
  const ownerId = String(vehicleOwnerId || '').trim();
  if (!ownerId) return null;
  const bookings = await db
    .collection('bookings')
    .find({
      vehicleOwnerId: ownerId,
      status: 'confirmed',
      isDeleted: { $ne: true },
    })
    .toArray();

  const now = new Date();
  for (const doc of bookings) {
    if (doc.checkedInAt) continue;
    if (isEntryQrExpired(doc, now)) continue;
    return doc;
  }
  return null;
}

/**
 * Cancel confirmed bookings whose entry QR was never scanned within 2 hours.
 * Releases the slot for others.
 */
async function expireUnscannedEntryQrBookings(db) {
  const bookings = await db
    .collection('bookings')
    .find({
      status: 'confirmed',
      isDeleted: { $ne: true },
    })
    .toArray();

  const now = new Date();
  const nowIso = now.toISOString();
  let expired = 0;

  for (const booking of bookings) {
    if (booking.checkedInAt) continue;
    if (!isEntryQrExpired(booking, now)) continue;

    const expires =
      booking.qrExpiresAt ||
      qrExpiresAtFrom(booking.createdAt || booking.startDateTime);

    await updateBookingDoc(db, booking, booking.qrPayload || booking.bookingRef, {
      status: 'cancelled',
      cancelledAt: nowIso,
      cancelReason: 'entry_qr_expired',
      qrExpiredAt: expires,
      updatedAt: nowIso,
    });

    await insertNotification(db, {
      recipientId: booking.vehicleOwnerId,
      recipientType: 'vehicle_owner',
      title: 'Booking Cancelled',
      message: `QR for ${booking.bookingRef} expired after 2 hours without gate scan. Slot ${booking.assignedSlot ?? '-'} was released.`,
    });

    expired += 1;
  }

  return { expired };
}

async function scanParkingQr(db, qrPayload) {
  await expireUnscannedEntryQrBookings(db);

  const booking = await findBookingByQr(db, qrPayload);
  if (!booking) {
    const error = new Error('QR / booking not found.');
    error.statusCode = 404;
    throw error;
  }

  const status = String(booking.status || '');
  if (status === 'completed') {
    const error = new Error('This parking session is already completed.');
    error.statusCode = 400;
    throw error;
  }
  if (status === 'cancelled') {
    const reason = String(booking.cancelReason || '');
    const error = new Error(
      reason === 'entry_qr_expired'
        ? 'This QR expired (valid 2 hours). Book a new slot.'
        : 'This booking was cancelled.',
    );
    error.statusCode = 400;
    throw error;
  }

  // Already billed — return as-is. Repair ₹0 bills from missing hourly rate.
  if (booking.checkedOutAt) {
    const billed = await ensureBillForCheckout(db, booking);
    return ensureAssignedSlot(db, billed);
  }

  const listing = await getListing(db, booking.parkingListingId);
  const parkingName =
    String(booking.parkingName || '').trim() ||
    (listing ? listingDisplayName(listing) : 'Parking');
  // Always stamp listing rate at check-in / exit — never reuse a client-written rate.
  const hourlyRate = resolveHourlyRate(null, listing);
  const now = new Date();
  const nowIso = now.toISOString();

  if (!booking.checkedInAt) {
    if (isEntryQrExpired(booking, now)) {
      await expireUnscannedEntryQrBookings(db);
      const error = new Error(
        'This QR expired (valid 2 hours from booking). Ask the driver to book again.',
      );
      error.statusCode = 400;
      throw error;
    }

    if (!ACTIVE_SLOT_STATUSES.includes(status) && status !== 'confirmed') {
      const error = new Error(`Booking is ${status} and cannot start.`);
      error.statusCode = 400;
      throw error;
    }

    const sessionId =
      String(booking.sessionId || '').trim() || generateSessionId();
    const started = {
      status: 'active',
      checkedInAt: nowIso,
      startDateTime: nowIso,
      sessionId,
      parkingName,
      hourlyRate,
      updatedAt: nowIso,
    };

    await updateBookingDoc(db, booking, qrPayload, started);

    await insertNotification(db, {
      recipientId: booking.vehicleOwnerId,
      recipientType: 'vehicle_owner',
      title: 'Parking Started',
      message: `Session ${sessionId} started at ${parkingName}, slot ${booking.assignedSlot ?? '-'}.`,
    });

    return (await reloadBooking(db, booking, qrPayload)) || { ...booking, ...started };
  }

  if (status !== 'active') {
    const error = new Error(`Booking is ${status}, not an active park session.`);
    error.statusCode = 400;
    throw error;
  }

  const { billedHours, amountDue } = computeBill(
    booking.checkedInAt,
    nowIso,
    hourlyRate,
  );

  const stopped = {
    checkedOutAt: nowIso,
    endDateTime: nowIso,
    actualDurationHours: billedHours,
    durationHours: billedHours,
    hourlyRate,
    parkingName,
    amountDue,
    totalPrice: amountDue,
    updatedAt: nowIso,
  };

  await updateBookingDoc(db, booking, qrPayload, stopped);

  await insertNotification(db, {
    recipientId: booking.vehicleOwnerId,
    recipientType: 'vehicle_owner',
    title: 'Ready to Pay',
    message: `Session stopped after ${billedHours.toFixed(2)} hrs at ${parkingName}. Pay ₹${amountDue.toFixed(0)} via Razorpay.`,
  });

  return (await reloadBooking(db, booking, qrPayload)) || { ...booking, ...stopped };
}

async function updateBookingDoc(db, booking, qrPayload, setDoc) {
  let result = await db.collection('bookings').updateOne(
    { _id: booking._id },
    { $set: setDoc },
  );
  if (result.matchedCount) return;

  const code = String(qrPayload || booking.qrPayload || booking.bookingRef || '').trim();
  if (code) {
    result = await db.collection('bookings').updateOne(
      { qrPayload: code },
      { $set: setDoc },
    );
    if (result.matchedCount) return;
    await db.collection('bookings').updateOne(
      { bookingRef: code },
      { $set: setDoc },
    );
  }
}

async function reloadBooking(db, booking, qrPayload) {
  const byId = booking?._id
    ? await db.collection('bookings').findOne({ _id: booking._id })
    : null;
  if (byId) return byId;
  return findBookingByQr(db, qrPayload);
}

module.exports = {
  startParkingSession,
  scanParkingQr,
  findBookingByQr,
  findLiveEntryQrBooking,
  expireUnscannedEntryQrBookings,
  ensureAssignedSlot,
  ensureBillForCheckout,
  allocateNextSlot,
  listingCapacity,
  listingHourlyRate,
  resolveHourlyRate,
  computeBill,
  QR_ENTRY_VALIDITY_MS,
};
