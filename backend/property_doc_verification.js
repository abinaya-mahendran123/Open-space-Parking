/**
 * Phase 1 — OCR property documents and build admin cross-check report.
 */

const { fetchBuffer, bufferToOcrImage, isPdfBuffer } = require('./government_id_ocr');
const { recognizeBuffer } = require('./ocr/paddleocr_client');
const { paddleResultToText } = require('./ocr/paddleocr_text');
const {
  extractPropertyFieldsFromText,
  mergePropertyFields,
  classifyPropertyDocument,
  classifyGovernmentId,
} = require('./ocr/property_doc_extraction');
const { buildVerificationReport } = require('./document_verification');
const { logOcr } = require('./ocr/ocr_logging');

const TICKET_DOC_SLOTS = [
  {
    key: 'governmentIdPath',
    id: 'government_id',
    label: 'Government ID',
    kind: 'government_id',
  },
  {
    key: 'propertyDocumentPath',
    id: 'property_document',
    label: 'Property Document',
    kind: 'property_document',
  },
  {
    key: 'pattaPath',
    id: 'patta',
    label: 'Patta',
    kind: 'patta',
  },
  {
    key: 'propertyTaxPath',
    id: 'property_tax',
    label: 'Property Tax',
    kind: 'property_tax',
  },
  {
    key: 'municipalityCertificatePath',
    id: 'municipality_certificate',
    label: 'Local municipality verified Document',
    kind: 'municipality_certificate',
  },
];

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

async function extractTextFromPdfBuffer(buffer) {
  const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  const loadingTask = pdfjs.getDocument({
    data: new Uint8Array(buffer),
    disableWorker: true,
    useSystemFonts: true,
  });
  const pdf = await loadingTask.promise;
  const maxPages = Math.min(pdf.numPages || 1, 2);
  const chunks = [];
  for (let pageNum = 1; pageNum <= maxPages; pageNum += 1) {
    const page = await pdf.getPage(pageNum);
    const content = await page.getTextContent();
    const line = [];
    for (const item of content.items || []) {
      const str = String(item?.str || '').trim();
      if (str) line.push(str);
    }
    if (line.length) chunks.push(line.join('\n'));
  }
  return chunks.join('\n');
}

async function ocrDocumentUrl(url, source) {
  if (!url) return { source, text: '', fields: extractPropertyFieldsFromText('') };

  try {
    const raw = await fetchBuffer(url);
    let text = '';

    if (isPdfBuffer(raw)) {
      text = await extractTextFromPdfBuffer(raw);
    }

    if (!text || text.replace(/\s+/g, '').length < 20) {
      const imageBuffer = await bufferToOcrImage(raw, url);
      if (imageBuffer) {
        const paddle = await recognizeBuffer(imageBuffer, { langs: ['en'] });
        text = paddleResultToText(paddle);
      }
    }

    const fields = extractPropertyFieldsFromText(text);
    return { source, text: text.slice(0, 4000), fields };
  } catch (err) {
    logOcr('property_doc_ocr_failed', { source, reason: err?.message || String(err) });
    return { source, text: '', fields: extractPropertyFieldsFromText(''), error: err?.message };
  }
}

/**
 * Verify one uploaded land document matches the expected type (patta, tax, etc.).
 */
