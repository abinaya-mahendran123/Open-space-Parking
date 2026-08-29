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
  // care-of / guardian (co) intentionally omitted from address
  const house = attr('house');
  const street = attr('street');
  const lm = attr('lm');
  const loc = attr('loc');
  const vtc = attr('vtc');
  const po = attr('po');
  const dist = attr('dist');
  const state = attr('state');
  const pc = attr('pc');

  // Exclude care-of / guardian (co) — keep house & location only.
  const addressParts = [house, street, lm, loc, vtc, po, dist, state, pc].filter(Boolean);
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
  const meta = await sharp(buffer).rotate().metadata();
  const w = meta.width || 800;
  // Keep QR decode fast on Render free tier (full 2200px × 5 variants was ~2 min).
  const targetWidth = Math.min(Math.max(w, 900), 1200);

  const makeVariant = (pipeline) =>
    pipeline
      .resize({ width: targetWidth, withoutEnlargement: false, kernel: 'lanczos3' })
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });

  const results = await Promise.allSettled([
    makeVariant(sharp(buffer).rotate().greyscale().normalize()),
    makeVariant(
      sharp(buffer)
        .rotate()
        .greyscale()
        .normalize()
        .sharpen()
        .linear(1.5, -(128 * 0.4)),
    ),
  ]);

  return results
    .filter((r) => r.status === 'fulfilled')
    .map((r) => r.value);
}

/**
 * Crop the regions where Aadhaar QR codes usually sit.
 */
async function buildQrCropVariants(buffer) {
  try {
    const meta = await sharp(buffer).rotate().metadata();
    const w = meta.width || 0;
    const h = meta.height || 0;
    if (w < 80 || h < 80) return [];

    const crops = [
      // bottom-right (most common on letter / plastic back)
      {
        left: Math.floor(w * 0.5),
        top: Math.floor(h * 0.4),
        width: Math.floor(w * 0.5),
        height: Math.floor(h * 0.6),
      },
      // tight bottom-right QR pocket
      {
        left: Math.floor(w * 0.58),
        top: Math.floor(h * 0.5),
        width: Math.floor(w * 0.42),
        height: Math.floor(h * 0.5),
      },
    ];

    const results = await Promise.allSettled(
      crops.map((crop) => {
        const left = Math.max(0, crop.left);
        const top = Math.max(0, crop.top);
        const width = Math.min(crop.width, w - left);
        const height = Math.min(crop.height, h - top);
        if (width < 60 || height < 60) {
          return Promise.reject(new Error('crop too small'));
        }
        return sharp(buffer)
          .rotate()
          .extract({ left, top, width, height })
          .greyscale()
          .normalize()
          .sharpen()
          .resize({ width: 800, withoutEnlargement: false, kernel: 'lanczos3' })
          .ensureAlpha()
          .raw()
          .toBuffer({ resolveWithObject: true });
      }),
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
