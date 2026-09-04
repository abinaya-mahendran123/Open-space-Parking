const { preprocessVariant, bufferMeetsMinOcrSize } = require('../ocr_preprocess');
const { recognizeBuffer: paddleRecognize } = require('./paddleocr_client');
const {
  recognizeMultiPass,
  recognizeForMissingFields,
  recognizeAadhaarNumber,
} = require('./tesseract_engine');
const {
  fieldsFromPaddle,
  mergeEngineResults,
  needsTesseractFallback,
  buildOcrMetadata,
} = require('./ocr_merge');
const {
  mergeExtracted,
  mergeExtractedForLayout,
  mergeExtractedForEnrollmentSheet,
  mergeExtractedForSingleSide,
  mergeBestFields,
  mergeAddresses,
  sanitizeNameForDetectedSide,
  titleCaseName,
  classifyAadhaarSide,
  isValidAadhaarChecksum,
  isMisclassifiedEnrollmentSheet,
  extractPhone,
  extractIdNumber,
} = require('./field_extraction');
const { paddleResultToText, averageConfidence } = require('./paddleocr_text');
const { logOcr } = require('./ocr_logging');

function mergeOcrFields(frontText, backText, idType, uploadLayout, options = {}) {
  if (uploadLayout) {
    return mergeExtractedForLayout(frontText, backText, idType, uploadLayout, options);
  }
  return mergeExtracted(frontText, backText, idType, options);
}

function configuredPaddleLangs() {
  const langs = (process.env.PADDLEOCR_LANGS || 'en')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
  return langs.length ? langs : ['en'];
}

function effectiveOcrLangs(preferred) {
  const allowed = new Set(configuredPaddleLangs());
  const picked = (preferred || []).filter((lang) => allowed.has(lang));
  return picked.length ? picked : configuredPaddleLangs();
}

function primaryOcrLangs() {
  const raw = process.env.PADDLEOCR_PRIMARY_LANGS || process.env.PADDLEOCR_LANGS || 'en';
  return effectiveOcrLangs(
    raw
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean),
  );
}

function addressOcrLangs() {
  const raw = process.env.PADDLEOCR_ADDRESS_LANGS || 'en';
  return effectiveOcrLangs(
    raw
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean),
  );
}

function needsContrastRetryForFields(fields, idType) {
  if (idType !== 'aadhaar') return false;
  const addr = String(fields.address || '');
  const uid = String(fields.governmentIdNumber || '').replace(/\D/g, '');
  if (addr.length >= 20 && /\b\d{6}\b/.test(addr)) return false;
  if (
    uid.length === 12 &&
    isValidAadhaarChecksum(uid) &&
    addr.length >= 12 &&
    (/\b\d{6}\b/.test(addr) ||
      /\b(street|nagar|puram|district|state|tamil)/i.test(addr))
  ) {
    return false;
  }
  return true;
}

async function runPaddleOnBuffer(buffer, idType, options = {}) {
  const { allowContrastRetry = true, langs = primaryOcrLangs() } = options;
  if (process.env.SKIP_PADDLEOCR_WORKER === '1') {
    return null;
  }
  if (!(await bufferMeetsMinOcrSize(buffer))) {
    logOcr('paddle_skip', { reason: 'buffer_too_small' });
    return null;
  }
  try {
    const standard = await preprocessVariant(buffer, 'standard', options.preprocess);
    const paddleResult = await paddleRecognize(standard, { langs });
    let frontText = paddleResultToText(paddleResult);
    let fields = mergeExtracted(frontText, '', idType, { preserveUnicode: true });
    let passes = 1;
    let confidence = averageConfidence(paddleResult);

    if (allowContrastRetry && needsContrastRetryForFields(fields, idType)) {
      const contrast = await preprocessVariant(buffer, 'contrast', options.preprocess);
      const retryResult = await paddleRecognize(contrast, { langs });
      const retryText = paddleResultToText(retryResult);
      const retryFields = mergeExtracted(retryText, '', idType, {
        preserveUnicode: true,
      });
      fields = mergeEngineResults(retryFields, fields, idType);
      frontText = `${retryText}\n${frontText}`.trim();
      passes = 2;
      confidence = Math.max(confidence, averageConfidence(retryResult));
    }

    return {
      fields,
      frontText,
      backText: '',
      confidence,
      passes,
      engine: 'paddleocr',
    };
  } catch (error) {
    logOcr('paddle_failed', { reason: error.message });
    return null;
  }
}

