/**
 * Unit tests for property document type classification.
 * Run: node ocr/property_doc_extraction.test.js
 */
const assert = require('assert');
const { classifyPropertyDocument } = require('./property_doc_extraction');

function testAcceptsPatta() {
  const text = [
    'Tamil Nadu Land Revenue Department',
    'Patta / Chitta Extract',
    'Pattadar: Test Owner',
    'Survey No: 123/4A',
    'Village: Samplepuram',
    'Taluk: Madurai South',
    'District: Madurai',
  ].join('\n');
  const result = classifyPropertyDocument(text, 'patta');
  assert.strictEqual(result.accepted, true, JSON.stringify(result));
}

function testRejectsAadhaarAsPatta() {
  const text = 'Government of India Unique Identification Authority Aadhaar UIDAI';
  const result = classifyPropertyDocument(text, 'patta');
  assert.strictEqual(result.accepted, false);
  assert.match(result.message, /Aadhaar|upload your Patta/i);
}

function testRejectsTaxAsPatta() {
  const text = [
    'Property Tax Receipt',
    'House Tax Demand Notice',
    'Assessment No: 9988',
    'Tax Paid for Half Year',
    'Ward No: 12',
    'Arrears: Nil',
  ].join('\n');
  const result = classifyPropertyDocument(text, 'patta');
  assert.strictEqual(result.accepted, false, JSON.stringify(result));
  assert.match(result.message, /Property Tax|correct Patta/i);
}

function testAcceptsPropertyTax() {
  const text = [
    'Municipal Property Tax Receipt',
    'House Tax / Assessment',
    'Assessment No: 4455',
    'Tax Paid',
    'Ward No: 4',
    'Half Year: I',
  ].join('\n');
  const result = classifyPropertyDocument(text, 'property_tax');
  assert.strictEqual(result.accepted, true, JSON.stringify(result));
}

function testAcceptsSaleDeed() {
  const text = [
    'Sale Deed / Conveyance',
    'Registered before the Sub Registrar',
    'Stamp Duty paid',
    'Vendor and Purchaser',
    'Schedule of Property',
    'Document No: 2020/1234',
  ].join('\n');
  const result = classifyPropertyDocument(text, 'property_document');
  assert.strictEqual(result.accepted, true, JSON.stringify(result));
}

function testAcceptsMunicipalityCertificate() {
  const text = [
    'Madurai Corporation',
    'Local Body Certificate',
    'Commissioner',
    'No Objection Certificate (NOC)',
    'Approved for parking use',
  ].join('\n');
  const result = classifyPropertyDocument(text, 'municipality_certificate');
  assert.strictEqual(result.accepted, true, JSON.stringify(result));
}

function testRejectsUnreadable() {
  const result = classifyPropertyDocument('xx', 'patta');
  assert.strictEqual(result.accepted, false);
  assert.match(result.message, /clear/i);
}

const tests = [
  testAcceptsPatta,
  testRejectsAadhaarAsPatta,
  testRejectsTaxAsPatta,
  testAcceptsPropertyTax,
  testAcceptsSaleDeed,
  testAcceptsMunicipalityCertificate,
  testRejectsUnreadable,
];

for (const fn of tests) {
  fn();
  console.log(`OK ${fn.name}`);
}
console.log(`\n${tests.length}/${tests.length} property doc classification tests passed`);