async function verifyPropertyDocumentUpload({
  url,
  expectedType,
  imageBase64,
}) {
  const expected = String(expectedType || '').trim();
  if (!DOC_TYPE_LABELS[expected]) {
    const err = new Error(
      'Unsupported document type. Upload Patta, Property Document, Property Tax, or Municipality Certificate.',
    );
    err.code = 'UNSUPPORTED_DOC_TYPE';
    throw err;
  }
  if (!url && !imageBase64) {
    const err = new Error('Document URL or image data is required.');
    err.code = 'MISSING_DOC';
    throw err;
  }

  let text = '';
  let error;

  try {
    const inline = decodeDataUrlOrBase64(imageBase64);
    if (inline) {
      if (isPdfBuffer(inline)) {
        text = await extractTextFromPdfBuffer(inline);
      }
      if (!text || text.replace(/\s+/g, '').length < 20) {
        const imageBuffer = await bufferToOcrImage(inline, url || '');
        if (imageBuffer) {
          const paddle = await recognizeBuffer(imageBuffer, { langs: ['en'] });
          text = paddleResultToText(paddle);
        }
      }
    }

    if ((!text || text.replace(/\s+/g, '').length < 20) && url) {
      const ocr = await ocrDocumentUrl(url, expected);
      text = ocr.text || '';
      error = ocr.error;
    }
  } catch (err) {
    error = err?.message || String(err);
    logOcr('property_doc_upload_verify_failed', {
      expectedType: expected,
      reason: error,
    });
  }

  const classification = classifyPropertyDocument(text, expected);
  const fields = extractPropertyFieldsFromText(text);

  if (!classification.accepted) {
    const err = new Error(classification.message);
    err.code = 'WRONG_DOCUMENT';
    err.details = {
      ...classification,
      fields,
      error,
    };
    throw err;
  }

  return {
    accepted: true,
    expectedType: expected,
    detectedType: classification.detectedType,
    score: classification.score,
    message: classification.message,
    fields,
  };
}

async function verifyTicketDocuments({ ownerDetails, documents, landDetails }) {
  const slots = TICKET_DOC_SLOTS.map((slot) => ({
    ...slot,
    url: String(documents?.[slot.key] || '').trim() || null,
  }));

  const ocrResults = await Promise.all(
    slots.map(async (slot) => {
      if (!slot.url) {
        return {
          ...slot,
          text: '',
          fields: extractPropertyFieldsFromText(''),
          error: null,
        };
      }
      const ocr = await ocrDocumentUrl(slot.url, slot.id);
      return {
        ...slot,
        text: ocr.text || '',
        fields: ocr.fields || extractPropertyFieldsFromText(''),
        error: ocr.error || null,
      };
    }),
  );

  const documentResults = ocrResults.map((result) => {
    if (!result.url) {
      return {
        id: result.id,
        label: result.label,
        present: false,
        pass: false,
        matchPercent: 0,
        status: 'missing',
        detectedType: '',
        message: 'Document missing',
      };
    }

    const classification =
      result.kind === 'government_id'
        ? classifyGovernmentId(result.text)
        : classifyPropertyDocument(result.text, result.kind);

    const matchPercent = Math.max(
      0,
      Math.min(100, Math.round(Number(classification.matchPercent) || 0)),
    );
    const pass = Boolean(classification.accepted);
    return {
      id: result.id,
      label: result.label,
      present: true,
      pass,
      matchPercent,
      status: pass ? 'verified' : 'failed',
      detectedType: classification.detectedType || '',
      message:
        classification.message ||
        (pass
          ? `${result.label} verified.`
          : `${result.label} could not be verified.`),
      error: result.error || undefined,
    };
  });

  const fieldParts = ocrResults
    .filter((r) => r.kind !== 'government_id' && r.url)
    .map((r) => ({ ...r.fields, source: r.id }));
  const extracted = mergePropertyFields(fieldParts);

  const report = buildVerificationReport({
    ownerDetails: ownerDetails || {},
    documents: documents || {},
    landDetails: landDetails || {},
    extracted,
  });

  // Prefer document-level match average when available.
  const scoredDocs = documentResults.filter((d) => d.present);
  const docsOverall =
    scoredDocs.length > 0
      ? scoredDocs.reduce((sum, d) => sum + d.matchPercent, 0) /
        scoredDocs.length /
        100
      : report.overallScore;

  return {
    ...report,
    overallScore: Number(docsOverall.toFixed(2)),
    documents: documentResults,
    ocrByDoc: ocrResults.reduce((acc, r) => {
      acc[r.id] = {
        ownerName: r.fields.ownerName,
        surveyNumber: r.fields.surveyNumber,
        district: r.fields.district,
        village: r.fields.village,
        error: r.error,
      };
      return acc;
    }, {}),
  };
}
module.exports = {
  verifyTicketDocuments,
  verifyPropertyDocumentUpload,
  ocrDocumentUrl,
};