async function runTesseractOnly(
  frontBuffer,
  backBuffer,
  extraBackBuffer,
  sameBuffer,
  idType,
  uploadLayout,
) {
  logOcr('tesseract_start', { sameBuffer, idType, uploadLayout });
  let passes = 0;
  let digitUid = '';

  // UID first — most common miss, and must finish before gateway timeout.
  if (idType === 'aadhaar') {
    logOcr('tesseract_aadhaar_digits');
    digitUid =
      (await recognizeAadhaarNumber(frontBuffer)) ||
      (!sameBuffer ? await recognizeAadhaarNumber(backBuffer) : '') ||
      (extraBackBuffer ? await recognizeAadhaarNumber(extraBackBuffer) : '');
    if (digitUid) passes += 1;
  }

  // One fast full-page pass for name / phone / address.
  let frontTess;
  let backTess;
  if (sameBuffer) {
    frontTess = await recognizeMultiPass(frontBuffer, { deep: false, idType });
    backTess = frontTess;
  } else {
    [frontTess, backTess] = await Promise.all([
      recognizeMultiPass(frontBuffer, { deep: false, idType }),
      recognizeMultiPass(backBuffer, { deep: false, idType }),
    ]);
  }

  let backTextForMerge = backTess.text;
  if (extraBackBuffer) {
    const cropTess = await recognizeMultiPass(extraBackBuffer, { deep: false, idType });
    passes += cropTess.passes || 0;
    backTextForMerge = `${cropTess.text}\n${backTess.text}`.trim();
  }

  const combined = mergeOcrFields(frontTess.text, backTextForMerge, idType, uploadLayout, {
    preserveUnicode: false,
  });
  passes += (frontTess.passes || 0) + (sameBuffer ? 0 : backTess.passes || 0);

  const pageUid = String(combined.governmentIdNumber || '').replace(/\D/g, '');
  if (idType === 'aadhaar' && digitUid && !/^\d{12}$/.test(pageUid)) {
    combined.governmentIdNumber = digitUid;
  }
  if (idType === 'aadhaar' && combined.governmentIdNumber) {
    combined.aadhaarNumber = combined.governmentIdNumber;
  }

  return {
    ...combined,
    ocrConfidence: Math.max(frontTess.confidence || 0, backTess.confidence || 0),
    ocrPasses: passes,
    ...buildOcrMetadata(['tesseract'], passes),
  };
}

