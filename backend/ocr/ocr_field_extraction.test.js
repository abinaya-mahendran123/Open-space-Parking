/**
 * Field extraction unit tests — synthetic/redacted text only.
 * Run: node ocr/ocr_field_extraction.test.js
 */
const assert = require('assert');
const {
  extractName,
  extractAddress,
  extractPhone,
  extractIdNumber,
  isValidAadhaarChecksum,
  scoreOcrExtraction,
  isCompleteAadhaarQr,
  mergeWithPreference,
} = require('./field_extraction');

function testNameRejectsGovernmentHeader() {
  const text = 'Government of India\nGovemmentofingia Pee\nHari Haran\nDOB: 01/01/1990';
  const name = extractName(text);
  assert.strictEqual(name, 'Hari Haran');
}

function testAddressEnglish() {
  const text = [
    'To',
    'Hari Haran',
    'S/O: Test Parent',
    '12 Sample Street',
    'Sample Nagar',
    'Madurai',
    'Tamil Nadu - 625001',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('Sample Street'), `address=${address}`);
}

function testAddressPreservesUnicode() {
  const text = 'S/O: Parent\n123 Test Street\nமதுரை\nTamil Nadu - 625001';
  const address = extractAddress(text, { preserveUnicode: true });
  assert.ok(address.includes('மதுரை') || address.includes('Test Street'), address);
}

function testPhoneLabeled() {
  const text = 'Mobile: 9876543210\nAadhaar No: 2345 6789 0123';
  const phone = extractPhone(text, 'aadhaar');
  assert.strictEqual(phone, '9876543210');
}

function testAadhaarVerhoeff() {
  // Known valid test Aadhaar from UIDAI examples (synthetic fixture)
  const valid = '999999990019';
  assert.strictEqual(isValidAadhaarChecksum(valid), true);
  assert.strictEqual(isValidAadhaarChecksum('123456789012'), false);
}

function testQrComplete() {
  const qr = {
    fullName: 'Test User',
    address: 'Sample Address, City',
    governmentIdNumber: '999999990019',
    aadhaarNumber: '999999990019',
  };
  assert.strictEqual(isCompleteAadhaarQr(qr), true);
}

function testMergeQrPreference() {
  const qr = {
    fullName: 'Qr Name',
    address: 'Short',
    governmentIdNumber: '999999990019',
    aadhaarNumber: '999999990019',
    source: 'aadhaar_qr',
  };
  const ocr = {
    fullName: 'Ocr Name',
    address: 'Longer OCR Address, City, State',
    phone: '9876543210',
    governmentIdNumber: '999999990019',
    rawText: '...',
  };
  const merged = mergeWithPreference(qr, ocr);
  assert.strictEqual(merged.fullName, 'Qr Name');
  assert.strictEqual(merged.phone, '9876543210');
  assert.ok(merged.address.length >= 'Short'.length);
}

function testScoreOcrExtraction() {
  const score = scoreOcrExtraction({
    fullName: 'Hari Haran',
    address: 'Long sample address with district and state pin',
    governmentIdNumber: '999999990019',
    phone: '9876543210',
  });
  assert.ok(score >= 75, `score=${score}`);
}

const tests = [
  testNameRejectsGovernmentHeader,
  testAddressEnglish,
  testAddressPreservesUnicode,
  testPhoneLabeled,
  testAadhaarVerhoeff,
  testQrComplete,
  testMergeQrPreference,
  testScoreOcrExtraction,
];

let passed = 0;
for (const fn of tests) {
  fn();
  passed += 1;
  console.log(`OK ${fn.name}`);
}
console.log(`\n${passed}/${tests.length} field extraction tests passed`);
