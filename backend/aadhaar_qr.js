const sharp = require('sharp');
const jsQR = require('jsqr');
const zlib = require('zlib');
const { promisify } = require('util');

const inflate = promisify(zlib.inflate);
const inflateRaw = promisify(zlib.inflateRaw);
const gunzip = promisify(zlib.gunzip);

/**
 * Aadhaar Secure QR codes (post-2019) contain zlib-compressed XML.
 * The raw QR payload is a numeric string (all digits) that must be converted
 * to a byte buffer and then zlib-inflated to get the XML.
 * Older Aadhaar QRs contain plain-text XML directly.
 */
async function decompressAadhaarPayload(raw) {
  // If it looks like plain XML or pipe-delimited, return as-is
  if (raw.includes('<') || raw.includes('uid=') || raw.includes('|')) {
    return raw;
  }

  // Secure QR: all digits → convert big integer to byte buffer → inflate
  if (/^\d+$/.test(raw.trim())) {
    try {
      const digits = raw.trim();
      // Convert digit string to byte array
      const hex = BigInt(digits).toString(16);
      const paddedHex = hex.length % 2 === 0 ? hex : '0' + hex;
      const buf = Buffer.from(paddedHex, 'hex');

      // Try different decompression methods
      for (const decompress of [inflate, inflateRaw, gunzip]) {
        try {
          const decompressed = await decompress(buf);
          const text = decompressed.toString('utf-8');
          if (text.includes('<') || text.includes('uid=')) return text;
        } catch (_) { /* try next */ }
      }
    } catch (_) { /* not a valid big int */ }
  }

  return raw;
}

// ── QR payload parsers ────────────────────────────────────────────────────────

function parseAadhaarXml(qrData) {
  const text = String(qrData || '').trim();
  if (!text) return null;

  const attr = (name) => {
    const match = text.match(new RegExp(`${name}="([^"]*)"`, 'i'));
    return match?.[1]?.trim() || '';
  };

  const uid =
    attr('uid') ||
    (text.match(/\b(\d{4}\s?\d{4}\s?\d{4})\b/)?.[1] || '').replace(/\s+/g, '');
  const name = attr('name');
  const co = attr('co');
  const house = attr('house');
  const street = attr('street');
  const lm = attr('lm');
  const loc = attr('loc');
  const vtc = attr('vtc');
  const po = attr('po');
  const dist = attr('dist');
  const state = attr('state');
  const pc = attr('pc');

  const addressParts = [co, house, street, lm, loc, vtc, po, dist, state, pc].filter(Boolean);
  const address = addressParts.join(', ');

  if (!uid && !name && !address) return null;

  return {
    fullName: name,
    address,
    phone: '',
    governmentIdNumber: uid.length === 12 ? uid : '',
    aadhaarNumber: uid.length === 12 ? uid : '',
    source: 'aadhaar_qr',
  };
}

function parsePipeDelimited(qrData) {
  const parts = String(qrData || '')
    .split('|')
    .map((p) => p.trim())
    .filter(Boolean);
  if (parts.length < 2) return null;

  const uidCandidate = parts.find((p) => /^\d{12}$/.test(p.replace(/\s+/g, '')));
  const uid = uidCandidate ? uidCandidate.replace(/\s+/g, '') : '';

  const nameCandidate = parts.find(
    (p) =>
      p.length > 2 &&
      p.length < 80 &&
      !/^\d+$/.test(p) &&
      !/^[A-Z]{5}\d{4}[A-Z]$/i.test(p),
  );

  if (!uid && !nameCandidate) return null;

  return {
    fullName: nameCandidate || '',
    address: parts.slice(2).join(', '),
    phone: '',
    governmentIdNumber: uid,
    aadhaarNumber: uid,
    source: 'aadhaar_qr',
  };
}

function parseAadhaarQrPayload(qrData) {
  if (!qrData) return null;

  if (qrData.includes('<') || qrData.includes('uid=')) {
    return parseAadhaarXml(qrData);
  }

  if (qrData.includes('|')) {
    return parsePipeDelimited(qrData);
  }

  const uidMatch = qrData.match(/\b(\d{4}\s?\d{4}\s?\d{4})\b/);
  if (uidMatch) {
    const uid = uidMatch[1].replace(/\s+/g, '');
    return {
      fullName: '',
      address: '',
      phone: '',
      governmentIdNumber: uid,
      aadhaarNumber: uid,
      source: 'aadhaar_qr',
    };
  }

  return null;
}

// ── Low-level QR scan on raw RGBA buffer ─────────────────────────────────────

function tryJsQr(data, width, height) {
  try {
    const code = jsQR(new Uint8ClampedArray(data), width, height, {
      inversionAttempts: 'attemptBoth',
    });
    return code?.data || null;
  } catch (_) {
    return null;
  }
}

/**
 * Build multiple preprocessed RGBA buffers from one input buffer.
 * Each variant targets a different image characteristic to maximise QR decode rate.
 */
