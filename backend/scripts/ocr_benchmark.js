/**
 * Local OCR benchmark utility (synthetic image or authorized test file).
 *
 * Usage:
 *   node scripts/ocr_benchmark.js --image path/to/test.jpg
 *
 * Does NOT print extracted PII — timing metrics only.
 */
const fs = require('fs');
const path = require('path');
const { preprocessVariant } = require('../ocr_preprocess');
const { recognizeBuffer: paddleRecognize, isServiceHealthy } = require('../ocr/paddleocr_client');
const { recognizeMultiPass } = require('../ocr/tesseract_engine');
const { extractAadhaarFromQr } = require('../aadhaar_qr');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === '--image') args.image = argv[++i];
  }
  return args;
}

async function timed(label, fn) {
  const start = Date.now();
  const result = await fn();
  return { label, ms: Date.now() - start, result };
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.image || !fs.existsSync(args.image)) {
    console.error('Usage: node scripts/ocr_benchmark.js --image path/to/test.jpg');
    process.exit(1);
  }

  const buffer = fs.readFileSync(args.image);
  const report = {
    imageBytes: buffer.length,
    paddleServiceHealthy: await isServiceHealthy(),
  };

  const qr = await timed('qr', () => extractAadhaarFromQr(buffer));
  report.qrMs = qr.ms;
  report.qrFound = Boolean(qr.result && (qr.result.fullName || qr.result.governmentIdNumber));

  const pre = await timed('preprocess', () => preprocessVariant(buffer, 'standard'));
  report.preprocessMs = pre.ms;

  try {
    const paddle = await timed('paddleOcr', () => paddleRecognize(pre.result));
    report.paddleOcrMs = paddle.ms;
    report.paddleLines = (paddle.result.text || []).length;
    report.paddleMode = paddle.result.mode;
  } catch (error) {
    report.paddleError = error.message;
  }

  const tess = await timed('tesseractFallback', () =>
    recognizeMultiPass(pre.result, { deep: false, idType: 'aadhaar' }),
  );
  report.tesseractFallbackMs = tess.ms;
  report.tesseractPasses = tess.result.passes;

  report.totalMs =
    report.qrMs + report.preprocessMs + (report.paddleOcrMs || 0) + report.tesseractFallbackMs;

  console.log(JSON.stringify(report, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
