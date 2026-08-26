const { preprocessVariant } = require('../ocr_preprocess');
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
  mergeBestFields,
} = require('./field_extraction');
const { paddleResultToText, averageConfidence } = require('./paddleocr_text');
const { logOcr } = require('./ocr_logging');

async function runPaddleOnBuffer(buffer, idType) {
  if (process.env.SKIP_PADDLEOCR_WORKER === '1') {
    return null;
  }
  try {
    const standard = await preprocessVariant(buffer, 'standard');
    let paddleResult = await paddleRecognize(standard);
    let frontText = paddleResultToText(paddleResult);
    let fields = mergeExtracted(frontText, '', idType, { preserveUnicode: true });
    let passes = 1;
    let confidence = averageConfidence(paddleResult);

    const check = needsTesseractFallback(fields, idType);
    if (check.needed && check.reason !== 'missing_phone') {
      const contrast = await preprocessVariant(buffer, 'contrast');
      const retryResult = await paddleRecognize(contrast);
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

async function runTesseractOnly(frontBuffer, backBuffer, extraBackBuffer, sameBuffer, idType) {
  logOcr('tesseract_start', { sameBuffer, idType });
  // Fast path first — deep OCR often exceeds Render's gateway timeout (HTTP 502).
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

  let combined = mergeExtracted(frontTess.text, backTess.text, idType, {
    preserveUnicode: false,
  });
  let passes = (frontTess.passes || 0) + (sameBuffer ? 0 : backTess.passes || 0);

  if (extraBackBuffer && (!combined.address || combined.address.length < 20)) {
    const extraTess = await recognizeMultiPass(extraBackBuffer, { deep: false, idType });
    combined = mergeExtracted(
      frontTess.text,
      `${backTess.text}\n${extraTess.text}`,
      idType,
      { preserveUnicode: false },
    );
    passes += extraTess.passes || 0;
  }

  // Dedicated Aadhaar UID pass when full-page OCR missed the 12 digits.
  if (
    idType === 'aadhaar' &&
    (!combined.governmentIdNumber ||
      !String(combined.governmentIdNumber).replace(/\D/g, '').match(/^\d{12}$/))
  ) {
    logOcr('tesseract_aadhaar_digits');
    const uid =
      (await recognizeAadhaarNumber(frontBuffer)) ||
      (!sameBuffer ? await recognizeAadhaarNumber(backBuffer) : '') ||
      (extraBackBuffer ? await recognizeAadhaarNumber(extraBackBuffer) : '');
    if (uid) {
      combined.governmentIdNumber = uid;
      combined.aadhaarNumber = uid;
      passes += 1;
    }
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

async function runPaddleFrontBack(frontBuffer, backBuffer, idType, sameBuffer) {
  if (sameBuffer) {
    const bundle = await runPaddleOnBuffer(frontBuffer, idType);
    if (!bundle) return null;
    return {
      front: bundle,
      back: bundle,
      combined: bundle.fields,
    };
  }

  const [front, back] = await Promise.all([
    runPaddleOnBuffer(frontBuffer, idType),
    runPaddleOnBuffer(backBuffer, idType),
  ]);

  if (!front && !back) return null;

  const frontText = front?.frontText || '';
  const backText = back?.frontText || '';
  const fields = mergeExtracted(frontText, backText, idType, { preserveUnicode: true });
  const fieldBest = mergeBestFields(front?.fields || {}, back?.fields || {});

  return {
    front: front || back,
    back: back || front,
    combined: {
      fullName: fieldBest.fullName || fields.fullName,
      address: fieldBest.address || fields.address,
      phone: fieldBest.phone || fields.phone,
      governmentIdNumber:
        fieldBest.governmentIdNumber || fields.governmentIdNumber,
      rawText: `${frontText}\n${backText}`.slice(0, 4000),
    },
    ocrConfidence: Math.max(front?.confidence || 0, back?.confidence || 0),
    ocrPasses: (front?.passes || 0) + (back?.passes || 0),
  };
}

async function applyTesseractFallback({
  fields,
  frontBuffer,
  backBuffer,
  extraBackBuffer,
  sameBuffer,
  idType,
  fallbackPlan,
}) {
  const enginesUsed = ['paddleocr'];
  let merged = { ...fields };
  let passes = merged.ocrPasses || 1;
  let confidence = merged.ocrConfidence || 0;

  const runTesseractSide = async (buffer) => {
    if (fallbackPlan.targeted) {
      return recognizeForMissingFields(buffer, idType, merged);
    }
    return recognizeMultiPass(buffer, {
      deep: fallbackPlan.reason === 'weak_score',
      idType,
    });
  };

  let frontTess = null;
  let backTess = null;

  if (sameBuffer) {
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
    const tessFields = mergeExtracted(
      frontTess?.text || '',
      backTess?.text || '',
      idType,
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

  if (
    extraBackBuffer &&
    (!merged.address || merged.address.length < 20) &&
    !fallbackPlan.targeted
  ) {
    const extraTess = await recognizeMultiPass(extraBackBuffer, { deep: true, idType });
    enginesUsed.push('tesseract');
    const extraFields = mergeExtracted('', extraTess.text, idType, { preserveUnicode: false });
    merged = mergeEngineResults(merged, extraFields, idType);
    passes += extraTess.passes || 0;
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
  sameBuffer,
  idType,
}) {
  const started = Date.now();
  const skipPaddle = process.env.SKIP_PADDLEOCR_WORKER === '1';
  logOcr('pipeline_start', { idType, sameBuffer, skipPaddle });

  const paddle = skipPaddle
    ? null
    : await runPaddleFrontBack(frontBuffer, backBuffer, idType, sameBuffer);

  let result;
  if (!paddle) {
    logOcr('fallback=tesseract', {
      reason: skipPaddle ? 'paddle_disabled' : 'paddle_unavailable',
    });
    result = await runTesseractOnly(
      frontBuffer,
      backBuffer,
      extraBackBuffer,
      sameBuffer,
      idType,
    );
  } else {
    result = {
      ...paddle.combined,
      ocrConfidence: paddle.ocrConfidence,
      ocrPasses: paddle.ocrPasses,
      ...buildOcrMetadata(['paddleocr'], paddle.ocrPasses || 1),
    };

    const fallbackPlan = needsTesseractFallback(result, idType);
    if (fallbackPlan.needed) {
      logOcr('fallback=tesseract', { reason: fallbackPlan.reason });
      result = await applyTesseractFallback({
        fields: result,
        frontBuffer,
        backBuffer,
        extraBackBuffer,
        sameBuffer,
        idType,
        fallbackPlan,
      });
    }
  }

  logOcr('pipeline_complete', {
    totalTimeMs: Date.now() - started,
    ocrEngine: result.ocrEngine,
  });

  return result;
}

module.exports = { runOcrPipeline };
