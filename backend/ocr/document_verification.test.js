const assert = require('assert');
const {
  buildVerificationReport,
  nameSimilarity,
  addressOverlap,
} = require('../document_verification');
const { extractPropertyFieldsFromText } = require('../ocr/property_doc_extraction');

function testNameSimilarity() {
  assert.ok(nameSimilarity('Hariharan', 'Hari Haran') >= 0.55);
  assert.ok(nameSimilarity('Hariharan', 'Different Person') < 0.4);
  assert.strictEqual(nameSimilarity('Same Name', 'Same Name'), 1);
}

function testAddressOverlap() {
  const score = addressOverlap(
    '268, NSK STREET, Subramaniapuram, Madurai',
    'NSK Street, Subramaniapuram, Madurai South',
  );
  assert.ok(score >= 0.25, `score=${score}`);
}

function testExtractPattaFields() {
  const text = [
    'Patta',
    'Owner: Hariharan',
    'Survey No: 123/4A',
    'District: Madurai',
    'Village: Subramaniapuram',
  ].join('\n');
  const fields = extractPropertyFieldsFromText(text);
  assert.ok(/hariharan/i.test(fields.ownerName), fields.ownerName);
  assert.ok(fields.surveyNumber.includes('123'), fields.surveyNumber);
  assert.ok(/madurai/i.test(fields.district), fields.district);
}

function testReportAllDocsPass() {
  const report = buildVerificationReport({
    ownerDetails: {
      fullName: 'Hariharan',
      address: '268 NSK Street Subramaniapuram Madurai 625011',
    },
    documents: {
      governmentIdPath: 'https://example.com/aadhaar.png',
      propertyDocumentPath: 'https://example.com/prop.pdf',
      pattaPath: 'https://example.com/patta.pdf',
      propertyTaxPath: 'https://example.com/tax.pdf',
      municipalityCertificatePath: 'https://example.com/muni.pdf',
    },
    landDetails: {
      landAddress: 'NSK Street Subramaniapuram Madurai',
      areaSqFt: 500,
    },
    extracted: {
      ownerName: 'Hariharan',
      surveyNumber: '123/4A',
      district: 'Madurai',
      sources: ['patta'],
    },
  });
  assert.strictEqual(report.status, 'complete');
  assert.ok(report.checks.find((c) => c.id === 'required_docs')?.pass);
  assert.ok(report.checks.find((c) => c.id === 'owner_name_match')?.pass);
  assert.ok(report.readyForQuickApproval);
}

function testReportMissingDocs() {
  const report = buildVerificationReport({
    ownerDetails: { fullName: 'Test User' },
    documents: { pattaPath: 'https://example.com/patta.pdf' },
    landDetails: { areaSqFt: 0 },
    extracted: {},
  });
  assert.ok(!report.checks.find((c) => c.id === 'required_docs')?.pass);
  assert.ok(!report.readyForQuickApproval);
}

const tests = [
  testNameSimilarity,
  testAddressOverlap,
  testExtractPattaFields,
  testReportAllDocsPass,
  testReportMissingDocs,
];

for (const fn of tests) {
  fn();
  console.log(`OK ${fn.name}`);
}
console.log(`\n${tests.length}/${tests.length} document verification tests passed`);
