const NAMED_TABLES = [
  'users',
  'employees',
  'vehicle_owner_profiles',
  'land_owner_profiles',
  'land_owner_requests',
  'bookings',
  'payments',
  'parking_reviews',
  'vehicle_owner_favorites',
  'vehicle_owner_notifications',
  'land_owner_notifications',
  'employee_notifications',
  'notifications',
  'quotations',
  'construction_progress',
  'documents',
  'parking_spaces',
];

function oidHex(value) {
  if (value == null) return '';
  if (typeof value === 'string') {
    const match = value.match(/[a-fA-F0-9]{24}/);
    return match ? match[0] : value;
  }
  if (typeof value === 'object') {
    if (typeof value.toHexString === 'function') return value.toHexString();
    if (typeof value.oid === 'string') return value.oid;
    if (typeof value.$oid === 'string') return value.$oid;
  }
  return String(value);
}

function asText(value, fallback = '') {
  if (value == null) return fallback;
  if (typeof value === 'object') {
    if (value.$oid || value.oid) return oidHex(value);
    return fallback;
  }
  return String(value);
}

function asNullableText(value) {
  const text = asText(value, '').trim();
  return text ? text : null;
}

function asBool(value, fallback = false) {
  if (value === true || value === 1 || value === 'true' || value === '1') return true;
  if (value === false || value === 0 || value === 'false' || value === '0') return false;
  return fallback;
}

function asNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function asNullableNumber(value) {
  if (value == null || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function asInt(value, fallback = 0) {
  const n = asNullableNumber(value);
  return n == null ? fallback : Math.round(n);
}

function asNullableInt(value) {
  const n = asNullableNumber(value);
  return n == null ? null : Math.round(n);
}

function asTime(value) {
  if (value == null || value === '') return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function canonicalRole(role) {
  const value = asText(role);
  if (value === 'vehicleOwner' || value === 'vehicle_owner') return 'vehicle_owner';
  if (value === 'landOwner' || value === 'land_owner') return 'land_owner';
  return value || 'vehicle_owner';
}

function asJson(value, fallback = {}) {
  if (value == null) return fallback;
  if (typeof value === 'object') return value;
  return fallback;
}

function rowId(doc) {
  return oidHex(doc && doc._id);
}

const UNIQUE_FALLBACKS = {
  users: ['email', 'phone'],
  vehicle_owner_profiles: ['vehicle_owner_id'],
  land_owner_profiles: ['owner_id'],
  land_owner_requests: ['ticket_id'],
  bookings: ['booking_ref'],
  employees: ['email', 'phone'],
};

async function upsertByColumn(pool, table, row, keys, altColumn) {
  // Match on secondary unique fields without rewriting the primary key.
  // Duplicate mongo docs can share an email/phone with different ids.
  const setKeys = keys.filter((key) => key !== altColumn && key !== 'id');
  if (!setKeys.length) return;
  const setSql = setKeys.map((key, i) => `"${key}" = $${i + 1}`).join(', ');
  const setValues = setKeys.map((key) => row[key]);
  const whereIndex = setValues.length + 1;
  const whereSql =
    altColumn === 'email'
      ? `lower("${altColumn}") = lower($${whereIndex})`
      : `"${altColumn}" = $${whereIndex}`;
  await pool.query(
    `update public.${table} set ${setSql} where ${whereSql}`,
    [...setValues, row[altColumn]],
  );
}

async function upsert(pool, table, row) {
  const keys = Object.keys(row).filter((key) => row[key] !== undefined);
  if (!keys.includes('id') || !row.id) return;
  const cols = keys.map((key) => `"${key}"`).join(', ');
  const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
  const updates = keys
    .filter((key) => key !== 'id')
    .map((key) => `"${key}" = excluded."${key}"`)
    .join(', ');
  const values = keys.map((key) => row[key]);
  try {
    await pool.query(
      `insert into public.${table} (${cols}) values (${placeholders})
       on conflict (id) do update set ${updates}`,
      values,
    );
  } catch (error) {
    if (error.code !== '23505') throw error;
    const fallbacks = UNIQUE_FALLBACKS[table] || [];
    for (const alt of fallbacks) {
      if (row[alt] == null || String(row[alt]).trim() === '') continue;
      try {
        await upsertByColumn(pool, table, row, keys, alt);
        return;
      } catch (fallbackError) {
        if (fallbackError.code !== '23505') throw fallbackError;
      }
    }
    // Last resort: drop conflicting secondary unique fields and update by id only.
    try {
      const relaxed = { ...row };
      for (const alt of fallbacks) {
        if (alt === 'email' && relaxed.email) {
          relaxed.email = `${relaxed.id}@dup.placeholder.local`;
        }
        if (alt === 'phone') {
          relaxed.phone = null;
        }
      }
      const relaxedKeys = Object.keys(relaxed).filter(
        (key) => relaxed[key] !== undefined,
      );
      const relaxedCols = relaxedKeys.map((key) => `"${key}"`).join(', ');
      const relaxedPlaceholders = relaxedKeys
        .map((_, i) => `$${i + 1}`)
        .join(', ');
      const relaxedUpdates = relaxedKeys
        .filter((key) => key !== 'id')
        .map((key) => `"${key}" = excluded."${key}"`)
        .join(', ');
      await pool.query(
        `insert into public.${table} (${relaxedCols}) values (${relaxedPlaceholders})
         on conflict (id) do update set ${relaxedUpdates}`,
        relaxedKeys.map((key) => relaxed[key]),
      );
      return;
    } catch (_) {
      throw error;
    }
  }
}

function uniqueEmail(doc) {
  const email = asText(doc.email).trim().toLowerCase();
  if (email) return email;
  const id = rowId(doc) || 'unknown';
  return `user-${id}@placeholder.local`;
}

function usersRow(doc) {
  return {
    id: rowId(doc),
    email: uniqueEmail(doc),
    phone: asNullableText(doc.phone),
    display_name: asText(doc.displayName || doc.fullName),
    role: canonicalRole(doc.role),
    auth_provider: asNullableText(doc.authProvider),
    google_id: asNullableText(doc.googleId),
    password_hash: asNullableText(doc.passwordHash),
    password_salt: asNullableText(doc.passwordSalt),
    is_deleted: asBool(doc.isDeleted, false),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
    deleted_at: asTime(doc.deletedAt),
  };
}

function employeesRow(doc) {
  const id = rowId(doc);
  const emailRaw = asText(doc.email).trim().toLowerCase();
  return {
    id,
    full_name: asText(doc.fullName || doc.displayName, 'Employee'),
    email: emailRaw || `employee-${id}@placeholder.local`,
    phone: asText(doc.phone),
    role_title: asText(doc.roleTitle || doc.role, 'Field Employee'),
    is_active: asBool(doc.isActive, true),
    assigned_ticket_count: asInt(doc.assignedTicketCount, 0),
    password_hash: asNullableText(doc.passwordHash),
    password_salt: asNullableText(doc.passwordSalt),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
  };
}

function vehicleOwnerProfilesRow(doc) {
  return {
    id: rowId(doc),
    vehicle_owner_id: asText(doc.vehicleOwnerId || doc.ownerId),
    profile: asJson(doc.profile, doc),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
  };
}

function landOwnerProfilesRow(doc) {
  return {
    id: rowId(doc),
    owner_id: asText(doc.ownerId),
    owner_details: asJson(doc.ownerDetails),
    payout: doc.payout == null ? null : asJson(doc.payout),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
  };
}

function landOwnerRequestsRow(doc) {
  return {
    id: rowId(doc),
    ticket_id: asText(doc.ticketId, rowId(doc)),
    owner_id: asText(doc.ownerId),
    request_type: asText(doc.requestType, 'build_parking'),
    status: asText(doc.status, 'submitted'),
    owner_details: asJson(doc.ownerDetails),
    documents: asJson(doc.documents),
    land_details: asJson(doc.landDetails),
    parking_preferences: doc.parkingPreferences == null ? null : asJson(doc.parkingPreferences),
    assigned_employee_id: asNullableText(doc.assignedEmployeeId),
    assigned_employee_name: asNullableText(doc.assignedEmployeeName),
    documents_verified: asBool(doc.documentsVerified, false),
    admin_notes: asNullableText(doc.adminNotes),
    reviewed_at: asTime(doc.reviewedAt),
    reviewed_by: asNullableText(doc.reviewedBy),
    construction_progress: asInt(doc.constructionProgress, 0),
    navigation_notes: asNullableText(doc.navigationNotes),
    submitted_at: asTime(doc.submittedAt) || asTime(doc.createdAt) || new Date().toISOString(),
    completed_at: asTime(doc.completedAt),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
    is_deleted: asBool(doc.isDeleted, false),
  };
}

function bookingsRow(doc) {
  return {
    id: rowId(doc),
    booking_ref: asText(doc.bookingRef, rowId(doc)),
    vehicle_owner_id: asText(doc.vehicleOwnerId),
    parking_listing_id: asText(doc.parkingListingId),
    ticket_id: asText(doc.ticketId),
    parking_type: asText(doc.parkingType, 'open'),
    vehicle_number: asText(doc.vehicleNumber),
    vehicle_model: asNullableText(doc.vehicleModel),
    start_date_time: asTime(doc.startDateTime) || new Date().toISOString(),
    end_date_time: asTime(doc.endDateTime) || new Date().toISOString(),
    duration_hours: asNumber(doc.durationHours, 0),
    hourly_rate: asNumber(doc.hourlyRate, 0),
    total_price: asNumber(doc.totalPrice, 0),
    status: asText(doc.status, 'confirmed'),
    parking_address: asNullableText(doc.parkingAddress),
    parking_name: asNullableText(doc.parkingName),
    assigned_slot: asNullableInt(doc.assignedSlot),
    qr_payload: asNullableText(doc.qrPayload),
    session_id: asNullableText(doc.sessionId),
    checked_in_at: asTime(doc.checkedInAt),
    checked_out_at: asTime(doc.checkedOutAt),
    actual_duration_hours: asNullableNumber(doc.actualDurationHours),
    amount_due: asNullableNumber(doc.amountDue),
    paid_amount: asNullableNumber(doc.paidAmount),
    payment_id: asNullableText(doc.paymentId),
    paid_at: asTime(doc.paidAt),
    payment_method: asNullableText(doc.paymentMethod),
    razorpay_order_id: asNullableText(doc.razorpayOrderId),
    split: doc.split == null ? null : asJson(doc.split),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
  };
}

function paymentsRow(doc) {
  return {
    id: rowId(doc),
    booking_id: asText(doc.bookingId),
    booking_ref: asNullableText(doc.bookingRef),
    vehicle_owner_id: asNullableText(doc.vehicleOwnerId),
    amount: asNumber(doc.amount, 0),
    method: asNullableText(doc.method),
    status: asText(doc.status, 'paid'),
    split: doc.split == null ? null : asJson(doc.split),
    razorpay_order_id: asNullableText(doc.razorpayOrderId),
    razorpay_payment_id: asNullableText(doc.razorpayPaymentId),
    razorpay_signature: asNullableText(doc.razorpaySignature),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function reviewsRow(doc) {
  return {
    id: rowId(doc),
    parking_listing_id: asText(doc.parkingListingId),
    vehicle_owner_id: asText(doc.vehicleOwnerId),
    reviewer_name: asText(doc.reviewerName),
    rating: asInt(doc.rating, 1),
    comment: asText(doc.comment),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    updated_at: asTime(doc.updatedAt),
  };
}

function favoritesRow(doc) {
  return {
    id: rowId(doc),
    vehicle_owner_id: asText(doc.vehicleOwnerId),
    parking_listing_id: asText(doc.parkingListingId),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function vehicleOwnerNotificationsRow(doc) {
  return {
    id: rowId(doc),
    vehicle_owner_id: asText(doc.vehicleOwnerId || doc.recipientId),
    title: asText(doc.title, 'Notification'),
    message: asText(doc.message || doc.body),
    booking_ref: asNullableText(doc.bookingRef || doc.referenceId),
    is_read: asBool(doc.isRead, false),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function landOwnerNotificationsRow(doc) {
  return {
    id: rowId(doc),
    owner_id: asText(doc.ownerId || doc.recipientId),
    title: asText(doc.title, 'Notification'),
    message: asText(doc.message || doc.body),
    is_read: asBool(doc.isRead, false),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function employeeNotificationsRow(doc) {
  return {
    id: rowId(doc),
    employee_id: asText(doc.employeeId || doc.recipientId),
    title: asText(doc.title, 'Notification'),
    message: asText(doc.message || doc.body),
    ticket_id: asNullableText(doc.ticketId || doc.referenceId),
    is_read: asBool(doc.isRead, false),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function notificationsRow(doc) {
  return {
    id: rowId(doc),
    recipient_id: asNullableText(doc.recipientId || doc.userId || doc.vehicleOwnerId),
    recipient_type: asNullableText(doc.recipientType),
    title: asText(doc.title, 'Notification'),
    message: asText(doc.message || doc.body),
    is_read: asBool(doc.isRead, false),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    doc,
  };
}

function quotationsRow(doc) {
  return {
    id: rowId(doc),
    ticket_id: asText(doc.ticketId),
    request_id: asText(doc.requestId || doc.ticketId),
    employee_id: asText(doc.employeeId),
    amount: asNumber(doc.amount, 0),
    materials_cost: asNumber(doc.materialsCost, 0),
    labor_cost: asNumber(doc.laborCost, 0),
    timeline_days: asInt(doc.timelineDays, 0),
    description: asText(doc.description),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function constructionProgressRow(doc) {
  return {
    id: rowId(doc),
    ticket_id: asText(doc.ticketId),
    request_id: asText(doc.requestId || doc.ticketId),
    employee_id: asText(doc.employeeId),
    progress_percent: asInt(doc.progressPercent ?? doc.progress, 0),
    notes: asText(doc.notes),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
  };
}

function documentsRow(doc) {
  return {
    id: rowId(doc),
    owner_id: asNullableText(doc.ownerId),
    url: asNullableText(doc.url),
    category: asNullableText(doc.category),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    doc,
  };
}

function parkingSpacesRow(doc) {
  return {
    id: rowId(doc),
    created_at: asTime(doc.createdAt) || new Date().toISOString(),
    doc,
  };
}

const ROW_BUILDERS = {
  users: usersRow,
  employees: employeesRow,
  vehicle_owner_profiles: vehicleOwnerProfilesRow,
  land_owner_profiles: landOwnerProfilesRow,
  land_owner_requests: landOwnerRequestsRow,
  bookings: bookingsRow,
  payments: paymentsRow,
  parking_reviews: reviewsRow,
  vehicle_owner_favorites: favoritesRow,
  vehicle_owner_notifications: vehicleOwnerNotificationsRow,
  land_owner_notifications: landOwnerNotificationsRow,
  employee_notifications: employeeNotificationsRow,
  notifications: notificationsRow,
  quotations: quotationsRow,
  construction_progress: constructionProgressRow,
  documents: documentsRow,
  parking_spaces: parkingSpacesRow,
};

async function prepareNamedTables(pool) {
  for (const table of NAMED_TABLES) {
    await pool.query(`alter table if exists public.${table} disable row level security`);
  }
  await pool.query('grant all on all tables in schema public to current_user');
}

async function syncNamedTable(pool, collection, doc) {
  const builder = ROW_BUILDERS[collection];
  if (!builder || !doc) return;
  try {
    await upsert(pool, collection, builder(doc));
  } catch (error) {
    console.error(`Named table sync failed for ${collection}: ${error.message}`);
  }
}

async function deleteNamedTable(pool, collection, id) {
  if (!ROW_BUILDERS[collection] || !id) return;
  try {
    await pool.query(`delete from public.${collection} where id = $1`, [id]);
  } catch (error) {
    console.error(`Named table delete failed for ${collection}: ${error.message}`);
  }
}

async function backfillNamedTables(pool) {
  await prepareNamedTables(pool);
  const result = await pool.query(
    'select collection, doc from mongo_documents order by collection, id',
  );
  let synced = 0;
  for (const row of result.rows) {
    if (!ROW_BUILDERS[row.collection]) continue;
    await syncNamedTable(pool, row.collection, row.doc);
    synced += 1;
  }
  if (synced) {
    console.log(`Synced ${synced} documents into named Supabase tables`);
  }
}

module.exports = {
  prepareNamedTables,
  syncNamedTable,
  deleteNamedTable,
  backfillNamedTables,
  oidHex,
};
