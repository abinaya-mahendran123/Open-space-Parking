/**
 * Low-RAM heuristics for hosted free / 512MB–2GB instances (e.g. Render).
 * Set LOW_MEMORY_OCR=0 to force full quality on a large machine.
 * Set LOW_MEMORY_OCR=1 to force frugal mode locally.
 */

function envFlag(name) {
  const v = String(process.env[name] || '')
    .trim()
    .toLowerCase();
  if (!v) return null;
  return v === '1' || v === 'true' || v === 'yes';
}

function isLowMemoryOcr() {
  const forced = envFlag('LOW_MEMORY_OCR');
  if (forced !== null) return forced;
  return Boolean(process.env.RENDER || process.env.RENDER_SERVICE_ID);
}

function ocrMaxConcurrentDefault() {
  if (isLowMemoryOcr()) return 1;
  return 2;
}

function preprocessLimits() {
  if (isLowMemoryOcr()) {
    return {
      maxWidth: 1100,
      minUpscale: 900,
      jpegQuality: 72,
      bandMaxWidth: 1200,
      bandJpegQuality: 75,
      pdfDensity: 140,
    };
  }
  return {
    maxWidth: 1600,
    minUpscale: 1200,
    jpegQuality: 85,
    bandMaxWidth: 1600,
    bandJpegQuality: 90,
    pdfDensity: 220,
  };
}

module.exports = {
  isLowMemoryOcr,
  ocrMaxConcurrentDefault,
  preprocessLimits,
};
