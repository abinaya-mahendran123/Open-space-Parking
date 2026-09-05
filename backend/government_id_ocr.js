const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');

const { prepareAadhaarUpload } = require('./ocr_preprocess');
const { extractAadhaarFromQr } = require('./aadhaar_qr');
const {
  ID_TYPES,
  mergeWithPreference,
  mergeExtracted,
  isCompleteAadhaarQr,
  isUsefulPartialQr,
  assertAadhaarDocument,
  finalizeAadhaarExtraction,
} = require('./ocr/field_extraction');
const { runOcrPipeline } = require('./ocr/ocr_pipeline');
const { terminateWorkers } = require('./ocr/tesseract_engine');
const { logOcr } = require('./ocr/ocr_logging');

const localUploadDir = path.join(__dirname, 'uploads');

function decodeDataUrlOrBase64(value) {
  const text = String(value || '').trim();
  if (!text) return null;
  const dataUrl = text.match(/^data:[^;]+;base64,(.+)$/i);
  const b64 = dataUrl ? dataUrl[1] : text;
  try {
    const buf = Buffer.from(b64, 'base64');
    return buf.length > 32 ? buf : null;
  } catch (_) {
    return null;
  }
}

/** Prefer reading /uploads/* from disk — Render restarts wipe remote URLs mid-session. */
function readLocalUploadIfPresent(url) {
  try {
    const parsed = new URL(String(url || ''));
    const match = parsed.pathname.match(/\/uploads\/([^/]+)$/i);
    if (!match) return null;
    const fileName = path.basename(decodeURIComponent(match[1]));
    if (!fileName || fileName === '.' || fileName === '..') return null;
    const filePath = path.join(localUploadDir, fileName);
    if (!fs.existsSync(filePath)) return null;
    return fs.readFileSync(filePath);
  } catch (_) {
    return null;
  }
}

function fetchBuffer(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 5) {
      reject(new Error('Too many redirects while fetching image.'));
      return;
    }

    const local = readLocalUploadIfPresent(url);
    if (local) {
      resolve(local);
      return;
    }

    const client = url.startsWith('https') ? https : http;
    client
      .get(url, (res) => {
        if (
          res.statusCode >= 300 &&
          res.statusCode < 400 &&
          res.headers.location
        ) {
          fetchBuffer(res.headers.location, redirects + 1)
            .then(resolve)
            .catch(reject);
          return;
        }

        if (res.statusCode !== 200) {
          reject(new Error(`Could not download image (HTTP ${res.statusCode}).`));
          return;
        }

        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => resolve(Buffer.concat(chunks)));
        res.on('error', reject);
      })
      .on('error', reject);
  });
}

function isPdfBuffer(buffer) {
  return (
    Buffer.isBuffer(buffer) &&
    buffer.length >= 4 &&
    buffer.slice(0, 4).toString('utf8') === '%PDF'
  );
}

/**
 * Build Cloudinary delivery URLs that render PDF page 1 as PNG/JPG.
 * Sharp on Render usually cannot rasterize PDFs (no Poppler), so this is required.
 */
function cloudinaryPdfRenderCandidates(url) {
  const text = String(url || '').trim();
  if (!text.includes('res.cloudinary.com') || !text.includes('/upload/')) {
    return [];
  }

  const candidates = [];
  const add = (value) => {
    const u = String(value || '').trim();
    if (u && !candidates.includes(u)) candidates.push(u);
  };

  const asImage = text
    .replace('/raw/upload/', '/image/upload/')
    .replace('/auto/upload/', '/image/upload/');

  const match = asImage.match(
    /^(https?:\/\/res\.cloudinary\.com\/[^/]+\/image\/upload\/)(.+)$/i,
  );
  if (!match) {
    add(asImage.replace('/upload/', '/upload/f_png,pg_1,q_auto,w_2000/'));
    return candidates;
  }

  const prefix = match[1];
  let rest = match[2];

  const segments = rest.split('/');
  const versionIdx = segments.findIndex((part) => /^v\d+$/.test(part));
  if (versionIdx > 0) {
    rest = segments.slice(versionIdx).join('/');
  } else if (
    segments.length > 1 &&
    (segments[0].includes(',') || /^(f_|pg_|q_|w_|c_|fl_)/.test(segments[0]))
  ) {
    rest = segments.slice(1).join('/');
  }

  const transforms = [
    'f_png,pg_1,q_auto,w_2000',
    'pg_1,f_png,q_auto,w_2000',
    'f_jpg,pg_1,q_auto,w_2000',
    'pg_1/f_png',
  ];
  for (const transform of transforms) {
    add(`${prefix}${transform}/${rest}`);
  }

  add(asImage.replace('/upload/', '/upload/f_png,pg_1,q_auto,w_2000/'));
  return candidates;
}

