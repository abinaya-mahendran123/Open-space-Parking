const { buildPreprocessedBuffers } = require('../ocr_preprocess');
const {
  mergeExtracted,
  scoreOcrExtraction,
} = require('./field_extraction');

const OCR_PSMS = ['6', '4'];
const GOOD_EXTRACTION_SCORE = 75;

let _workerEng = null;
let _workerTam = null;
let _workerHin = null;

async function getWorkerEng() {
  if (!_workerEng) {
    const { createWorker } = require('tesseract.js');
    _workerEng = await createWorker('eng');
  }
  return _workerEng;
}

async function getWorkerTam() {
  if (!_workerTam) {
    const { createWorker } = require('tesseract.js');
    _workerTam = await createWorker('eng+tam');
  }
  return _workerTam;
}

async function getWorkerHin() {
  if (!_workerHin) {
    const { createWorker } = require('tesseract.js');
    _workerHin = await createWorker('eng+hin');
  }
  return _workerHin;
}

async function recognizeWithPsm(worker, buffer, psm) {
  await worker.setParameters({
    tessedit_pageseg_mode: psm,
    preserve_interword_spaces: '1',
  });
  const { data } = await worker.recognize(buffer);
  return { text: data.text || '', confidence: data.confidence || 0 };
}

/**
 * Tesseract fallback OCR — English fast path; deep retry adds PSM 4.
 */
async function recognizeMultiPass(buffer, { deep = false, idType = 'aadhaar' } = {}) {
  const worker = await getWorkerEng();
  const preprocessed = await buildPreprocessedBuffers(buffer, { deep });
  const psms = deep ? OCR_PSMS : ['6'];
  const runs = [];

  let bestFields = {
    fullName: '',
    address: '',
    phone: '',
    governmentIdNumber: '',
  };
  let bestFieldScore = -1;

  for (const item of preprocessed) {
    for (const psm of psms) {
      try {
        const result = await recognizeWithPsm(worker, item.buffer, psm);
        runs.push({ ...result, variant: item.variant, psm });
        const fields = mergeExtracted(result.text, '', idType, { preserveUnicode: false });
        const score = scoreOcrExtraction(fields) + result.confidence / 10;
        if (score > bestFieldScore) {
          bestFieldScore = score;
          bestFields = fields;
        }
        if (scoreOcrExtraction(bestFields) >= GOOD_EXTRACTION_SCORE) {
          return {
            engine: 'tesseract',
            text: result.text || '',
            confidence: result.confidence || 0,
            passes: runs.length,
            bestFields,
            fieldScore: bestFieldScore,
          };
        }
      } catch (_) {
        // keep going
      }
    }
  }

  runs.sort((a, b) => b.confidence - a.confidence);
  const mergedText = runs
    .slice(0, 4)
    .map((r) => r.text.trim())
    .filter(Boolean)
    .join('\n');
  const best = runs[0] || { text: '', confidence: 0 };

  return {
    engine: 'tesseract',
    text: mergedText || best.text,
    confidence: best.confidence,
    passes: runs.length,
    bestFields,
    fieldScore: bestFieldScore,
  };
}

/**
 * Targeted Tesseract pass for specific missing fields (e.g. phone).
 */
async function recognizeForMissingFields(buffer, idType, existingFields) {
  const missingPhone = !existingFields.phone;
  const missingAddress = !existingFields.address || existingFields.address.length < 20;
  const missingName = !existingFields.fullName;
  const missingId = !existingFields.governmentIdNumber;

  if (!missingPhone && !missingAddress && !missingName && !missingId) {
    return null;
  }

  const deep = missingAddress || missingName || missingId;
  return recognizeMultiPass(buffer, { deep, idType });
}

async function terminateWorkers() {
  for (const workerRef of [_workerEng, _workerTam, _workerHin]) {
    if (!workerRef) continue;
    try {
      await workerRef.terminate();
    } catch (_) {}
  }
  _workerEng = null;
  _workerTam = null;
  _workerHin = null;
}

module.exports = {
  recognizeMultiPass,
  recognizeForMissingFields,
  terminateWorkers,
  GOOD_EXTRACTION_SCORE,
  OCR_PSMS,
};
