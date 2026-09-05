/**
 * Admin operations analytics: occupancy (check-ins + peak) and payments.
 * Day boundaries use Asia/Kolkata (IST).
 */

const { ObjectId } = require('mongodb');

const IST_OFFSET = '+05:30';

function parseDayKey(value) {
  const raw = String(value || '').trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  return raw;
}

function istDayStart(dayKey) {
  return new Date(`${dayKey}T00:00:00${IST_OFFSET}`);
}

function istDayEndExclusive(dayKey) {
  const start = istDayStart(dayKey);
  return new Date(start.getTime() + 24 * 60 * 60 * 1000);
}

function toIstDayKey(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  // Shift into IST wall-clock then read UTC Y-M-D of that shifted instant.
  const shifted = new Date(date.getTime() + 5.5 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

function eachDayKey(fromKey, toKey) {
  const keys = [];
  let cursor = istDayStart(fromKey);
  const end = istDayStart(toKey);
  while (cursor <= end) {
    keys.push(toIstDayKey(cursor));
    cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
  }
  return keys;
}

function resolveDateRange(query = {}) {
  const today = toIstDayKey(new Date());
  let toKey = parseDayKey(query.to) || today;
  let fromKey = parseDayKey(query.from);
  if (!fromKey) {
    const toStart = istDayStart(toKey);
    fromKey = toIstDayKey(new Date(toStart.getTime() - 6 * 24 * 60 * 60 * 1000));
  }
  if (fromKey > toKey) {
    const tmp = fromKey;
    fromKey = toKey;
    toKey = tmp;
  }
  // Allow any start/end the admin picks (no artificial window shrink).
  return { from: fromKey, to: toKey, days: eachDayKey(fromKey, toKey) };
}

function listingIdOf(doc) {
  return String(doc?.parkingListingId || '').trim();
}

function listingLabel(doc) {
  const name = String(doc?.parkingName || '').trim();
  if (name) return name;
  const addr = String(
    doc?.parkingAddress ||
      doc?.landDetails?.landAddress ||
      doc?.landDetails?.address ||
      '',
  ).trim();
  if (addr) return addr;
  const ticket = String(doc?.ticketId || '').trim();
  if (ticket) return ticket;
  return listingIdOf(doc) || 'Unknown place';
}

/**
 * Peak concurrent cars on one calendar day for a set of sessions.
 * Session: { checkedInAt, checkedOutAt? }
 */
function peakOccupancyForDay(sessions, dayKey, now = new Date()) {
  const dayStart = istDayStart(dayKey);
  const dayEnd = istDayEndExclusive(dayKey);
  const events = [];

  for (const session of sessions) {
    const cin = new Date(session.checkedInAt);
    if (Number.isNaN(cin.getTime())) continue;
    let cout = session.checkedOutAt ? new Date(session.checkedOutAt) : now;
    if (Number.isNaN(cout.getTime())) cout = now;
    if (cout <= dayStart || cin >= dayEnd) continue;

    const start = cin < dayStart ? dayStart : cin;
    const end = cout > dayEnd ? dayEnd : cout;
    if (end <= start) continue;

    events.push({ t: start.getTime(), d: 1 });
    events.push({ t: end.getTime(), d: -1 });
  }

  events.sort((a, b) => {
    if (a.t !== b.t) return a.t - b.t;
    // Process departures before arrivals at the same timestamp.
    return a.d - b.d;
  });

  let current = 0;
  let peak = 0;
  for (const event of events) {
    current += event.d;
    if (current > peak) peak = current;
  }
  return peak;
}

function countCheckInsForDay(sessions, dayKey) {
  let count = 0;
  for (const session of sessions) {
    const key = toIstDayKey(session.checkedInAt);
    if (key === dayKey) count += 1;
  }
  return count;
}

function buildDailyOccupancy(sessions, dayKeys, now = new Date()) {
  return dayKeys.map((day) => ({
    day,
    checkIns: countCheckInsForDay(sessions, day),
    peakOccupancy: peakOccupancyForDay(sessions, day, now),
  }));
}

function docIdString(doc) {
  if (!doc) return '';
  if (doc.$oid) return String(doc.$oid);
  if (typeof doc.toHexString === 'function') return doc.toHexString();
  return String(doc);
}

async function loadPlaces(db) {
  const [listingDocs, bookingDocs] = await Promise.all([
    db
      .collection('land_owner_requests')
      .find({
        isDeleted: { $ne: true },
        documentsVerified: true,
        status: { $in: ['approved', 'completed'] },
      })
      .toArray(),
    db
      .collection('bookings')
      .find({ parkingListingId: { $exists: true, $ne: '' } })
      .toArray(),
  ]);

  const bookingPlaces = [];
  const seenListing = new Set();
  for (const doc of bookingDocs) {
    const id = String(doc.parkingListingId || '').trim();
    if (!id || seenListing.has(id)) continue;
    seenListing.add(id);
    bookingPlaces.push({
      _id: id,
      parkingName: doc.parkingName,
      parkingAddress: doc.parkingAddress,
      ticketId: doc.ticketId,
    });
  }

  const byId = new Map();

  for (const doc of listingDocs) {
    const id = docIdString(doc._id);
    if (!id) continue;
    byId.set(id, {
      id,
      name: listingLabel(doc),
      ticketId: doc.ticketId || null,
      capacity:
        Number(doc.parkingPreferences?.numberOfCars ?? doc.capacity ?? 0) ||
        null,
    });
  }

  for (const row of bookingPlaces) {
    const id = String(row._id || '').trim();
    if (!id) continue;
    if (byId.has(id)) {
      const existing = byId.get(id);
      if (!existing.name || existing.name === 'Unknown place') {
        existing.name = listingLabel(row);
      }
      continue;
    }
    byId.set(id, {
      id,
      name: listingLabel(row),
      ticketId: row.ticketId || null,
      capacity: null,
    });
  }

  return Array.from(byId.values()).sort((a, b) =>
    a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }),
  );
}