function cloudinaryPdfPageImageUrl(url) {
  return cloudinaryPdfRenderCandidates(url)[0] || null;
}

function looksLikeRasterImage(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 8) return false;
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return true;
  }
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return true;
  }
  if (
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return true;
  }
  return false;
}

async function extractTextFromPdfBuffer(buffer) {
  const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(buffer),
    disableWorker: true,
    useSystemFonts: true,
  });
  const pdf = await loadingTask.promise;
  const maxPages = Math.min(pdf.numPages || 1, 3);
  const chunks = [];

  for (let pageNum = 1; pageNum <= maxPages; pageNum += 1) {
    const page = await pdf.getPage(pageNum);
    const content = await page.getTextContent();
    const line = [];
    for (const item of content.items || []) {
      const str = String(item?.str || '').trim();
      if (str) line.push(str);
    }
    if (line.length) {
      chunks.push(line.join(' '));
      chunks.push(line.join('\n'));
    }
  }

  return chunks.join('\n');
}

/**
 * Returns a raster image buffer for OCR, or null when PDF cannot be converted.
 */
async function bufferToOcrImage(buffer, sourceUrl) {
  if (!isPdfBuffer(buffer)) return buffer;

  const candidates = cloudinaryPdfRenderCandidates(sourceUrl);
  for (const pageUrl of candidates) {
    try {
      const rendered = await fetchBuffer(pageUrl);
      if (looksLikeRasterImage(rendered)) {
        logOcr('pdf_render=cloudinary');
        return rendered;
      }
    } catch (error) {
      logOcr('pdf_render_failed', { reason: error?.message || String(error) });
    }
  }

  try {
    const sharp = require('sharp');
    return await sharp(buffer, { density: 220, page: 0 }).png().toBuffer();
  } catch (error) {
    logOcr('pdf_render_failed', { reason: error?.message || String(error) });
    return null;
  }
}

async function fetchImageBufferForOcr(url, inlineBase64) {
  const inline = decodeDataUrlOrBase64(inlineBase64);
  if (inline) {
    return bufferToOcrImage(inline, url || '');
  }
  const buffer = await fetchBuffer(url);
  return bufferToOcrImage(buffer, url);
}

async function tryExtractFromPdfUrl(url, idType) {
  try {
    const raw = await fetchBuffer(url);
    if (!isPdfBuffer(raw)) return null;
    const pdfText = await extractTextFromPdfBuffer(raw);
    if (!pdfText || pdfText.replace(/\s+/g, '').length < 12) return null;

    const extracted = mergeExtracted(pdfText, pdfText, idType);
    extracted.rawText = pdfText.slice(0, 4000);
    extracted.extractionSource = 'pdf_text';
    if (idType === 'aadhaar' && extracted.governmentIdNumber) {
      extracted.aadhaarNumber = extracted.governmentIdNumber;
    }

    const useful =
      (extracted.fullName && extracted.fullName.length >= 3) ||
      (extracted.governmentIdNumber &&
        String(extracted.governmentIdNumber).replace(/\D/g, '').length === 12) ||
      (extracted.address && extracted.address.length >= 8);

    return useful ? extracted : null;
  } catch (error) {
    logOcr('pdf_text_failed', { reason: error?.message || String(error) });
    return null;
  }
}

