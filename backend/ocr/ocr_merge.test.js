/**
 * OCR merge / fallback decision tests.
 * Run: node ocr/ocr_merge.test.js
 */
const assert = require('assert');
const { needsTesseractFallback, mergeEngineResults } = require('./ocr_merge');

function testStrongPaddleSkipsFallback() {
  const plan = needsTesseractFallback(
    {
      fullName: 'Hari Haran',
      address: 'Long enough address line with district and state',
      governmentIdNumber: '999999990019',
      phone: '9876543210',
    },
    'aadhaar',
  );
  assert.strictEqual(plan.needed, false);
}

function testMissingPhoneTriggersFallback() {
  const plan = needsTesseractFallback(
    {
      fullName: 'Hari Haran',
      address: 'Long enough address line with district and state',
      governmentIdNumber: '999999990019',
      phone: '',
    },
    'aadhaar',
  );
  assert.strictEqual(plan.needed, true);
  assert.strictEqual(plan.reason, 'missing_phone');
}

function testMergeKeepsPhoneFromTesseract() {
  const merged = mergeEngineResults(
    {
      fullName: 'Hari Haran',
      address: 'Long OCR address',
      governmentIdNumber: '999999990019',
      phone: '',
    },
    {
      fullName: 'Hari Haran',
      address: 'Long OCR address',
      governmentIdNumber: '999999990019',
      phone: '9876543210',
    },
    'aadhaar',
  );
  assert.strictEqual(merged.phone, '9876543210');
}

const tests = [testStrongPaddleSkipsFallback, testMissingPhoneTriggersFallback, testMergeKeepsPhoneFromTesseract];
for (const fn of tests) {
  fn();
  console.log(`OK ${fn.name}`);
}
console.log(`\n${tests.length}/${tests.length} merge tests passed`);
