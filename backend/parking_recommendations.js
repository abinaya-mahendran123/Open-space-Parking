const {
  isPublicParkingListing,
  loadNamedRequests,
} = require('./parking_listings');
const {
  resolveVehicleSpec,
  isVehicleCompatibleWithListing,
  listingSlotAreaSqM,
  listingCapacity,
} = require('./vehicle_compatibility');

function toRadians(value) {
  return (value * Math.PI) / 180;
}

function distanceKmBetween(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function parseObjectId(value) {
  const text = String(value || '').trim();
  const match = text.match(/[a-fA-F0-9]{24}/);
  return match ? match[0] : text;
}

async function loadVehicleProfile(db, vehicleOwnerId) {
  if (!vehicleOwnerId) return null;

  const ownerHex = parseObjectId(vehicleOwnerId);
  let profileDoc = await db.collection('vehicle_owner_profiles').findOne({
    vehicleOwnerId: ownerHex,
  });
  if (!profileDoc) {
    profileDoc = await db.collection('vehicle_owner_profiles').findOne({
      vehicleOwnerId,
    });
  }
  if (!profileDoc) return null;

  return profileDoc.profile || profileDoc;
}

async function countActiveBookings(db, listingId) {
  const hex = parseObjectId(listingId);
  const now = new Date();
  const end = new Date(now.getTime() + 60 * 60 * 1000);

  const bookings = await db
    .collection('bookings')
    .find({ parkingListingId: { $in: [hex, listingId] } })
    .toArray();

  return bookings.filter((doc) => {
    const status = String(doc.status || '');
    if (status === 'cancelled' || status === 'completed') return false;
    if (status === 'confirmed' || status === 'active') return true;

    const start = new Date(doc.startDateTime);
    const bookingEnd = new Date(doc.endDateTime);
    if (Number.isNaN(start.getTime()) || Number.isNaN(bookingEnd.getTime())) {
      return false;
    }
    return start < end && bookingEnd > now;
  }).length;
}

function listingToRecommendation(doc, extras = {}) {
  const land = doc.landDetails || {};
  const prefs = doc.parkingPreferences || {};
  const capacity = listingCapacity(doc);

  return {
    id: parseObjectId(doc._id),
    ticketId: doc.ticketId || '',
    parkingName:
      (land.landAddress && String(land.landAddress).trim()) ||
      doc.ticketId ||
      'Open Space Parking',
    address: land.landAddress || null,
    latitude: Number(land.gpsLatitude),
    longitude: Number(land.gpsLongitude),
    parkingType: prefs.parkingType || doc.parkingType || null,
    capacity,
    availableSlots: extras.availableSlots ?? capacity,
    distanceKm: extras.distanceKm ?? null,
    isCompatible: extras.isCompatible === true,
    parkingStatus: doc.status || 'approved',
    isActive: doc.isActive !== false,
    documentsVerified: doc.documentsVerified === true,
    areaSqFt: Number(land.areaSqFt) || 0,
    slotAreaSqM: listingSlotAreaSqM(doc),
    hourlyRate:
      Number(prefs.hourlyRate) ||
      Number(doc.hourlyRate) ||
      Number(doc.amountPerHour) ||
      null,
    rankScore: extras.rankScore ?? 0,
    isBestMatch: extras.isBestMatch === true,
  };
}

async function recommendNearbyParking(db, options = {}) {
  const latitude = Number(options.latitude);
  const longitude = Number(options.longitude);
  const radiusKm = Number(options.radiusKm ?? options.radius ?? 25);
  const vehicleOwnerId = options.vehicleOwnerId || options.vehicle_id || null;

  const hasLocation =
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    !(latitude === 0 && longitude === 0);

  const vehicleProfile = await loadVehicleProfile(db, vehicleOwnerId);
  const vehicleSpec = resolveVehicleSpec(vehicleProfile || {});

  let docs;
  if (db.pool) {
    docs = (await loadNamedRequests(db.pool)).filter(isPublicParkingListing);
  } else {
    docs = await db
      .collection('land_owner_requests')
      .find({ isDeleted: { $ne: true } })
      .toArray();
    docs = docs.filter(isPublicParkingListing);
  }

  const recommendations = [];

  for (const doc of docs) {
    const listingId = parseObjectId(doc._id);
    const capacity = listingCapacity(doc);
    const booked = await countActiveBookings(db, listingId);
    const availableSlots = Math.max(0, capacity - booked);
    if (availableSlots <= 0) continue;

    const compatible = isVehicleCompatibleWithListing(vehicleSpec, doc);
    if (!compatible) continue;

    const land = doc.landDetails || {};
    const lat = Number(land.gpsLatitude);
    const lng = Number(land.gpsLongitude);

    let distanceKm = null;
    if (hasLocation) {
      distanceKm = distanceKmBetween(latitude, longitude, lat, lng);
      if (Number.isFinite(radiusKm) && radiusKm > 0 && distanceKm > radiusKm) {
        continue;
      }
    }

    const availabilityRatio = capacity > 0 ? availableSlots / capacity : 0;
    const rankScore =
      (doc.status === 'approved' ? 1000 : 900) +
      (compatible ? 500 : 0) +
      availabilityRatio * 100 +
      (distanceKm != null ? Math.max(0, 100 - distanceKm * 10) : 0);

    recommendations.push(
      listingToRecommendation(doc, {
        availableSlots,
        distanceKm,
        isCompatible: compatible,
        rankScore,
      }),
    );
  }

  recommendations.sort((a, b) => {
    if (b.rankScore !== a.rankScore) return b.rankScore - a.rankScore;
    const aDist = a.distanceKm ?? Number.POSITIVE_INFINITY;
    const bDist = b.distanceKm ?? Number.POSITIVE_INFINITY;
    return aDist - bDist;
  });

  if (recommendations.length > 0) {
    recommendations[0] = { ...recommendations[0], isBestMatch: true };
  }

  return {
    recommendations,
    vehicle: vehicleSpec,
    meta: {
      count: recommendations.length,
      hasLocation,
      radiusKm: Number.isFinite(radiusKm) ? radiusKm : null,
    },
  };
}

module.exports = {
  recommendNearbyParking,
  distanceKmBetween,
  loadVehicleProfile,
};