async function runPaddleFrontBack(
  frontBuffer,
  backBuffer,
  idType,
  sameBuffer,
  uploadLayout,
  supplementaryBuffers = [],
) {
  const qualityPreprocess = { maxWidth: 1280, minUpscale: 1000, jpegQuality: 88 };
  const fastCrop = { maxWidth: 1120, minUpscale: 900, jpegQuality: 85 };
  const primaryLangs = primaryOcrLangs();
  const addressLangs = addressOcrLangs();
  const isEnrollment = uploadLayout === 'enrollment_sheet';

  // Address column only — full frame includes disclaimer text that corrupts extraction.
  if (uploadLayout === 'back_columns') {
    const bundle = await runPaddleOnBuffer(backBuffer, idType, {
      allowContrastRetry: true,
      preprocess: qualityPreprocess,
      langs: addressLangs,
    });
    if (!bundle) return null;
    const merged = mergeOcrFields('', bundle.frontText, idType, uploadLayout, {
      preserveUnicode: true,
    });
    return {
      front: bundle,
      back: bundle,
      combined: merged,
      ocrConfidence: bundle.confidence || 0,
      ocrPasses: bundle.passes || 1,
    };
  }

  if (sameBuffer && supplementaryBuffers.length === 0) {
    const bundle = await runPaddleOnBuffer(frontBuffer, idType);
    if (!bundle) return null;
    const merged = mergeOcrFields(
      bundle.frontText,
      bundle.frontText,
      idType,
      uploadLayout,
      { preserveUnicode: true },
    );
    return {
      front: bundle,
      back: bundle,
      combined: merged,
      ocrConfidence: bundle.confidence || 0,
      ocrPasses: bundle.passes || 1,
    };
  }

  const jobs = [];
  if (sameBuffer) {
    jobs.push({
      role: 'full',
      buffer: frontBuffer,
      allowContrastRetry: !isEnrollment,
      preprocess: qualityPreprocess,
      langs: primaryLangs,
    });
    supplementaryBuffers.forEach((buffer, index) => {
      jobs.push({
        role: `extra${index}`,
        buffer,
        allowContrastRetry: false,
        preprocess: fastCrop,
        langs: addressLangs,
      });
    });
  } else if (isEnrollment) {
    // Two fast crops: full left column (letter + address) + card-back compressed line.
    jobs.push({
      role: 'back',
      buffer: backBuffer,
      allowContrastRetry: false,
      preprocess: fastCrop,
      langs: addressLangs,
    });
    supplementaryBuffers.forEach((buffer, index) => {
      jobs.push({
        role: `extra${index}`,
        buffer,
        allowContrastRetry: false,
        preprocess: fastCrop,
        langs: addressLangs,
      });
    });
  } else {
    jobs.push(
      {
        role: 'front',
        buffer: frontBuffer,
        allowContrastRetry: true,
        preprocess: qualityPreprocess,
        langs: primaryLangs,
      },
      {
        role: 'back',
        buffer: backBuffer,
        allowContrastRetry: true,
        preprocess: qualityPreprocess,
        langs: primaryLangs,
      },
    );
    supplementaryBuffers.forEach((buffer, index) => {
      jobs.push({
        role: `extra${index}`,
        buffer,
        allowContrastRetry: false,
        preprocess: fastCrop,
        langs: addressLangs,
      });
    });
  }

  const started = Date.now();
  const settled = await Promise.all(
    jobs.map(async (job) => ({
      role: job.role,
      bundle: await runPaddleOnBuffer(job.buffer, idType, {
        allowContrastRetry: job.allowContrastRetry,
        preprocess: job.preprocess,
        langs: job.langs,
      }),
    })),
  );
  logOcr('paddle_parallel_complete', {
    buffers: jobs.length,
    elapsedMs: Date.now() - started,
    primaryLangs,
    addressLangs,
  });

  const byRole = Object.fromEntries(settled.map((row) => [row.role, row.bundle]));

  let frontText = '';
  let backText = '';
  let front = null;
  let back = null;

  if (sameBuffer) {
    const fullText = byRole.full?.frontText || '';
    const addressTexts = supplementaryBuffers
      .map((_, index) => byRole[`extra${index}`]?.frontText || '')
      .filter(Boolean);
    const addressText = addressTexts.join('\n').trim();
    const side = classifyAadhaarSide(addressText || fullText);
    if (side === 'back' && addressText) {
      frontText = '';
      backText = addressText;
    } else if (side === 'front') {
      frontText = fullText || addressText;
      backText = addressText;
    } else {
      frontText = fullText;
      backText = addressText || fullText;
    }
    front = byRole.full || byRole.extra0;
    back = byRole.extra0 || byRole.full;
  } else {
    front = byRole.front;
    back = byRole.back;
    frontText = front?.frontText || '';
    const extraTexts = supplementaryBuffers
      .map((_, index) => byRole[`extra${index}`]?.frontText || '')
      .filter(Boolean);
    backText = [back?.frontText || '', ...extraTexts].filter(Boolean).join('\n').trim();
  }

  if (!front && !back) return null;

  const fields = mergeOcrFields(frontText, backText, idType, uploadLayout, {
    preserveUnicode: true,
  });

  let pooledFields = { ...fields };
  const allOcrText = settled
    .map((row) => row.bundle?.frontText || '')
    .filter(Boolean)
    .join('\n');

  if (uploadLayout === 'enrollment_sheet') {
    const letterText = back?.frontText || '';
    const cardBackText = byRole.extra0?.frontText || '';
    if (isMisclassifiedEnrollmentSheet(letterText, cardBackText, frontText)) {
      const combinedBack = [letterText, cardBackText, frontText].filter(Boolean).join('\n');
      const mismerged = mergeExtractedForSingleSide('', combinedBack, idType, 'back', {
        preserveUnicode: true,
      });
      pooledFields = {
        ...mismerged,
        uploadLayout: 'single_back',
        phone: mismerged.phone || fields.phone,
        governmentIdNumber:
          mismerged.governmentIdNumber || fields.governmentIdNumber,
      };
    } else {
      const enrollmentMerged = mergeExtractedForEnrollmentSheet(
        '',
        letterText,
        cardBackText,
        idType,
        { preserveUnicode: true },
      );
      pooledFields = {
        ...enrollmentMerged,
        phone: enrollmentMerged.phone || fields.phone,
        governmentIdNumber:
          enrollmentMerged.governmentIdNumber || fields.governmentIdNumber,
      };
    }
    if (!pooledFields.phone) {
      pooledFields.phone = extractPhone(allOcrText, idType);
    }
    if (!pooledFields.governmentIdNumber) {
      const uid = extractIdNumber(allOcrText, idType);
      if (uid) pooledFields.governmentIdNumber = uid;
    }
  } else {
    pooledFields = mergeBestFields(front?.fields || {}, back?.fields || {});
    for (const row of settled) {
      if (row.role.startsWith('extra') && row.bundle?.fields) {
        pooledFields = mergeBestFields(pooledFields, row.bundle.fields);
      }
    }
    pooledFields = {
      ...pooledFields,
      fullName: fields.fullName || pooledFields.fullName,
      address: fields.address || pooledFields.address,
      phone: fields.phone || pooledFields.phone,
      governmentIdNumber:
        fields.governmentIdNumber || pooledFields.governmentIdNumber,
    };
  }

  const totalPasses = settled.reduce((sum, row) => sum + (row.bundle?.passes || 0), 0);

  return {
    front: front || back,
    back: back || front,
    combined: {
      fullName: titleCaseName(
        sanitizeNameForDetectedSide(
          pooledFields.fullName || fields.fullName,
          fields.detectedSide,
          fields.rawText || `${frontText}\n${backText}`,
        ),
      ),
      address: pooledFields.address || fields.address,
      phone: pooledFields.phone || fields.phone,
      governmentIdNumber:
        pooledFields.governmentIdNumber || fields.governmentIdNumber,
      rawText: fields.rawText || `${frontText}\n${backText}`.slice(0, 4000),
      uploadLayout: fields.uploadLayout,
      detectedSide: fields.detectedSide,
    },
    ocrConfidence: Math.max(
      ...settled.map((row) => row.bundle?.confidence || 0),
      0,
    ),
    ocrPasses: totalPasses,
  };
}