async function loadCheckedInBookings(db, { from, to, listingId }) {
  const rangeStart = istDayStart(from);
  const rangeEnd = istDayEndExclusive(to);
  const filter = {
    checkedInAt: { $exists: true, $ne: null, $lt: rangeEnd.toISOString() },
    $or: [
      { checkedOutAt: { $exists: false } },
      { checkedOutAt: null },
      { checkedOutAt: { $gte: rangeStart.toISOString() } },
    ],
  };
  if (listingId) {
    filter.parkingListingId = String(listingId);
  }

  const docs = await db.collection('bookings').find(filter).toArray();

  // Also include check-ins that started in range even if filtered oddly by checkout.
  const checkInOnly = await db
    .collection('bookings')
    .find({
      ...(listingId ? { parkingListingId: String(listingId) } : {}),
      checkedInAt: {
        $gte: rangeStart.toISOString(),
        $lt: rangeEnd.toISOString(),
      },
    })
    .toArray();

  const byId = new Map();
  for (const doc of [...docs, ...checkInOnly]) {
    const id = docIdString(doc._id);
    if (id) byId.set(id, doc);
  }
  return Array.from(byId.values());
}

async function buildOccupancyReport(db, query = {}) {
  const { from, to, days } = resolveDateRange(query);
  const listingId = String(query.listingId || query.placeId || '').trim();
  const sessions = await loadCheckedInBookings(db, {
    from,
    to,
    listingId: listingId || null,
  });
  const now = new Date();
  const daily = buildDailyOccupancy(sessions, days, now);

  return {
    from,
    to,
    listingId: listingId || null,
    totals: {
      checkIns: daily.reduce((sum, d) => sum + d.checkIns, 0),
      peakOccupancy: daily.reduce((max, d) => Math.max(max, d.peakOccupancy), 0),
    },
    daily,
  };
}

function isPaidBooking(doc) {
  if (doc.paidAt) return true;
  if (String(doc.status || '') === 'completed' && Number(doc.paidAmount) > 0) {
    return true;
  }
  return false;
}

