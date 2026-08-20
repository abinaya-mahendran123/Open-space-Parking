/**
 * Vehicle compatibility helpers for parking recommendations.
 * Uses physical dimensions / parking class — not seat count.
 */

function asNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function inferParkingClass(profile = {}) {
  const explicit = String(profile.vehicleParkingClass || profile.parkingClass || '')
    .trim()
    .toLowerCase();
  if (explicit) return explicit;

  const model = String(profile.vehicleModel || '').trim().toLowerCase();
  const brand = String(profile.vehicleBrand || profile.brand || '').trim().toLowerCase();
  const text = `${brand} ${model}`;

  if (/(bike|motorcycle|scooter|activa|pulsar|splendor|bullet)/.test(text)) {
    return 'two_wheeler';
  }
  if (/(truck|bus|tempo|lorry|carrier|van|pickup)/.test(text)) {
    return 'commercial';
  }
  if (/(suv|jeep|fortuner|creta|xuv|harrier|compass|thar|seltos)/.test(text)) {
    return 'suv';
  }
  if (/(hatch|swift|i20|polo|alto|wagon|figo|celerio|tiago)/.test(text)) {
    return 'compact';
  }
  return 'sedan';
}

const DEFAULT_DIMENSIONS = {
  two_wheeler: { lengthM: 2.0, widthM: 0.8 },
  compact: { lengthM: 3.8, widthM: 1.7 },
  sedan: { lengthM: 4.5, widthM: 1.8 },
  suv: { lengthM: 4.8, widthM: 1.9 },
  commercial: { lengthM: 6.2, widthM: 2.3 },
};

function resolveVehicleSpec(profile = {}) {
  const parkingClass = inferParkingClass(profile);
  const defaults = DEFAULT_DIMENSIONS[parkingClass] || DEFAULT_DIMENSIONS.sedan;

  const lengthM =
    asNumber(profile.vehicleLengthM) ??
    asNumber(profile.lengthM) ??
    asNumber(profile.length) ??
    defaults.lengthM;
  const widthM =
    asNumber(profile.vehicleWidthM) ??
    asNumber(profile.widthM) ??
    asNumber(profile.width) ??
    defaults.widthM;

  const requiredAreaSqM = lengthM * widthM * 1.15;

  return {
    brand: String(profile.vehicleBrand || profile.brand || '').trim(),
    model: String(profile.vehicleModel || profile.model || '').trim(),
    parkingClass,
    lengthM,
    widthM,
    requiredAreaSqM,
  };
}

function listingCapacity(doc) {
  const prefs = doc.parkingPreferences || {};
  const cars =
    asNumber(prefs.numberOfCars) ??
    asNumber(doc.capacity) ??
    asNumber(doc.numberOfCars) ??
    1;
  return cars > 0 ? Math.floor(cars) : 0;
}

function listingSlotAreaSqM(doc) {
  const land = doc.landDetails || {};
  const areaSqFt = asNumber(land.areaSqFt) || 0;
  const capacity = listingCapacity(doc);
  if (areaSqFt > 0 && capacity > 0) {
    return (areaSqFt / capacity) * 0.092903;
  }

  const parkingType = String(
    (doc.parkingPreferences && doc.parkingPreferences.parkingType) ||
      doc.parkingType ||
      '',
  ).toLowerCase();

  switch (parkingType) {
    case 'tower_parking':
    case 'shuttle_parking':
    case 'puzzle_parking':
      return 14;
    case 'hydraulic_stack_4_post':
      return 12;
    case 'hydraulic_stack_2_post':
      return 10;
    case 'pit_stack_parking':
      return 11;
    default:
      return 12;
  }
}

function maxVehicleClassForParkingType(doc) {
  const parkingType = String(
    (doc.parkingPreferences && doc.parkingPreferences.parkingType) ||
      doc.parkingType ||
      '',
  ).toLowerCase();

  switch (parkingType) {
    case 'hydraulic_stack_2_post':
      return ['two_wheeler', 'compact', 'sedan'];
    case 'hydraulic_stack_4_post':
      return ['two_wheeler', 'compact', 'sedan', 'suv'];
    case 'pit_stack_parking':
      return ['two_wheeler', 'compact', 'sedan', 'suv'];
    case 'tower_parking':
    case 'shuttle_parking':
    case 'puzzle_parking':
      return ['two_wheeler', 'compact', 'sedan', 'suv', 'commercial'];
    default:
      return ['two_wheeler', 'compact', 'sedan', 'suv'];
  }
}

const CLASS_RANK = {
  two_wheeler: 1,
  compact: 2,
  sedan: 3,
  suv: 4,
  commercial: 5,
};

function isVehicleCompatibleWithListing(vehicleSpec, doc) {
  const allowed = maxVehicleClassForParkingType(doc);
  if (!allowed.includes(vehicleSpec.parkingClass)) {
    return false;
  }

  const slotAreaSqM = listingSlotAreaSqM(doc);
  return vehicleSpec.requiredAreaSqM <= slotAreaSqM;
}

module.exports = {
  resolveVehicleSpec,
  listingCapacity,
  listingSlotAreaSqM,
  isVehicleCompatibleWithListing,
  inferParkingClass,
  CLASS_RANK,
};