async function extractGovernmentIdDetails({
  frontUrl,
  backUrl,
  idType,
  frontBase64,
  backBase64,
}) {
  if (!ID_TYPES.has(idType)) {
    throw new Error('Unsupported government ID type.');
  }
  if (!frontUrl && !frontBase64) {
    throw new Error('Image URL or image data is required.');
  }

  const started = Date.now();

  // Prefer inline bytes (survives Render redeploys). Skip URL PDF probe when present.
  const pdfTextExtracted =
    frontUrl && !frontBase64
      ? await tryExtractFromPdfUrl(frontUrl, idType)
      : null;
  if (
    pdfTextExtracted &&
    pdfTextExtracted.fullName &&
    pdfTextExtracted.governmentIdNumber &&
    pdfTextExtracted.address
  ) {
    assertAadhaarDocument(pdfTextExtracted);
    return pdfTextExtracted;
  }

  const sameUrl =
    (!frontUrl && !backUrl) ||
    (frontUrl && backUrl && frontUrl === backUrl) ||
    (!backUrl && !!frontUrl) ||
    (!!frontBase64 && (!backBase64 || backBase64 === frontBase64));
  let frontBuffer;
  let backBuffer;
  let extraBackBuffer = null;
  let fullRawBuffer = null;
  let uploadLayout = 'single';
  let sameBuffer = true;
  let addressCropBuffer = null;
  let cardBackBuffer = null;
  let qrExtracted = null;

  try {
    if (sameUrl) {
      fullRawBuffer = await fetchImageBufferForOcr(frontUrl, frontBase64);
      if (!fullRawBuffer) {
        if (pdfTextExtracted) return pdfTextExtracted;
        throw new Error(
          'Could not read this Aadhaar PDF automatically. Upload a clear PNG/JPG photo of the card (or a screenshot of the PDF), then tap Re-scan.',
        );
      }
      const [prepared, qrFromImage] = await Promise.all([
        prepareAadhaarUpload(fullRawBuffer),
        idType === 'aadhaar'
          ? extractAadhaarFromQr(fullRawBuffer).catch((error) => {
              logOcr('qr_failed', { reason: error?.message || String(error) });
              return null;
            })
          : Promise.resolve(null),
      ]);
      frontBuffer = prepared.frontBuffer;
      backBuffer = prepared.backBuffer;
      sameBuffer = prepared.sameBuffer;
      uploadLayout = prepared.layout;
      addressCropBuffer = prepared.addressCropBuffer || null;
      cardBackBuffer = prepared.cardBackBuffer || null;
      if (qrFromImage && isCompleteAadhaarQr(qrFromImage)) {
        logOcr('qrResult=complete', { totalTimeMs: Date.now() - started });
        return {
          ...qrFromImage,
          aadhaarNumber:
            qrFromImage.aadhaarNumber || qrFromImage.governmentIdNumber || '',
          extractionSource: 'aadhaar_qr',
        };
      }
      if (idType === 'aadhaar' && qrFromImage) {
        qrExtracted = qrFromImage;
      }
      logOcr('upload_layout', {
        layout: uploadLayout,
        sameBuffer,
        hasAddressCrop: !!addressCropBuffer,
        hasCardBackCrop: !!cardBackBuffer,
      });
    } else {
      const [frontConverted, backConverted] = await Promise.all([
        fetchImageBufferForOcr(frontUrl, frontBase64),
        fetchImageBufferForOcr(backUrl || frontUrl, backBase64 || frontBase64),
      ]);
      if (!frontConverted) {
        if (pdfTextExtracted) return pdfTextExtracted;
        throw new Error(
          'Could not read this Aadhaar PDF automatically. Upload a clear PNG/JPG photo of the card (or a screenshot of the PDF), then tap Re-scan.',
        );
      }
      frontBuffer = frontConverted;
      backBuffer = backConverted || frontConverted;
      sameBuffer = frontBuffer === backBuffer;
      uploadLayout = sameBuffer ? 'single' : 'dual_horizontal';
    }
  } catch (error) {
    const message = error?.message || String(error);
    if (message.includes('HTTP 404')) {
      throw new Error(
        'Uploaded image is missing on the server (common after a redeploy). Tap Replace, upload the Aadhaar again, then Re-scan.',
      );
    }
    throw error;
  }

  const sameBufferFinal = frontBuffer === backBuffer;
  let ocrFrontBuffer = frontBuffer;
  let ocrBackBuffer = backBuffer;
  let supplementaryBuffers = cardBackBuffer
    ? [cardBackBuffer]
    : [addressCropBuffer].filter(Boolean);
  if (uploadLayout === 'enrollment_sheet' && addressCropBuffer) {
    ocrBackBuffer = addressCropBuffer;
    supplementaryBuffers = cardBackBuffer ? [cardBackBuffer] : [];
  }

  const pipelineArgs = {
    frontBuffer: ocrFrontBuffer,
    backBuffer: ocrBackBuffer,
    extraBackBuffer: supplementaryBuffers[0] || null,
    supplementaryBuffers,
    sameBuffer: sameBufferFinal,
    uploadLayout,
    idType,
    uidScanBuffer: fullRawBuffer || frontBuffer,
  };

  let extracted;
  if (idType === 'aadhaar' && !qrExtracted) {
    const qrBuffer = fullRawBuffer || frontBuffer;
    const [qrSecond, pipelineResult] = await Promise.all([
      extractAadhaarFromQr(qrBuffer).catch((error) => {
        logOcr('qr_failed', { reason: error?.message || String(error) });
        return null;
      }),
      runOcrPipeline(pipelineArgs),
    ]);
    qrExtracted = qrSecond;
    extracted = pipelineResult;
    if (isCompleteAadhaarQr(qrExtracted)) {
      logOcr('qrResult=complete', { totalTimeMs: Date.now() - started });
      return {
        ...qrExtracted,
        aadhaarNumber:
          qrExtracted.aadhaarNumber || qrExtracted.governmentIdNumber || '',
        extractionSource: 'aadhaar_qr',
      };
    }
    logOcr('qrResult=partial_or_none');
  } else {
    extracted = await runOcrPipeline(pipelineArgs);
  }

  if (qrExtracted) {
    extracted = mergeWithPreference(qrExtracted, extracted, {
      detectedSide: extracted.detectedSide,
      uploadLayout: extracted.uploadLayout || uploadLayout,
    });
    if (!extracted.extractionSource) {
      extracted.extractionSource = 'ocr';
    }
  }
  if (pdfTextExtracted) {
    extracted = mergeWithPreference(pdfTextExtracted, extracted, {
      detectedSide: extracted.detectedSide,
      uploadLayout: extracted.uploadLayout || uploadLayout,
    });
  }

  if (idType === 'aadhaar' && extracted.governmentIdNumber) {
    extracted.aadhaarNumber = extracted.governmentIdNumber;
  }

  if (idType === 'aadhaar') {
    extracted = finalizeAadhaarExtraction(extracted, uploadLayout);
    assertAadhaarDocument(extracted);
  }

  logOcr('extract_complete', {
    totalTimeMs: Date.now() - started,
    extractionSource: extracted.extractionSource,
    ocrEngine: extracted.ocrEngine,
    uploadLayout: extracted.uploadLayout || uploadLayout,
    detectedSide: extracted.detectedSide,
    ocrAccepted: extracted.ocrAccepted,
  });

  return extracted;
}

module.exports = {
  extractGovernmentIdDetails,
  terminateWorkers,
  cloudinaryPdfRenderCandidates,
  cloudinaryPdfPageImageUrl,
  bufferToOcrImage,
  fetchBuffer,
  isPdfBuffer,
  mergeExtracted,
  mergeWithPreference,
};