async function applyTesseractFallback({
  fields,
  frontBuffer,
  backBuffer,
  extraBackBuffer,
  supplementaryBuffers = [],
  sameBuffer,
  idType,
  fallbackPlan,
  uploadLayout,
  uidScanBuffer = null,
}) {
  const enginesUsed = ['paddleocr'];
  let merged = { ...fields };
  let passes = merged.ocrPasses || 1;
  let confidence = merged.ocrConfidence || 0;
  const extraBuffers =
    supplementaryBuffers.length > 0
      ? supplementaryBuffers
      : extraBackBuffer
        ? [extraBackBuffer]
        : [];

  const runTesseractSide = async (buffer) => {
    if (fallbackPlan.targeted) {
      return recognizeForMissingFields(buffer, idType, merged);
    }
    return recognizeMultiPass(buffer, {
      deep: false,
      idType,
    });
  };

  let frontTess = null;
  let backTess = null;

  if (uploadLayout === 'enrollment_sheet') {
    const uidBuffer = uidScanBuffer || frontBuffer;
    const targets = [];
    if (fallbackPlan.missing?.phone || fallbackPlan.missing?.address) {
      targets.push(runTesseractSide(backBuffer));
    }
    if (fallbackPlan.missing?.id && uidBuffer && uidBuffer !== backBuffer) {
      targets.push(runTesseractSide(uidBuffer));
    } else if (fallbackPlan.missing?.id) {
      targets.push(runTesseractSide(backBuffer));
    }
    if (targets.length > 0) {
      const results = await Promise.all(targets);
      backTess = results[0];
      frontTess = results[1] || null;
    }
  } else if (sameBuffer) {
    frontTess = await runTesseractSide(frontBuffer);
    backTess = frontTess;
  } else {
    const targets = [];
    if (fallbackPlan.missing?.phone || fallbackPlan.missing?.address) {
      targets.push(runTesseractSide(backBuffer));
    }
    if (fallbackPlan.missing?.name || fallbackPlan.missing?.id) {
      targets.push(runTesseractSide(frontBuffer));
    }
    if (targets.length === 0) {
      [frontTess, backTess] = await Promise.all([
        runTesseractSide(frontBuffer),
        runTesseractSide(backBuffer),
      ]);
    } else {
      const results = await Promise.all(targets);
      frontTess = results[0];
      backTess = results[1] || results[0];
    }
  }

  if (frontTess || backTess) {
    enginesUsed.push('tesseract');
    const tessFields = mergeOcrFields(
      frontTess?.text || '',
      backTess?.text || '',
      idType,
      uploadLayout,
      { preserveUnicode: false },
    );
    merged = mergeEngineResults(merged, tessFields, idType);
    merged.rawText = `${merged.rawText || ''}\n${frontTess?.text || ''}\n${backTess?.text || ''}`.slice(
      0,
      4000,
    );
    passes += (frontTess?.passes || 0) + (sameBuffer ? 0 : backTess?.passes || 0);
    confidence = Math.max(
      confidence,
      frontTess?.confidence || 0,
      backTess?.confidence || 0,
    );
  }

  if (extraBuffers.length > 0 && !fallbackPlan.targeted) {
    for (const buffer of extraBuffers) {
      if (buffer === backBuffer) continue;
      const extraTess = await recognizeMultiPass(buffer, { deep: false, idType });
      enginesUsed.push('tesseract');
      const extraFields = mergeOcrFields(
        merged.rawText || '',
        extraTess.text,
        idType,
        uploadLayout,
        { preserveUnicode: false },
      );
      merged = mergeEngineResults(merged, extraFields, idType);
      passes += extraTess.passes || 0;
      if (merged.address && merged.address.length >= 40 && /\b\d{6}\b/.test(merged.address)) {
        break;
      }
    }
  }

  return {
    ...merged,
    ...buildOcrMetadata(enginesUsed, passes),
    ocrConfidence: confidence,
  };
}

