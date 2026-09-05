/**
 * Phase 1 — cross-check submitted ticket data against OCR / DigiLocker extractions.
 * No DigiLocker required; works with manual uploads + Aadhaar owner details.
 */

function normalizeName(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function nameSimilarity(a, b) {
  const left = normalizeName(a);
  const right = normalizeName(b);
  if (!left || !right) return 0;
  if (left === right) return 1;
  if (left.includes(right) || right.includes(left)) return 0.88;

  const compactLeft = left.replace(/\s/g, '');
  const compactRight = right.replace(/\s/g, '');
  if (compactLeft === compactRight) return 0.95;
  if (compactLeft.includes(compactRight) || compactRight.includes(compactLeft)) {
    return 0.85;
  }

  const wordsA = left.split(' ').filter((w) => w.length >= 2);
  const wordsB = new Set(right.split(' ').filter((w) => w.length >= 2));
  if (wordsA.length === 0 || wordsB.size === 0) return 0;

  let overlap = 0;
  for (const word of wordsA) {
    if (wordsB.has(word)) overlap += 1;
  }
  return overlap / Math.max(wordsA.length, wordsB.size);
}

function normalizeTokens(value) {
  const stop = new Set([
    'the',
    'and',
    'of',
    'in',
    'at',
    'to',
    'street',
    'st',
    'road',
    'rd',
    'nagar',
    'tamil',
    'nadu',
    'india',
    'pin',
    'code',
  ]);
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length >= 3 && !stop.has(t));
}

function addressOverlap(a, b) {
  const ta = new Set(normalizeTokens(a));
  const tb = new Set(normalizeTokens(b));
  if (ta.size === 0 || tb.size === 0) return 0;
  let overlap = 0;
  for (const token of ta) {
    if (tb.has(token)) overlap += 1;
  }
  return overlap / Math.min(ta.size, tb.size);
}

function makeCheck({ id, label, pass, severity = 'normal', expected = '', found = '', score = null, note = '' }) {
  return {
    id,
    label,
    pass: Boolean(pass),
    severity,
    expected: expected || undefined,
    found: found || undefined,
    score: score == null ? undefined : Number(score.toFixed(2)),
    note: note || undefined,
  };
}

function buildVerificationReport({
  ownerDetails = {},
  documents = {},
  landDetails = {},
  extracted = {},
}) {
  const checks = [];
  const ownerName = String(ownerDetails.fullName || '').trim();
  const ownerAddress = String(ownerDetails.address || '').trim();
  const landAddress = String(landDetails.landAddress || '').trim();
  const areaSqFt = Number(landDetails.areaSqFt || 0);

  const manualComplete =
    Boolean(documents.propertyDocumentPath) &&
    Boolean(documents.pattaPath) &&
    Boolean(documents.propertyTaxPath) &&
    Boolean(documents.municipalityCertificatePath);

  const govIdPresent = Boolean(
    documents.governmentIdPath || ownerDetails.governmentIdFrontPath,
  );

  checks.push(
    makeCheck({
      id: 'required_docs',
      label: 'All 4 property documents uploaded',
      pass: manualComplete || documents.digilockerVerified,
      severity: 'critical',
      note: documents.digilockerVerified ? 'DigiLocker verified' : undefined,
    }),
  );

  checks.push(
    makeCheck({
      id: 'gov_id',
      label: 'Government ID (Aadhaar) uploaded',
      pass: govIdPresent,
      severity: 'critical',
    }),
  );

  checks.push(
    makeCheck({
      id: 'owner_name_present',
      label: 'Owner name provided on form',
      pass: ownerName.length >= 3,
      severity: 'critical',
      found: ownerName,
    }),
  );

  const pattaName = extracted.ownerName || documents.digilockerOwnerName || '';
  const nameScore = nameSimilarity(ownerName, pattaName);
  checks.push(
    makeCheck({
      id: 'owner_name_match',
      label: 'Owner name matches property documents',
      pass: nameScore >= 0.55 || (documents.digilockerVerified && pattaName.length >= 3),
      severity: 'critical',
      expected: ownerName,
      found: pattaName || '(not found in OCR)',
      score: nameScore,
    }),
  );

  const surveyNo = extracted.surveyNumber || documents.digilockerSurveyNumber || '';
  checks.push(
    makeCheck({
      id: 'survey_number',
      label: 'Survey / SF number found on Patta',
      pass: surveyNo.length >= 3,
      severity: 'normal',
      found: surveyNo || '(not detected)',
    }),
  );

  const addrScore = addressOverlap(ownerAddress, landAddress);
  checks.push(
    makeCheck({
      id: 'address_land_match',
      label: 'Aadhaar address overlaps land location',
      pass: addrScore >= 0.25 || (!ownerAddress && landAddress.length >= 8),
      severity: 'normal',
      expected: ownerAddress.slice(0, 80) || undefined,
      found: landAddress.slice(0, 80) || undefined,
      score: addrScore,
    }),
  );

  checks.push(
    makeCheck({
      id: 'land_area',
      label: 'Land area (sq ft) provided',
      pass: areaSqFt > 0,
      severity: 'normal',
      found: areaSqFt > 0 ? `${areaSqFt} sq ft` : undefined,
    }),
  );

  const district = extracted.district || documents.digilockerDistrict || '';
  const districtHint = `${ownerAddress} ${landAddress}`.toLowerCase();
  const districtPass =
    !district ||
    districtHint.includes(String(district).toLowerCase()) ||
    documents.digilockerVerified;
  checks.push(
    makeCheck({
      id: 'district',
      label: 'District consistent with addresses',
      pass: districtPass,
      severity: 'normal',
      found: district || '(not detected)',
    }),
  );

  if (documents.digilockerVerified) {
    checks.push(
      makeCheck({
        id: 'digilocker',
        label: 'DigiLocker government verification',
        pass: true,
        severity: 'normal',
        note: documents.digilockerDocumentType || 'Verified document',
      }),
    );
  }

  const scored = checks.filter((c) => c.score != null);
  const overallScore =
    scored.length > 0
      ? scored.reduce((sum, c) => sum + c.score, 0) / scored.length
      : checks.filter((c) => c.pass).length / Math.max(checks.length, 1);

  const critical = checks.filter((c) => c.severity === 'critical');
  const criticalPass = critical.every((c) => c.pass);
  const passCount = checks.filter((c) => c.pass).length;

  return {
    status: 'complete',
    overallScore: Number(overallScore.toFixed(2)),
    passCount,
    totalChecks: checks.length,
    readyForQuickApproval: criticalPass && passCount >= Math.ceil(checks.length * 0.75),
    checks,
    extracted: {
      ownerName: extracted.ownerName || '',
      surveyNumber: extracted.surveyNumber || '',
      district: extracted.district || '',
      village: extracted.village || '',
      sources: extracted.sources || [],
    },
  };
}

module.exports = {
  buildVerificationReport,
  nameSimilarity,
  addressOverlap,
  normalizeName,
};
