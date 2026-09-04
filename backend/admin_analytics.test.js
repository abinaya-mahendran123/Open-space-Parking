const assert = require('assert');
const {
  toIstDayKey,
  peakOccupancyForDay,
  countCheckInsForDay,
  buildDailyOccupancy,
  resolveDateRange,
} = require('./admin_analytics');

function testPeakAndCheckIns() {
  const day = '2026-09-03';
  const sessions = [
    {
      checkedInAt: '2026-09-03T02:30:00.000Z', // 08:00 IST
      checkedOutAt: '2026-09-03T06:30:00.000Z', // 12:00 IST
    },
    {
      checkedInAt: '2026-09-03T04:30:00.000Z', // 10:00 IST
      checkedOutAt: '2026-09-03T08:30:00.000Z', // 14:00 IST
    },
    {
      checkedInAt: '2026-09-03T10:30:00.000Z', // 16:00 IST
      checkedOutAt: null,
    },
    {
      checkedInAt: '2026-09-02T10:00:00.000Z', // previous day
      checkedOutAt: '2026-09-03T03:30:00.000Z', // still there until 09:00 IST
    },
  ];

  assert.strictEqual(countCheckInsForDay(sessions, day), 3);
  // Overnight + morning car overlap until 09:00 IST → peak 2
  // Morning pair overlap 10:00–12:00 IST → peak 2
  const peak = peakOccupancyForDay(
    sessions,
    day,
    new Date('2026-09-03T12:00:00.000Z'),
  );
  assert.strictEqual(peak, 2);

  const daily = buildDailyOccupancy(
    sessions,
    [day],
    new Date('2026-09-03T12:00:00.000Z'),
  );
  assert.strictEqual(daily[0].checkIns, 3);
  assert.strictEqual(daily[0].peakOccupancy, 2);
}

function testIstDayKey() {
  // 2026-09-03 22:30 UTC = 2026-09-04 04:00 IST
  assert.strictEqual(toIstDayKey('2026-09-03T22:30:00.000Z'), '2026-09-04');
  assert.strictEqual(toIstDayKey('2026-09-03T18:00:00.000Z'), '2026-09-03');
}

function testDateRange() {
  const range = resolveDateRange({ from: '2026-09-01', to: '2026-09-03' });
  assert.deepStrictEqual(range.days, [
    '2026-09-01',
    '2026-09-02',
    '2026-09-03',
  ]);
}

testIstDayKey();
testPeakAndCheckIns();
testDateRange();
console.log('admin_analytics.test.js: ok');