async function buildQrVariants(buffer) {
  const base = sharp(buffer).rotate();
  const meta = await base.metadata();
  const w = meta.width || 800;

  // Upscale small images so jsQR can find the QR finder patterns
  const targetWidth = Math.max(w, 1400);

  const makeVariant = (pipeline) =>
    pipeline
      .resize({ width: targetWidth, withoutEnlargement: false })
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });

  const results = await Promise.allSettled([
    // 1. Standard colour, auto-rotated
    makeVariant(sharp(buffer).rotate()),
    // 2. Greyscale + normalize
    makeVariant(sharp(buffer).rotate().greyscale().normalize()),
    // 3. High contrast
    makeVariant(
      sharp(buffer)
        .rotate()
        .greyscale()
        .normalize()
        .linear(1.5, -(128 * 0.4)),
    ),
    // 4. Threshold binarize (good for dark QR on white bg)
    makeVariant(sharp(buffer).rotate().greyscale().normalize().threshold(128)),
    // 5. Inverted threshold (for light QR on dark bg — rare but happens)
    makeVariant(
      sharp(buffer).rotate().greyscale().normalize().threshold(128).negate(),
    ),
    // 6. Sharpen then greyscale
    makeVariant(
      sharp(buffer).rotate().sharpen({ sigma: 2 }).greyscale().normalize(),
    ),
  ]);

  return results
    .filter((r) => r.status === 'fulfilled')
    .map((r) => r.value);
}

/**
 * Crop specific regions of the image to help QR scanning when the QR is in a
 * known corner. On Aadhaar letter format the QR is bottom-right of the left
 * (address) half. On plastic Aadhaar the QR is front-centre-right.
 */
async function buildQrCropVariants(buffer) {
  try {
    const meta = await sharp(buffer).rotate().metadata();
    const w = meta.width || 0;
    const h = meta.height || 0;
    if (w < 10 || h < 10) return [];

    // Generate 4 quadrant crops + 4 half-image crops
    const crops = [
      { left: Math.floor(w / 2), top: Math.floor(h / 2), width: Math.floor(w / 2), height: Math.floor(h / 2) }, // BR
      { left: 0, top: Math.floor(h / 2), width: Math.floor(w / 2), height: Math.floor(h / 2) }, // BL
      { left: Math.floor(w / 2), top: 0, width: Math.floor(w / 2), height: Math.floor(h / 2) }, // TR
      { left: 0, top: 0, width: Math.floor(w / 2), height: Math.floor(h / 2) }, // TL
      // right half
      { left: Math.floor(w / 2), top: 0, width: Math.floor(w / 2), height: h },
      // left half
      { left: 0, top: 0, width: Math.floor(w / 2), height: h },
      // bottom half
      { left: 0, top: Math.floor(h / 2), width: w, height: Math.floor(h / 2) },
      // bottom-right 40%
      {
        left: Math.floor(w * 0.6),
        top: Math.floor(h * 0.5),
        width: Math.floor(w * 0.4),
        height: Math.floor(h * 0.5),
      },
    ];

    const results = await Promise.allSettled(
      crops.map((crop) =>
        sharp(buffer)
          .rotate()
          .extract(crop)
          .greyscale()
          .normalize()
          .resize({ width: 800, withoutEnlargement: false })
          .ensureAlpha()
          .raw()
          .toBuffer({ resolveWithObject: true }),
      ),
    );

    return results
      .filter((r) => r.status === 'fulfilled')
      .map((r) => r.value);
  } catch (_) {
    return [];
  }
}

/**
 * Main QR decode function. Tries many preprocessing variants and crop regions.
 */
async function decodeQrFromBuffer(buffer) {
  // Full image variants first
  const fullVariants = await buildQrVariants(buffer);
  for (const { data, info } of fullVariants) {
    const result = tryJsQr(data, info.width, info.height);
    if (result) {
      console.log('[QR] Decoded from full-image variant, length:', result.length, 'preview:', result.substring(0, 60));
      return result;
    }
  }

  // Cropped region variants
  const cropVariants = await buildQrCropVariants(buffer);
  for (const { data, info } of cropVariants) {
    const result = tryJsQr(data, info.width, info.height);
    if (result) {
      console.log('[QR] Decoded from crop variant, length:', result.length, 'preview:', result.substring(0, 60));
      return result;
    }
  }

  console.log('[QR] No QR code found in any variant/crop');
  return null;
}

async function extractAadhaarFromQr(buffer) {
  const rawPayload = await decodeQrFromBuffer(buffer);
  if (!rawPayload) return null;

  // Decompress if it's a Secure QR (numeric-only payload = zlib-compressed XML)
  const payload = await decompressAadhaarPayload(rawPayload);
  console.log('[QR] Final payload type:', rawPayload === payload ? 'plain-text' : 'decompressed', '| preview:', payload.substring(0, 80));

  return parseAadhaarQrPayload(payload);
}

module.exports = {
  decodeQrFromBuffer,
  extractAadhaarFromQr,
  parseAadhaarQrPayload,
};
