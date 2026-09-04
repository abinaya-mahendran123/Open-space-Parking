/**
 * Parking slot capacity helpers (server-side source of truth).
 */

const SQ_FT_PER_CAR = 150;
const CONSTRUCTED_PARKING_SLOTS = 100;

function slotsFromLandArea(areaSqFt) {
  const area = Number(areaSqFt);
  if (!Number.isFinite(area) || area <= 0) return 1;
  const slots = Math.floor(area / SQ_FT_PER_CAR);
  return slots < 1 ? 1 : slots;
}

function resolveCapacity({ requestType, areaSqFt, storedNumberOfCars } = {}) {
  const type = String(requestType || '').trim().toLowerCase();
  if (type === 'build_parking') {
    const stored = Number(storedNumberOfCars);
    if (Number.isFinite(stored) && stored > 0) return Math.floor(stored);
    return CONSTRUCTED_PARKING_SLOTS;
  }

  const area = Number(areaSqFt);
  if (Number.isFinite(area) && area > 0) {
    return slotsFromLandArea(area);
  }

  const stored = Number(storedNumberOfCars);
  if (Number.isFinite(stored) && stored > 0) return Math.floor(stored);
  return 1;
}

module.exports = {
  SQ_FT_PER_CAR,
  CONSTRUCTED_PARKING_SLOTS,
  slotsFromLandArea,
  resolveCapacity,
};