async function runOcrPipeline({
  frontBuffer,
  backBuffer,
  extraBackBuffer,
  supplementaryBuffers = [],
  sameBuffer,
  uploadLayout = 'single',
  idType,
  uidScanBuffer = null,
}) {
  const started = Date.now();
  const skipPaddle = process.env.SKIP_PADDLEOCR_WORKER === '1';
  const extraBuffers =
    supplementaryBuffers.length > 0
      ? supplementaryBuffers
      : extraBackBuffer
        ? [extraBackBuffer]
        : [];
  logOcr('pipeline_start', { idType, sameBuffer, uploadLayout, skipPaddle });

  const uidBuffer = uidScanBuffer || frontBuffer;
  const digitScanPromise =
    idType === 'aadhaar'
      ? Promise.all([
          recognizeAadhaarNumber(uidBuffer),
          uidBuffer !== frontBuffer ? recognizeAadhaarNumber(frontBuffer) : Promise.resolve(''),
          uidBuffer !== backBuffer ? recognizeAadhaarNumber(backBuffer) : Promise.resolve(''),
          extraBuffers[0] ? recognizeAadhaarNumber(extraBuffers[0]) : Promise.resolve(''),
        ]).then((rows) => rows.find((uid) => uid && isValidAadhaarChecksum(uid)) || '')
      : Promise.resolve('');

  const [paddle, earlyDigitUid] = await Promise.all([
    skipPaddle
      ? Promise.resolve(null)
      : runPaddleFrontBack(
          frontBuffer,
          backBuffer,
          idType,
          sameBuffer,
          uploadLayout,
          extraBuffers,
        ),
    digitScanPromise,
  ]);

  let result;
  if (!paddle) {
    logOcr('fallback=tesseract', {
      reason: skipPaddle ? 'paddle_disabled' : 'paddle_unavailable',
    });
    result = await runTesseractOnly(
      frontBuffer,
      backBuffer,
      extraBuffers[0] || null,
      sameBuffer,
      idType,
      uploadLayout,
    );
  } else {
    result = {
      ...paddle.combined,
      ocrConfidence: paddle.ocrConfidence,
      ocrPasses: paddle.ocrPasses,
      ...buildOcrMetadata(['paddleocr'], paddle.ocrPasses || 1),
    };

    const fallbackPlan = needsTesseractFallback(result, idType, { uploadLayout });
    if (fallbackPlan.needed) {
      logOcr('fallback=tesseract', { reason: fallbackPlan.reason });
      result = await applyTesseractFallback({
        fields: result,
        frontBuffer,
        backBuffer,
        extraBackBuffer: extraBuffers[0] || null,
        supplementaryBuffers: extraBuffers,
        sameBuffer,
        idType,
        fallbackPlan,
        uploadLayout,
        uidScanBuffer: uidBuffer,
      });
    }
  }

  logOcr('pipeline_complete', {
    totalTimeMs: Date.now() - started,
    ocrEngine: result.ocrEngine,
  });

  if (idType === 'aadhaar' && result && !result.phone) {
    const pooledPhone = extractPhone(result.rawText || '', idType);
    if (pooledPhone) result.phone = pooledPhone;
  }

  if (
    idType === 'aadhaar' &&
    result &&
    (!result.governmentIdNumber || !isValidAadhaarChecksum(result.governmentIdNumber))
  ) {
    const digitUid =
      earlyDigitUid ||
      (await recognizeAadhaarNumber(uidBuffer)) ||
      (await recognizeAadhaarNumber(frontBuffer)) ||
      (await recognizeAadhaarNumber(backBuffer)) ||
      (extraBuffers[0] ? await recognizeAadhaarNumber(extraBuffers[0]) : '');
    if (digitUid && isValidAadhaarChecksum(digitUid)) {
      result.governmentIdNumber = digitUid;
      result.aadhaarNumber = digitUid;
    }
  }

  return result;
}

module.exports = { runOcrPipeline };
