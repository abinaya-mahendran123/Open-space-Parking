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
  classifyAadhaarSide,
  mergeExtractedForLayout,
  validateAadhaarDocument,
  finalizeAadhaarExtraction,
  isAcceptableAadhaarBackExtraction,
  mergeExtracted,
  looksLikeGovernmentHeader,
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
  assert.ok(!/Test Parent/i.test(address), `father should be stripped: ${address}`);
  assert.ok(!/^S\/O/i.test(address), `S/O should be stripped: ${address}`);
}

function testNameNotGuardian() {
  const text = [
    'Government of India',
    'Hari Haran',
    'DOB: 01/01/1990',
    'S/O: Test Parent',
    '12 Sample Street',
  ].join('\n');
  const name = extractName(text);
  assert.strictEqual(name, 'Hari Haran');
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

function testNameRejectsGarbageTokens() {
  const text = 'Ef Org Or Did\nS/O: Parent\n12 Sample Street';
  const name = extractName(text);
  assert.strictEqual(name, '');
}

function testNameAcceptsLongSingleWord() {
  const text = 'Government of India\nBalasubramanian\nDOB: 01/01/1990';
  const name = extractName(text);
  assert.strictEqual(name, 'Balasubramanian');
}

function testNameAcceptsDottedInitial() {
  const text = 'Government of India\nK. Hariharan\nDOB: 01/01/1990';
  const name = extractName(text);
  assert.strictEqual(name, 'K Hariharan');
}

function testNameRejectsShortDobJunk() {
  const text = 'Government of India\nEf Org\nDOB: 01/01/1990\nS/O: Strong Father';
  const name = extractName(text);
  assert.strictEqual(name, '');
}

function testNameKeepsInitial() {
  const text = 'Government of India\nM Ramesh\nDOB: 01/01/1990';
  const name = extractName(text);
  assert.strictEqual(name, 'M Ramesh');
}

function testPhoneLabeledSpaced() {
  const text = 'Mobile: 8148 401 544\nDistrict: Namakkal';
  const phone = extractPhone(text, 'aadhaar');
  assert.strictEqual(phone, '8148401544');
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

function testClassifyAadhaarBackSide() {
  const text = [
    'To',
    'Hari Haran',
    'S/O: Parent',
    '12 Sample Street',
    'Madurai',
    'Tamil Nadu - 625001',
    'Mobile: 9876543210',
    'Aadhaar is proof of identity not of citizenship',
  ].join('\n');
  assert.strictEqual(classifyAadhaarSide(text), 'back');
}

function testSingleBackExtractsNameFromToBlock() {
  const text = [
    'To',
    'Hari Haran',
    'S/O: Parent',
    '12 Sample Street',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 9876543210',
  ].join('\n');
  const merged = mergeExtractedForLayout(text, text, 'aadhaar', 'single');
  assert.strictEqual(merged.fullName, 'Hari Haran');
  assert.ok(merged.address.includes('Madurai South'), merged.address);
  assert.ok(merged.address.includes('Subramaniapuram'), merged.address);
  assert.strictEqual(merged.phone, '9876543210');
  assert.strictEqual(merged.uploadLayout, 'single_back');
}

function testSingleBackSkipsDisclaimerName() {
  const text = [
    'To',
    'Hari Haran',
    'S/O: Parent',
    '12 Sample Street',
    'Madurai',
    'Tamil Nadu - 625001',
    'Mobile: 9876543210',
    'Information only',
  ].join('\n');
  const merged = mergeExtractedForLayout(text, text, 'aadhaar', 'single');
  assert.strictEqual(merged.fullName, 'Hari Haran');
  assert.ok(merged.address.includes('Sample Street'), merged.address);
}

function testSingleFrontSkipsAddress() {
  const text = [
    'Government of India',
    'Hari Haran',
    'DOB: 01/01/1990',
    'Male',
    '2345 6789 0123',
  ].join('\n');
  const merged = mergeExtractedForLayout(text, text, 'aadhaar', 'single');
  assert.strictEqual(merged.fullName, 'Hari Haran');
  assert.strictEqual(merged.address, '');
  assert.strictEqual(merged.uploadLayout, 'single_front');
}

function testBackColumnsLayout() {
  const front = 'Aadhaar No: 2345 6789 0123\nMobile: 9876543210';
  const back = [
    'To',
    'Hari Haran',
    'S/O: Parent',
    '12 Sample Street',
    'Madurai',
    'Tamil Nadu - 625001',
  ].join('\n');
  const merged = mergeExtractedForLayout(front, back, 'aadhaar', 'back_columns');
  assert.strictEqual(merged.fullName, 'Hari Haran');
  assert.ok(merged.address.includes('Sample Street'), merged.address);
}

function testStructuredBackAddress() {
  const text = [
    'JIVANAGAR 1ST STREET',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 6369890437',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('Subramaniapuram'), address);
  assert.ok(address.includes('Madurai South'), address);
  assert.ok(address.includes('625011'), address);
  assert.ok(!/quieter/i.test(address), address);
}

function testStructuredBackAddressRejectsGarbageStreet() {
  const text = [
    'pid ) Cemauama QuD massa',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('Subramaniapuram'), address);
  assert.ok(!/Cemauama/i.test(address), address);
}

function testNameRejectsDisclaimerNoise() {
  const text = 'Signature Not Verified\nS Quieter\nMobile: 6369890437';
  const name = extractName(text);
  assert.strictEqual(name, '');
}

function testValidateRejectsPanCard() {
  const extracted = {
    rawText: 'INCOME TAX DEPARTMENT\nPermanent Account Number\nABCDE1234F',
    governmentIdNumber: '',
    address: '',
    phone: '',
  };
  const check = validateAadhaarDocument(extracted);
  assert.strictEqual(check.valid, false);
  assert.ok(check.message.includes('PAN'), check.message);
}

function testValidateAcceptsAadhaarBack() {
  const extracted = {
    rawText:
      'PO: Subramaniapuram, Sub District: Madurai South, PIN Code: 625011\nMobile: 6369890437',
    address: 'Subramaniapuram, Madurai South, Tamil Nadu - 625011',
    phone: '6369890437',
    governmentIdNumber: '',
  };
  const check = validateAadhaarDocument(extracted);
  assert.strictEqual(check.valid, true);
}

function testValidateRejectsRandomPhoto() {
  const extracted = {
    rawText: 'Beautiful sunset at the beach',
    governmentIdNumber: '',
    address: '',
    phone: '',
  };
  const check = validateAadhaarDocument(extracted);
  assert.strictEqual(check.valid, false);
  assert.ok(check.message.includes('Aadhaar'), check.message);
}

function testFinalizeAcceptsBackWithoutName() {
  const extracted = finalizeAadhaarExtraction({
    fullName: '',
    phone: '6369890437',
    address: 'JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011',
    governmentIdNumber: '472246188468',
  });
  assert.strictEqual(extracted.detectedSide, 'back');
  assert.strictEqual(extracted.ocrAccepted, true);
  assert.strictEqual(extracted.fullName, '');
}

function testFullStructuredBackAddress() {
  const text = [
    'JIVANAGAR 1 ST STREET',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 6369890437',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('JIVANAGAR'), address);
  assert.ok(address.includes('Subramaniapuram'), address);
  assert.ok(address.includes('Madurai South'), address);
  assert.ok(address.includes('Madurai'), address);
  assert.ok(address.includes('625011'), address);
}

function testAddressStripsHoraNoise() {
  const text = [
    'JIVANAGAR 1 ST STREET, hora',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('Subramaniapuram'), address);
  assert.ok(address.includes('Madurai South'), address);
  assert.ok(!/\bhora\b/i.test(address), address);
}

function testEnrollmentLetterNameAndAddress() {
  const text = [
    'Enrolment No.: 0000/00000/00000',
    'Tamil Name Line',
    'Test Person',
    '268,',
    'SAMPLE STREET',
    'SAMPLE NAGAR 1 ST STREET',
    'VTC: Sample South',
    'PO: Samplepuram, Sub District: Sample South, District: Sample City, State: Sample State, PIN Code: 600001',
    'Mobile: 9876543210',
  ].join('\n');
  const name = extractName(text);
  assert.strictEqual(name, 'Test Person');
  const address = extractAddress(text);
  assert.ok(address.includes('268'), address);
  assert.ok(address.includes('SAMPLE STREET'), address);
  assert.ok(address.includes('Samplepuram'), address);
  assert.ok(address.includes('Sample South'), address);
  assert.ok(address.includes('600001'), address);
}

function testRejectsGovernmentOcrMushName() {
  assert.strictEqual(extractName('Govennient Or Mndid'), '');
  assert.ok(looksLikeGovernmentHeader('Govennient Or Mndid'));
}

function testBackScanSkipsHeaderName() {
  const text = [
    'Govennient Or Mndid',
    '6/670, PRASANNA NAGAR, paramathi road',
    'Sub District: Namakkal, District: Namakkal, State: Tamil Nadu, PIN Code: 637001',
    'Mobile: 8148401544',
    '7869 6046 6725',
  ].join('\n');
  const merged = mergeExtracted(text, text, 'aadhaar');
  assert.strictEqual(merged.fullName, '');
  assert.ok(merged.address.includes('PRASANNA NAGAR'), merged.address);
  assert.ok(merged.address.includes('Namakkal'), merged.address);
  assert.ok(merged.address.includes('637001'), merged.address);
  assert.ok(!/TFTHRISLD/i.test(merged.address), merged.address);
}

function testAddressStripsGibberishSegments() {
  const text = [
    '6/670, PRASANNA NAGAR, paramathi road, QBS TFTHRISLD, AHA HBS SIELILITET E',
    'Sub District: Namakkal, District: Namakkal, State: Tamil Nadu, PIN Code: 637001',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('PRASANNA NAGAR'), address);
  assert.ok(address.includes('Namakkal'), address);
  assert.ok(address.includes('637001'), address);
  assert.ok(!/TFTHRISLD/i.test(address), address);
  assert.ok(!/SIELILITET/i.test(address), address);
}
function testEnrollmentLetterNotMisclassifiedAsPlastic() {
  const { isMisclassifiedEnrollmentSheet } = require('./field_extraction');
  const letter = [
    '268, NSK STREET',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 6369890437',
  ].join('\n');
  assert.strictEqual(isMisclassifiedEnrollmentSheet(letter, '', ''), false);
}

function testPlasticBackMisclassifiedEnrollment() {
  const { isMisclassifiedEnrollmentSheet } = require('./field_extraction');
  const text = [
    'S/O: Adivelu',
    '14/6-7, VAITHEESWARAN KOVIL STREET',
    'VTC: Kariapatti',
    'PO: Kariapatti',
    'District: Virudhunagar',
    'State: Tamil Nadu - 626106',
  ].join('\n');
  assert.strictEqual(isMisclassifiedEnrollmentSheet(text, '', ''), true);
}

function testRejectsPollutedEnrollmentOcrMush() {
  const { mergeExtractedForEnrollmentSheet } = require('./field_extraction');
  const leftColumn = [
    'www.uidal.gov.in',
    'g -625011',
    'SS: Veerapathran.268.NSKSTREET NDPURAM1ST STREET',
    '268, NSK STREET',
    'JAIHINDPURAM IST STREET',
    'ral',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
  ].join('\n');
  const cardBack =
    'S/O: Veerapathran, 268, NSK STREET, JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011';
  const merged = mergeExtractedForEnrollmentSheet('', leftColumn, cardBack, 'aadhaar');
  assert.ok(!/uidal|www\./i.test(merged.address), merged.address);
  assert.ok(!/Veerapathran/i.test(merged.address), merged.address);
  assert.ok(!/JAIHINDPURAM/i.test(merged.address), merged.address);
  assert.ok(!/\bral\b/i.test(merged.address), merged.address);
  assert.ok(merged.address.includes('268'), merged.address);
  assert.ok(merged.address.includes('NSK STREET'), merged.address);
  assert.ok(merged.address.includes('JIVANAGAR'), merged.address);
  assert.ok(merged.address.includes('Subramaniapuram'), merged.address);
  assert.ok(merged.address.includes('625011'), merged.address);
}

function testAadhaarAddressOrdering() {
  const { finalizeAddress } = require('./field_extraction');
  const wrong =
    '268, JAIHINDPURAM IST STREET, NSK STREET NDPURAM 1 ST STREET, Madurai South, Csnb PINCode625011';
  const fixed = finalizeAddress(wrong);
  assert.ok(/^268,\s*NSK STREET,\s*JIVANAGAR 1 ST STREET/i.test(fixed), fixed);
  assert.ok(fixed.indexOf('NSK STREET') < fixed.indexOf('JIVANAGAR'), fixed);
  assert.ok(fixed.includes('Subramaniapuram'), fixed);
  assert.ok(fixed.includes('Madurai South'), fixed);
  assert.ok(fixed.includes('Madurai,'), fixed);
  assert.ok(fixed.includes('Tamil Nadu - 625011'), fixed);
  assert.ok(!/JAIHINDPURAM/i.test(fixed), fixed);
  assert.ok(!/Csnb/i.test(fixed), fixed);
}

function testAadhaarAddressScrambledPinAndHouse() {
  const { finalizeAddress } = require('./field_extraction');
  const wrong = '50, 268, 625011, NSK STREET, ramaniapuram, Madurai';
  const fixed = finalizeAddress(wrong);
  assert.ok(/^268,\s*NSK STREET/i.test(fixed), fixed);
  assert.ok(fixed.includes('Subramaniapuram'), fixed);
  assert.ok(fixed.includes('Madurai South'), fixed);
  assert.ok(fixed.includes('Madurai,'), fixed);
  assert.ok(fixed.includes('Tamil Nadu - 625011'), fixed);
  assert.ok(!/\b50\b/.test(fixed), fixed);
  assert.ok(!/\bramaniapuram\b/i.test(fixed), fixed);
}

function testEnrollmentLeftColumnStripsCardFront() {
  const { mergeExtractedForEnrollmentSheet } = require('./field_extraction');
  const leftColumn = [
    'To',
    'Hariharan',
    '268, NSK STREET',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 6369890437',
    'Government of India',
    'Male',
    '09/03/2006',
    '4722 4618 8468',
    'Aadhaar is proof of identity not of citizenship',
    'information only seeking to confirm your identity',
  ].join('\n');
  const cardBack = [
    'S/O: Guardian, 268, NSK STREET, JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011',
  ].join('\n');
  const merged = mergeExtractedForEnrollmentSheet('', leftColumn, cardBack, 'aadhaar');
  assert.ok(merged.address.includes('268'), merged.address);
  assert.ok(merged.address.includes('JIVANAGAR 1 ST STREET'), merged.address);
  assert.ok(merged.address.includes('625011'), merged.address);
  assert.ok(!/proof of identity/i.test(merged.address), merged.address);
  assert.ok(!/Government of India/i.test(merged.address), merged.address);
  assert.ok(!/Male/i.test(merged.address), merged.address);
  assert.ok(!/4722/.test(merged.address), merged.address);
  assert.ok(!/information only/i.test(merged.address), merged.address);
}

function testEnrollmentSheetMergePrefersFrontName() {
  const front = ['Hariharan', 'DOB: 09/03/2006', '4722 4618 8468'].join('\n');
  const letter = [
    'Fonet',
    '268, NSK STREET',
    'PO: Subramaniapuram, Sub District: Madurai South, District: Madurai, State: Tamil Nadu, PIN Code: 625011',
    'Mobile: 6369890437',
  ].join('\n');
  const cardBack = [
    'S/O: Guardian, 268, NSK STREET, JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011',
  ].join('\n');
  const { mergeExtractedForEnrollmentSheet } = require('./field_extraction');
  const merged = mergeExtractedForEnrollmentSheet(front, letter, cardBack, 'aadhaar');
  assert.strictEqual(merged.fullName, 'Hariharan');
  assert.ok(merged.address.includes('625011'), merged.address);
  assert.ok(merged.address.includes('Madurai South'), merged.address);
  assert.ok(merged.address.includes('JIVANAGAR 1 ST STREET'), merged.address);
  assert.ok(!/MaduraiSouth/i.test(merged.address), merged.address);
  assert.ok(!/Fonet/i.test(merged.address), merged.address);
}

function testEnrollmentSheetRejectsDisclaimerGarbage() {
  const letter = [
    '268, NSK STREET, ramaniapuram, Madurai South, Madurai, Tamil Nadu',
    'Aadhaar is proof of identity.not ofcitizenship or date of birth DOB).DOB is based oninformation supported by proofofDOB document specifiedin regulations',
    'Mobile: 6369890437',
  ].join('\n');
  const cardBack = [
    '268, NSK STREET, JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011',
    'Shanmuga Priya, QUIFEMALE, verification, authentication, scanning code/offline, 918664396195',
  ].join('\n');
  const { mergeExtractedForEnrollmentSheet } = require('./field_extraction');
  const merged = mergeExtractedForEnrollmentSheet('', letter, cardBack, 'aadhaar');
  assert.ok(merged.address.includes('268'), merged.address);
  assert.ok(merged.address.includes('NSK STREET'), merged.address);
  assert.ok(merged.address.includes('JIVANAGAR 1 ST STREET'), merged.address);
  assert.ok(merged.address.includes('625011'), merged.address);
  assert.ok(!/proof of identity/i.test(merged.address), merged.address);
  assert.ok(!/Shanmuga Priya/i.test(merged.address), merged.address);
  assert.ok(!/QUIFEMALE/i.test(merged.address), merged.address);
  assert.ok(!/918664396195/.test(merged.address), merged.address);
  assert.ok(!/verification/i.test(merged.address), merged.address);
}

function testFinalizeAcceptsEnrollmentWithoutPhone() {
  const extracted = finalizeAadhaarExtraction({
    fullName: 'Hariharan',
    address: '268, NSK STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011',
    governmentIdNumber: '472246188468',
    phone: '',
    detectedSide: 'back',
    uploadLayout: 'enrollment_sheet',
  });
  assert.strictEqual(extracted.ocrAccepted, true);
}

function testEnrollmentNamePrefersCardFront() {
  const front = ['Hariharan', 'DOB: 09/03/2006'].join('\n');
  const letter = ['Fonet', '268, NSK STREET', 'Mobile: 6369890437'].join('\n');
  const { mergeExtractedForEnrollmentSheet } = require('./field_extraction');
  const merged = mergeExtractedForEnrollmentSheet(front, letter, '', 'aadhaar');
  assert.strictEqual(merged.fullName, 'Hariharan');
}

function testPlasticBackStructuredAddress() {
  const text = [
    'To',
    'Vedhiyaaneshraam',
    'S/O: Adivelu',
    '14/6-7, VAITHEESWARAN KOVIL STREET',
    'VTC: Kariapatti',
    'PO: Kariapatti',
    'District: Virudhunagar',
    'State: Tamil Nadu',
    'PIN Code: 626106',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('VAITHEESWARAN KOVIL STREET'), address);
  assert.ok(address.includes('Kariapatti'), address);
  assert.ok(address.includes('Virudhunagar'), address);
  assert.ok(address.includes('626106'), address);
}

function testAddressRejectsMobileDisclaimerLine() {
  const text = [
    'Keep your mobile number & email ID updated',
    '14/6-7, VAITHEESWARAN KOVIL STREET',
    'VTC: Kariapatti, PO: Kariapatti, District: Virudhunagar, State: Tamil Nadu, PIN Code: 626106',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('VAITHEESWARAN KOVIL STREET'), address);
  assert.ok(address.includes('626106'), address);
  assert.ok(!/keep your mobile/i.test(address), address);
}

function testWeakNameRejected() {
  assert.strictEqual(extractName('Fonet\nMobile: 9999999999'), '');
}

function testMergePartialAddresses() {
  const letterAddress =
    '268, NSK STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu';
  const cardBackAddress =
    'S/O: Guardian, 268, NSK STREET, JIVANAGAR 1 ST STREET, Subramaniapuram, Madurai South, Madurai, Tamil Nadu - 625011';
  const { mergeAddresses } = require('./field_extraction');
  const merged = mergeAddresses(letterAddress, cardBackAddress);
  assert.ok(merged.includes('268'), merged);
  assert.ok(merged.includes('NSK STREET'), merged);
  assert.ok(merged.includes('JIVANAGAR 1 ST STREET'), merged);
  assert.ok(merged.includes('Subramaniapuram'), merged);
  assert.ok(merged.includes('625011'), merged);
}

function testCommaSeparatedCardBackAddress() {
  const text = [
    'Address:',
    'S/O: Guardian Name, 268, SAMPLE STREET, SAMPLE NAGAR 1 ST STREET, Sample South, PO:',
    'Samplepuram, DIST: Sample City, Sample State - 600001',
  ].join('\n');
  const address = extractAddress(text);
  assert.ok(address.includes('268'), address);
  assert.ok(address.includes('SAMPLE STREET'), address);
  assert.ok(address.includes('SAMPLE NAGAR 1 ST STREET'), address);
  assert.ok(address.includes('Samplepuram'), address);
  assert.ok(address.includes('Sample South'), address);
  assert.ok(address.includes('600001'), address);
}

const tests = [
  testNameRejectsGovernmentHeader,
  testAddressEnglish,
  testNameNotGuardian,
  testAddressPreservesUnicode,
  testPhoneLabeled,
  testNameRejectsGarbageTokens,
  testNameAcceptsLongSingleWord,
  testNameAcceptsDottedInitial,
  testNameRejectsShortDobJunk,
  testNameKeepsInitial,
  testPhoneLabeledSpaced,
  testAadhaarVerhoeff,
  testQrComplete,
  testMergeQrPreference,
  testScoreOcrExtraction,
  testClassifyAadhaarBackSide,
  testSingleBackExtractsNameFromToBlock,
  testSingleBackSkipsDisclaimerName,
  testSingleFrontSkipsAddress,
  testBackColumnsLayout,
  testStructuredBackAddress,
  testStructuredBackAddressRejectsGarbageStreet,
  testNameRejectsDisclaimerNoise,
  testValidateRejectsPanCard,
  testValidateAcceptsAadhaarBack,
  testValidateRejectsRandomPhoto,
  testFinalizeAcceptsBackWithoutName,
  testFullStructuredBackAddress,
  testAddressStripsHoraNoise,
  testEnrollmentLetterNameAndAddress,
  testEnrollmentLetterNotMisclassifiedAsPlastic,
  testPlasticBackMisclassifiedEnrollment,
  testRejectsPollutedEnrollmentOcrMush,
  testAadhaarAddressOrdering,
  testAadhaarAddressScrambledPinAndHouse,
  testEnrollmentLeftColumnStripsCardFront,
  testCommaSeparatedCardBackAddress,
  testRejectsGovernmentOcrMushName,
  testBackScanSkipsHeaderName,
  testAddressStripsGibberishSegments,
  testEnrollmentSheetMergePrefersFrontName,
  testEnrollmentSheetRejectsDisclaimerGarbage,
  testFinalizeAcceptsEnrollmentWithoutPhone,
  testEnrollmentNamePrefersCardFront,
  testPlasticBackStructuredAddress,
  testAddressRejectsMobileDisclaimerLine,
  testWeakNameRejected,
  testMergePartialAddresses,
];

let passed = 0;
for (const fn of tests) {
  fn();
  passed += 1;
  console.log(`OK ${fn.name}`);
}
console.log(`\n${passed}/${tests.length} field extraction tests passed`);
