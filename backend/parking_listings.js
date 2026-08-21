function iso(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function namedRequestToDoc(row) {
  return {
    _id: { $oid: row.id },
    ticketId: row.ticket_id,
    ownerId: row.owner_id,
    requestType: row.request_type,
    status: row.status,
    ownerDetails: row.owner_details || {},
    documents: row.documents || {},
    landDetails: row.land_details || {},
    parkingPreferences: row.parking_preferences,
    assignedEmployeeId: row.assigned_employee_id,
    assignedEmployeeName: row.assigned_employee_name,
    documentsVerified: row.documents_verified === true,
    adminNotes: row.admin_notes,
    reviewedAt: iso(row.reviewed_at),
    reviewedBy: row.reviewed_by,
    constructionProgress: row.construction_progress || 0,
    navigationNotes: row.navigation_notes,
    submittedAt: iso(row.submitted_at),
    completedAt: iso(row.completed_at),
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    isDeleted: row.is_deleted === true,
  };
}

/** Legacy name kept for existing imports. */
function isEmployeeVerifiedListing(doc) {
  return isPublicParkingListing(doc);
}

/**
 * Parking visible to vehicle owners in nearby search.
 * Admin-approved, verified, active, with valid GPS and capacity.
 */
function isPublicParkingListing(doc) {
  if (!doc || doc.isDeleted) return false;
  if (doc.documentsVerified !== true) return false;
  if (doc.isActive === false) return false;

  const status = String(doc.status || '');
  const blockedStatuses = new Set([
    'rejected',
    'submitted',
    'under_review',
    'in_progress',
  ]);
  if (blockedStatuses.has(status)) return false;
  if (status !== 'approved' && status !== 'completed') return false;

  const land = doc.landDetails || {};
  const lat = Number(land.gpsLatitude);
  const lng = Number(land.gpsLongitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false;
  if (lat === 0 && lng === 0) return false;

  const cars = Number(
    (doc.parkingPreferences && doc.parkingPreferences.numberOfCars) ??
      doc.capacity ??
      doc.numberOfCars ??
      1,
  );
  if (Number.isFinite(cars) && cars <= 0) return false;
  return true;
}

async function loadNamedRequests(pool) {
  const result = await pool.query('select * from public.land_owner_requests');
  return result.rows.map(namedRequestToDoc);
}

async function nearbyVerifiedListings(pool) {
  const docs = await loadNamedRequests(pool);
  return docs.filter(isEmployeeVerifiedListing);
}

async function verifiedListingById(pool, id) {
  const hex = String(id || '').match(/[a-fA-F0-9]{24}/);
  const lookup = hex ? hex[0] : String(id || '').trim();
  if (!lookup || lookup === '[object Object]') return null;
  const result = await pool.query(
    'select * from public.land_owner_requests where id = $1 limit 1',
    [lookup],
  );
  if (!result.rows[0]) return null;
  const doc = namedRequestToDoc(result.rows[0]);
  return isEmployeeVerifiedListing(doc) ? doc : null;
}

async function verifiedListingByTicketId(pool, ticketId) {
  const ticket = String(ticketId || '').trim();
  if (!ticket) return null;
  const result = await pool.query(
    'select * from public.land_owner_requests where ticket_id = $1 limit 1',
    [ticket],
  );
  if (!result.rows[0]) return null;
  const doc = namedRequestToDoc(result.rows[0]);
  return isEmployeeVerifiedListing(doc) ? doc : null;
}

module.exports = {
  namedRequestToDoc,
  isEmployeeVerifiedListing,
  isPublicParkingListing,
  loadNamedRequests,
  nearbyVerifiedListings,
  verifiedListingById,
  verifiedListingByTicketId,
};

