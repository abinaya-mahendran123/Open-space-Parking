/**
 * Extract structured fields from property document OCR text (Patta, tax, etc.).
 */

function cleanText(text) {
  return String(text || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractSurveyNumber(text) {
  const body = String(text || '');
  const patterns = [
    /\b(?:survey|s\.?\s*no|sy\.?\s*no|sf\.?\s*no)\s*[:\-]?\s*([0-9]+[\/\-][0-9A-Za-z\/\-]+)/i,
    /\b([0-9]+[\/\-][0-9A-Za-z]+)\b/,
    /\bs\.?\s*f\.?\s*no\.?\s*[:\-]?\s*([0-9A-Za-z\/\-]+)/i,
  ];
  for (const re of patterns) {
    const m = body.match(re);
    if (m?.[1] && m[1].length >= 3) return m[1].trim();
  }
  return '';
}

function extractOwnerName(text) {
  const body = String(text || '');
  const labeled = [
    body.match(/(?:owner|name|pattadar|land\s*holder)\s*[:\-]\s*([A-Za-z][A-Za-z\s.]{2,40})/i)?.[1],
    body.match(/(?:s\s*\/\s*o|d\s*\/\s*o|w\s*\/\s*o|c\s*\/\s*o)\s*[:\-]?\s*([A-Za-z][A-Za-z\s.]{2,40})/i)?.[1],
  ].find(Boolean);
  if (labeled) return cleanText(labeled.replace(/[,;].*$/, ''));

  const lines = body.split(/\n+/).map((l) => l.trim()).filter(Boolean);
  for (const line of lines.slice(0, 12)) {
    if (/^(owner|name|survey|district|village|patta|tamil)/i.test(line)) continue;
    if (/^[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,3}$/.test(line) && line.length >= 4) {
      return line;
    }
  }
  return '';
}

function extractDistrict(text) {
  const body = String(text || '');
  return (
    body.match(/\bdistrict\s*[:\-]?\s*([A-Za-z\s]{3,30})/i)?.[1]?.trim() ||
    body.match(/\b(?:madurai|chennai|coimbatore|namakkal|virudhunagar|salem|trichy|tiruchirappalli)\b/i)?.[0] ||
    ''
  );
}

function extractVillage(text) {
  const body = String(text || '');
  return (
    body.match(/\b(?:village|vtc|po)\s*[:\-]?\s*([A-Za-z][A-Za-z\s]{2,30})/i)?.[1]?.trim() ||
    body.match(/\b([A-Za-z]+(?:puram|patti|nagar))\b/i)?.[1] ||
    ''
  );
}

function extractPropertyFieldsFromText(text) {
  const raw = String(text || '');
  return {
    ownerName: extractOwnerName(raw),
    surveyNumber: extractSurveyNumber(raw),
    district: extractDistrict(raw),
    village: extractVillage(raw),
    rawTextSample: raw.slice(0, 500),
  };
}

const DOC_TYPE_LABELS = {
  patta: 'Patta',
  property_document: 'Property Document',
  property_tax: 'Property Tax',
  municipality_certificate: 'Municipality Certificate',
};

const DOC_TYPE_HINTS = {
  patta: [
    /\bpatta\b/i,
    /\bpattadar\b/i,
    /\bchitta\b/i,
    /\badangal\b/i,
    /\bsurvey\s*(no|number|n[o0])\b/i,
    /\bs\.?\s*f\.?\s*no\b/i,
    /\bland\s*revenue\b/i,
    /\brevenue\s*department\b/i,
    /\bsettlement\b/i,
    /\bfmb\b/i,
    /\btaluk\b/i,
    /\bvillage\b/i,
  ],
  property_document: [
    /\bsale\s*deed\b/i,
    /\bconveyance\b/i,
    /\btitle\s*deed\b/i,
    /\bregistration\b/i,
    /\bregistrar\b/i,
    /\bstamp\s*duty\b/i,
    /\bschedule\s*of\s*property\b/i,
    /\bpurchaser\b/i,
    /\bvendor\b/i,
    /\bexecuted\b/i,
    /\bconsideration\b/i,
    /\bdocument\s*no\b/i,
  ],
  property_tax: [
    /\bproperty\s*tax\b/i,
    /\bhouse\s*tax\b/i,
    /\btax\s*receipt\b/i,
    /\bassessment\b/i,
    /\bdemand\s*notice\b/i,
    /\barrears\b/i,
    /\bhalf\s*year\b/i,
    /\btax\s*paid\b/i,
    /\bassessment\s*no\b/i,
    /\bward\s*no\b/i,
    /\bproperty\s*tax\s*receipt\b/i,
  ],
  municipality_certificate: [
    /\bmunicipality\b/i,
    /\bcorporation\b/i,
    /\bpanchayat\b/i,
    /\blocal\s*body\b/i,
    /\bcommissioner\b/i,
    /\bcertificate\b/i,
    /\bnoc\b/i,
    /\bno\s*objection\b/i,
    /\bapproved\b/i,
    /\btown\s*panchayat\b/i,
    /\bgreater\s*chennai\b/i,
    /\bmadurai\s*corporation\b/i,
  ],
};

const WRONG_ID_HINTS = [
  { re: /\baadhaar\b|\buidai\b|\bunique\s*identification\b/i, label: 'Aadhaar card' },
  { re: /\bpermanent\s*account\b|\bincome\s*tax\b|\bpan\b/i, label: 'PAN card' },
  { re: /\bdriving\s*licen[cs]e\b|\bdl\s*no\b/i, label: 'driving licence' },
  { re: /\belection\s*commission\b|\bvoter\s*id\b|\bepic\b/i, label: 'voter ID' },
];

const GOVERNMENT_ID_HINTS = [
  /\baadhaar\b/i,
  /\buidai\b/i,
  /\bunique\s*identification\b/i,
  /\bgovernment\s*of\s*india\b/i,
  /\bvid\b/i,
  /\bdob\b|\bdate\s*of\s*birth\b/i,
  /\bmale\b|\bfemale\b/i,
  /\b\d{4}\s*\d{4}\s*\d{4}\b/,
];

function scoreDocumentType(text, type) {
  const hints = DOC_TYPE_HINTS[type] || [];
  let score = 0;
  for (const re of hints) {
    if (re.test(text)) score += 1;
  }
  return score;
}

function matchPercentFromScore({ accepted, rawScore, hintCount, wrongType = false }) {
  const maxRelevant = Math.max(3, Math.ceil((hintCount || 4) * 0.45));
  const ratio = Math.min(1, (Number(rawScore) || 0) / maxRelevant);
  if (accepted) {
    return Math.min(100, Math.max(68, Math.round(60 + ratio * 40)));
  }
  if (wrongType) {
    return Math.min(28, Math.max(4, Math.round(ratio * 28)));
  }
  return Math.min(48, Math.max(0, Math.round(ratio * 55)));
}

/**
 * Classify OCR text as a government ID (Aadhaar / similar).
 */
function classifyGovernmentId(text) {
  const body = String(text || '');
  const compact = body.replace(/\s+/g, ' ').trim();
  if (compact.replace(/[^a-zA-Z0-9]/g, '').length < 12) {
    return {
      accepted: false,
      expectedType: 'government_id',
      detectedType: '',
      score: 0,
      matchPercent: 0,
      message: 'Could not read this Government ID clearly. Upload a clear Aadhaar photo.',
    };
  }

  let hits = 0;
  for (const re of GOVERNMENT_ID_HINTS) {
    if (re.test(body)) hits += 1;
  }

  // Strong property-doc signals mean the wrong file was uploaded.
  const propertyHits = Math.max(
    scoreDocumentType(body, 'patta'),
    scoreDocumentType(body, 'property_document'),
    scoreDocumentType(body, 'property_tax'),
  );

  if (propertyHits >= 3 && hits < 2) {
    return {
      accepted: false,
      expectedType: 'government_id',
      detectedType: 'property document',
      score: hits,
      matchPercent: matchPercentFromScore({
        accepted: false,
        rawScore: hits,
        hintCount: GOVERNMENT_ID_HINTS.length,
        wrongType: true,
      }),
      message: 'This looks like a property document, not a Government ID (Aadhaar).',
    };
  }

  const accepted = hits >= 2;
  return {
    accepted,
    expectedType: 'government_id',
    detectedType: accepted ? 'government_id' : '',
    score: hits,
    matchPercent: matchPercentFromScore({
      accepted,
      rawScore: hits,
      hintCount: GOVERNMENT_ID_HINTS.length,
      wrongType: false,
    }),
    message: accepted
      ? 'Government ID verified.'
      : 'This does not look like a clear Government ID (Aadhaar).',
  };
}

/**
 * Classify OCR text against the expected land-owner document type.
 * Returns { accepted, expectedType, detectedType, score, matchPercent, message }.
 */
function classifyPropertyDocument(text, expectedType) {
  const expected = String(expectedType || '').trim();
  const body = String(text || '');
  const compact = body.replace(/\s+/g, ' ').trim();
  const expectedLabel = DOC_TYPE_LABELS[expected] || expected || 'required document';
  const hintCount = (DOC_TYPE_HINTS[expected] || []).length;

  if (compact.replace(/[^a-zA-Z0-9]/g, '').length < 18) {
    return {
      accepted: false,
      expectedType: expected,
      detectedType: '',
      score: 0,
      matchPercent: 0,
      message:
        `Could not read this file clearly. Please upload a clear photo or PDF of your ${expectedLabel}.`,
    };
  }

  for (const wrong of WRONG_ID_HINTS) {
    if (wrong.re.test(body)) {
      return {
        accepted: false,
        expectedType: expected,
        detectedType: wrong.label,
        score: 0,
        matchPercent: 8,
        message: `This looks like a ${wrong.label}. Please upload your ${expectedLabel} instead.`,
      };
    }
  }

  const scores = Object.fromEntries(
    Object.keys(DOC_TYPE_HINTS).map((type) => [type, scoreDocumentType(body, type)]),
  );
  const ranked = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  const [topType, topScore] = ranked[0] || ['', 0];
  const expectedScore = scores[expected] || 0;
  const secondScore = ranked[1]?.[1] || 0;

  const withPercent = (result, { wrongType = false } = {}) => ({
    ...result,
    matchPercent: matchPercentFromScore({
      accepted: result.accepted,
      rawScore: result.score,
      hintCount,
      wrongType,
    }),
  });

  if (expectedScore >= 2 && expectedScore >= topScore) {
    return withPercent({
      accepted: true,
      expectedType: expected,
      detectedType: expected,
      score: expectedScore,
      message: `${expectedLabel} verified.`,
    });
  }

  if (expectedScore >= 2 && expectedScore + 1 >= topScore) {
    return withPercent({
      accepted: true,
      expectedType: expected,
      detectedType: expected,
      score: expectedScore,
      message: `${expectedLabel} verified.`,
    });
  }

  if (topScore >= 2 && topType !== expected) {
    const detectedLabel = DOC_TYPE_LABELS[topType] || topType;
    return withPercent(
      {
        accepted: false,
        expectedType: expected,
        detectedType: topType,
        score: topScore,
        message:
          `This looks like a ${detectedLabel}, not a ${expectedLabel}. Please upload the correct ${expectedLabel}.`,
      },
      { wrongType: true },
    );
  }

  if (expectedScore < 2 || expectedScore < secondScore) {
    return withPercent({
      accepted: false,
      expectedType: expected,
      detectedType: topType || '',
      score: expectedScore,
      message:
        `This does not look like a ${expectedLabel}. Please upload a clear photo or PDF of your ${expectedLabel}.`,
    });
  }

  return withPercent({
    accepted: true,
    expectedType: expected,
    detectedType: expected,
    score: expectedScore,
    message: `${expectedLabel} verified.`,
  });
}

function mergePropertyFields(parts) {
  const merged = {
    ownerName: '',
    surveyNumber: '',
    district: '',
    village: '',
    sources: [],
  };
  for (const part of parts) {
    if (!part) continue;
    merged.sources.push(part.source || 'unknown');
    if (!merged.ownerName && part.ownerName) merged.ownerName = part.ownerName;
    if (!merged.surveyNumber && part.surveyNumber) merged.surveyNumber = part.surveyNumber;
    if (!merged.district && part.district) merged.district = part.district;
    if (!merged.village && part.village) merged.village = part.village;
  }
  return merged;
}

module.exports = {
  extractPropertyFieldsFromText,
  mergePropertyFields,
  extractSurveyNumber,
  extractOwnerName,
  extractDistrict,
  classifyPropertyDocument,
  classifyGovernmentId,
  DOC_TYPE_LABELS,
};