function isUnpaidDue(doc) {
  if (isPaidBooking(doc)) return false;
  const due = Number(doc.amountDue ?? doc.totalPrice ?? 0);
  if (!(due > 0)) return false;
  // Billed after checkout, or explicitly awaiting payment.
  if (doc.checkedOutAt) return true;
  if (String(doc.status || '') === 'active' && due > 0) return true;
  return false;
}

async function buildPaymentsReport(db, query = {}) {
  const { from, to } = resolveDateRange(query);
  const listingId = String(query.listingId || query.placeId || '').trim();
  const rangeStart = istDayStart(from);
  const rangeEnd = istDayEndExclusive(to);

  const unpaidPaidAt = {
    $or: [{ paidAt: null }, { paidAt: { $exists: false } }, { paidAt: '' }],
  };
  const bookingFilter = {
    ...(listingId ? { parkingListingId: String(listingId) } : {}),
    $or: [
      {
        paidAt: {
          $gte: rangeStart.toISOString(),
          $lt: rangeEnd.toISOString(),
        },
      },
      {
        checkedOutAt: {
          $gte: rangeStart.toISOString(),
          $lt: rangeEnd.toISOString(),
        },
        ...unpaidPaidAt,
      },
      {
        amountDue: { $gt: 0 },
        checkedOutAt: { $exists: true, $ne: null },
        ...unpaidPaidAt,
      },
    ],
  };

  const bookings = await db
    .collection('bookings')
    .find(bookingFilter)
    .sort({ updatedAt: -1 })
    .limit(500)
    .toArray();

  const payments = await db
    .collection('payments')
    .find({
      createdAt: {
        $gte: rangeStart.toISOString(),
        $lt: rangeEnd.toISOString(),
      },
      status: { $in: ['paid', 'captured', 'authorized'] },
    })
    .sort({ createdAt: -1 })
    .limit(500)
    .toArray();

  const bookingById = new Map();
  for (const b of bookings) {
    bookingById.set(docIdString(b._id), b);
  }

  // Attach booking place info onto payments when needed.
  const paymentBookingIds = payments
    .map((p) => String(p.bookingId || '').trim())
    .filter(Boolean);
  const missingIds = paymentBookingIds.filter((id) => !bookingById.has(id));
  if (missingIds.length) {
    const objectIds = [];
    const oidFilters = [];
    for (const id of missingIds) {
      try {
        objectIds.push(new ObjectId(id));
        oidFilters.push({ $oid: id });
      } catch (_) {
        /* ignore */
      }
    }
    if (objectIds.length) {
      const extra = await db
        .collection('bookings')
        .find({
          $or: [
            { _id: { $in: objectIds } },
            { _id: { $in: oidFilters } },
            { _id: { $in: missingIds } },
          ],
        })
        .toArray();
      for (const b of extra) bookingById.set(docIdString(b._id), b);
    }
  }

  const paidItems = [];
  const seenPaymentKeys = new Set();

  for (const payment of payments) {
    const booking = bookingById.get(String(payment.bookingId || ''));
    if (listingId) {
      const place = String(booking?.parkingListingId || '').trim();
      if (place !== listingId) continue;
    }
    const amount = Number(payment.amount ?? booking?.paidAmount ?? 0);
    const split = payment.split || booking?.split || null;
    const key = String(payment.razorpayPaymentId || payment._id || '');
    if (key) seenPaymentKeys.add(key);
    paidItems.push({
      id: docIdString(payment._id) || key,
      kind: 'paid',
      bookingId: String(payment.bookingId || ''),
      bookingRef: booking?.bookingRef || null,
      parkingListingId: booking?.parkingListingId || null,
      parkingName: booking ? listingLabel(booking) : null,
      vehicleNumber: booking?.vehicleNumber || null,
      amount,
      platformCommission: Number(split?.platformCommission ?? 0),
      landOwnerPayout: Number(split?.landOwnerPayout ?? 0),
      razorpayPaymentId: payment.razorpayPaymentId || null,
      method: payment.method || 'Razorpay',
      at: payment.createdAt || booking?.paidAt || null,
    });
  }

  // Paid bookings without a payments row (legacy / edge).
  for (const booking of bookings) {
    if (!isPaidBooking(booking)) continue;
    if (listingId && listingIdOf(booking) !== listingId) continue;
    const paidAt = booking.paidAt;
    if (!paidAt) continue;
    const day = toIstDayKey(paidAt);
    if (!day || day < from || day > to) continue;
    const payKey = String(booking.paymentId || '');
    if (payKey && seenPaymentKeys.has(payKey)) continue;
    const amount = Number(booking.paidAmount ?? booking.amountDue ?? 0);
    const split = booking.split || null;
    paidItems.push({
      id: `booking-paid-${docIdString(booking._id)}`,
      kind: 'paid',
      bookingId: docIdString(booking._id),
      bookingRef: booking.bookingRef || null,
      parkingListingId: booking.parkingListingId || null,
      parkingName: listingLabel(booking),
      vehicleNumber: booking.vehicleNumber || null,
      amount,
      platformCommission: Number(split?.platformCommission ?? 0),
      landOwnerPayout: Number(split?.landOwnerPayout ?? 0),
      razorpayPaymentId: booking.paymentId || null,
      method: booking.paymentMethod || 'Razorpay',
      at: paidAt,
    });
  }

  const unpaidItems = [];
  for (const booking of bookings) {
    if (!isUnpaidDue(booking)) continue;
    if (listingId && listingIdOf(booking) !== listingId) continue;
    const amount = Number(booking.amountDue ?? booking.totalPrice ?? 0);
    unpaidItems.push({
      id: `booking-due-${docIdString(booking._id)}`,
      kind: 'unpaid',
      bookingId: docIdString(booking._id),
      bookingRef: booking.bookingRef || null,
      parkingListingId: booking.parkingListingId || null,
      parkingName: listingLabel(booking),
      vehicleNumber: booking.vehicleNumber || null,
      amount,
      platformCommission: 0,
      landOwnerPayout: 0,
      razorpayPaymentId: null,
      method: null,
      at: booking.checkedOutAt || booking.updatedAt || null,
    });
  }

  paidItems.sort((a, b) => String(b.at || '').localeCompare(String(a.at || '')));
  unpaidItems.sort((a, b) => String(b.at || '').localeCompare(String(a.at || '')));

  const paidTotal = paidItems.reduce((s, i) => s + Number(i.amount || 0), 0);
  const unpaidTotal = unpaidItems.reduce((s, i) => s + Number(i.amount || 0), 0);
  const platformTotal = paidItems.reduce(
    (s, i) => s + Number(i.platformCommission || 0),
    0,
  );
  const landOwnerTotal = paidItems.reduce(
    (s, i) => s + Number(i.landOwnerPayout || 0),
    0,
  );

  return {
    from,
    to,
    listingId: listingId || null,
    totals: {
      paidCount: paidItems.length,
      unpaidCount: unpaidItems.length,
      paidAmount: Math.round(paidTotal * 100) / 100,
      unpaidAmount: Math.round(unpaidTotal * 100) / 100,
      platformCommission: Math.round(platformTotal * 100) / 100,
      landOwnerPayout: Math.round(landOwnerTotal * 100) / 100,
    },
    paid: paidItems.slice(0, 100),
    unpaid: unpaidItems.slice(0, 100),
  };
}

async function buildOperationsAnalytics(db, query = {}) {
  const places = await loadPlaces(db);
  const [occupancy, payments] = await Promise.all([
    buildOccupancyReport(db, query),
    buildPaymentsReport(db, query),
  ]);
  return { places, occupancy, payments };
}

module.exports = {
  IST_OFFSET,
  parseDayKey,
  toIstDayKey,
  resolveDateRange,
  peakOccupancyForDay,
  countCheckInsForDay,
  buildDailyOccupancy,
  loadPlaces,
  buildOccupancyReport,
  buildPaymentsReport,
  buildOperationsAnalytics,
};
