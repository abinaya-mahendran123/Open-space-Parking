/**
 * Trusted billing unit tests — listing rate wins over tampered booking fields.
 * Run: node booking_billing.test.js
 */
const assert = require('assert');
const {
  listingHourlyRate,
  resolveHourlyRate,
  computeBill,
} = require('./booking_service');

function testListingRateFromPrefs() {
  const rate = listingHourlyRate({
    parkingPreferences: { hourlyRate: 80 },
  });
  assert.strictEqual(rate, 80);
}

function testListingRatePrefersTopLevel() {
  const rate = listingHourlyRate({
    hourlyRate: 120,
    parkingPreferences: { hourlyRate: 80 },
  });
  assert.strictEqual(rate, 120);
}

function testResolveIgnoresTamperedBookingRate() {
  const listing = { hourlyRate: 100 };
  const booking = { hourlyRate: 1 }; // attacker-lowered
  const rate = resolveHourlyRate(booking, listing);
  assert.strictEqual(rate, 100);
}

function testResolveFallbackWhenListingMissing() {
  const prev = process.env.DEFAULT_PARKING_HOURLY_RATE;
  process.env.DEFAULT_PARKING_HOURLY_RATE = '55';
  try {
    const rate = resolveHourlyRate({ hourlyRate: 1 }, {});
    assert.strictEqual(rate, 55);
  } finally {
    if (prev == null) delete process.env.DEFAULT_PARKING_HOURLY_RATE;
    else process.env.DEFAULT_PARKING_HOURLY_RATE = prev;
  }
}

function testComputeBillUsesRateAndDuration() {
  const start = '2026-01-01T10:00:00.000Z';
  const end = '2026-01-01T12:00:00.000Z'; // 2 hours
  const bill = computeBill(start, end, 60);
  assert.strictEqual(bill.billedHours, 2);
  assert.strictEqual(bill.amountDue, 120);
  assert.strictEqual(bill.hourlyRate, 60);
}

function testComputeBillMinimumQuarterHour() {
  const start = '2026-01-01T10:00:00.000Z';
  const end = '2026-01-01T10:01:00.000Z';
  const bill = computeBill(start, end, 100);
  assert.strictEqual(bill.billedHours, 0.25);
  assert.strictEqual(bill.amountDue, 25);
}

function testTamperedAmountWouldBeOverwrittenByRecompute() {
  const listing = { hourlyRate: 90 };
  const booking = {
    hourlyRate: 1,
    amountDue: 1,
    checkedInAt: '2026-01-01T08:00:00.000Z',
    checkedOutAt: '2026-01-01T10:00:00.000Z',
  };
  const rate = resolveHourlyRate(booking, listing);
  const bill = computeBill(booking.checkedInAt, booking.checkedOutAt, rate);
  assert.strictEqual(rate, 90);
  assert.strictEqual(bill.amountDue, 180);
  assert.notStrictEqual(bill.amountDue, booking.amountDue);
}

const tests = [
  testListingRateFromPrefs,
  testListingRatePrefersTopLevel,
  testResolveIgnoresTamperedBookingRate,
  testResolveFallbackWhenListingMissing,
  testComputeBillUsesRateAndDuration,
  testComputeBillMinimumQuarterHour,
  testTamperedAmountWouldBeOverwrittenByRecompute,
];

let passed = 0;
for (const fn of tests) {
  fn();
  passed += 1;
  console.log(`OK ${fn.name}`);
}
console.log(`\n${passed}/${tests.length} billing integrity tests passed`);
