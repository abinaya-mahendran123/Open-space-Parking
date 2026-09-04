const {
  mergeExtracted,
  mergeBestFields,
  scoreOcrExtraction,
  scoreNameCandidate,
  isValidAadhaarChecksum,
  isAadhaarBackSide,
  pickBetterAddress,
  mergeAddresses,
  appendMissingPin,
} = require('./field_extraction');
const { paddleResultToText, averageConfidence } = require('./paddleocr_text');

const GOOD_EXTRACTION_SCORE = 75;
const WEAK_EXTRACTION_SCORE = 55;

function fieldsFromEngineText(frontText, backText, idType, { preserveUnicode = false } = {}) {
  return mergeExtracted(frontText, backText, idType, { preserveUnicode });
}

function fieldsFromPaddle(paddleFront, paddleBack, idType) {
  const frontText = paddleResultToText(paddleFront);
  const backText = paddleResultToText(paddleBack);
  const fields = fieldsFromEngineText(frontText, backText, idType, {
    preserveUnicode: true,
  });
  return {
    fields,
    frontText,
    backText,
    confidence: Math.max(
      averageConfidence(paddleFront),
      averageConfidence(paddleBack),
    ),
    engine: 'paddleocr',
  };
}

function mergeEngineResults(primary, fallback, idType) {
  const primaryFields = primary.fields || primary;
  const fallbackFields = fallback.fields || fallback.bestFields || fallback;

  const primaryNameScore = scoreNameCandidate(primaryFields.fullName);
  const fallbackNameScore = scoreNameCandidate(fallbackFields.fullName);
  const primaryName = primaryNameScore >= 12 ? primaryFields.fullName : '';
  const fallbackName = fallbackNameScore >= 12 ? fallbackFields.fullName : '';

  return {
    fullName:
      primaryNameScore >= fallbackNameScore
        ? primaryName || fallbackName || ''
        : fallbackName || primaryName || '',
    address:
      mergeAddresses(primaryFields.address, fallbackFields.address) ||
      primaryFields.address ||
      fallbackFields.address ||
      '',
    phone: primaryFields.phone || fallbackFields.phone || '',
    governmentIdNumber:
      [primaryFields.governmentIdNumber, fallbackFields.governmentIdNumber].find(
        (n) => isValidAadhaarChecksum(n),
      ) ||
      primaryFields.governmentIdNumber ||
      fallbackFields.governmentIdNumber ||
      '',
    detectedSide: primaryFields.detectedSide || fallbackFields.detectedSide,
    uploadLayout: primaryFields.uploadLayout || fallbackFields.uploadLayout,
    ocrAccepted: primaryFields.ocrAccepted ?? fallbackFields.ocrAccepted,
  };
}

function mergeFrontBackFieldBundles(frontBundle, backBundle) {
  const merged = mergeBestFields(frontBundle.fields, backBundle.fields);
  return {
    ...merged,
    rawText: `${frontBundle.frontText || ''}\n${backBundle.backText || frontBundle.backText || ''}`.slice(
      0,
      4000,
    ),
    ocrConfidence: Math.max(frontBundle.confidence || 0, backBundle.confidence || 0),
    ocrPasses: (frontBundle.passes || 1) + (backBundle.passes || 1),
  };
}

function enrollmentAddressReady(fields) {
  const rawText = fields.rawText || '';
  const address = appendMissingPin(fields.address || '', rawText);
  if (!address || address.length < 20) return false;
  if (/\b\d{6}\b/.test(address)) return true;
  return (
    address.length >= 40 &&
    /\b(street|nagar|puram|madurai|tamil)\b/i.test(address) &&
    /\b\d{6}\b/.test(rawText)
  );
}

function needsTesseractFallback(fields, idType, options = {}) {
  const uploadLayout = String(options.uploadLayout || fields.uploadLayout || '');
  if (uploadLayout === 'enrollment_sheet') {
    const uid = String(fields.governmentIdNumber || fields.aadhaarNumber || '').replace(
      /\D/g,
      '',
    );
    const nameOk = Boolean(fields.fullName) && scoreNameCandidate(fields.fullName) >= 12;
    const missing = {
      uid: uid.length !== 12 || !isValidAadhaarChecksum(uid),
      phone: !fields.phone,
      address: !enrollmentAddressReady(fields),
      name: !nameOk,
    };
    if (missing.uid || missing.phone || missing.address || missing.name) {
      return {
        needed: true,
        reason: 'enrollment_missing_fields',
        missing: {
          name: missing.name,
          address: missing.address,
          id: missing.uid,
          phone: missing.phone,
        },
        targeted: true,
      };
    }
    return { needed: false, reason: 'enrollment_structured' };
  }

  const isBack = idType === 'aadhaar' && isAadhaarBackSide(fields);
  const missing = {
    name: !isBack && !fields.fullName,
    address: !fields.address || fields.address.length < 20,
    id:
      idType === 'aadhaar' &&
      (!fields.governmentIdNumber || !isValidAadhaarChecksum(fields.governmentIdNumber)),
    phone: !fields.phone,
  };

  // Back-side crops often lack name/UID — don't force slow Tesseract when address+phone are present.
  if (
    idType === 'aadhaar' &&
    isBack &&
    fields.phone &&
    fields.address &&
    fields.address.length >= 20
  ) {
    return { needed: false, reason: 'back_sufficient' };
  }

  if (missing.phone) {
    return { needed: true, reason: 'missing_phone', missing, targeted: true };
  }

  const score = scoreOcrExtraction(fields);
  if (score >= GOOD_EXTRACTION_SCORE) return { needed: false, reason: 'strong' };

  if (score < WEAK_EXTRACTION_SCORE) {
    return { needed: true, reason: 'weak_score', missing };
  }

  if (missing.name || missing.address || missing.id) {
    return { needed: true, reason: 'missing_critical', missing };
  }

  return { needed: false, reason: 'acceptable' };
}

function buildOcrMetadata(enginesUsed, passes) {
  const unique = [...new Set(enginesUsed.filter(Boolean))];
  const ocrEngine = unique.length === 1 ? unique[0] : unique.join('+');
  return {
    extractionSource: 'ocr',
    ocrEngine,
    ocrPasses: passes,
  };
}

module.exports = {
  fieldsFromEngineText,
  fieldsFromPaddle,
  mergeEngineResults,
  mergeFrontBackFieldBundles,
  needsTesseractFallback,
  buildOcrMetadata,
  GOOD_EXTRACTION_SCORE,
  WEAK_EXTRACTION_SCORE,
};
