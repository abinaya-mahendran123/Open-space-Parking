const sharp = require('sharp');

// Only two variants to keep OCR fast. 'standard' works for most clear images;
// 'contrast' helps with faded or low-contrast prints.
const VARIANTS = ['standard', 'contrast', 'threshold'];

async function withAutoScale(image) {
  const meta = await image.metadata();
  const width = meta.width || 0;
  // Phone camera / compressed uploads are often too small for reliable OCR.
  if (width > 0 && width < 1800) {
    return image.resize({
      width: Math.min(Math.max(width * 2, 1800), 2800),
      withoutEnlargement: false,
    });
  }
  if (width > 3200) {
    return image.resize({ width: 2800, withoutEnlargement: true });
  }
  return image;
}

async function preprocessVariant(buffer, variant) {
  const rotated = sharp(buffer).rotate();
  const scaled = await withAutoScale(rotated);

  switch (variant) {
    case 'contrast':
      return scaled
        .greyscale()
        .normalize()
        .linear(1.45, -(128 * 0.35))
        .sharpen({ sigma: 1.2 })
        .jpeg({ quality: 95 })
        .toBuffer();
    case 'threshold':
      return scaled
        .greyscale()
        .normalize()
        .threshold(145)
        .jpeg({ quality: 95 })
        .toBuffer();
    case 'inverted':
      return scaled
        .greyscale()
        .negate()
        .normalize()
        .sharpen({ sigma: 1 })
        .jpeg({ quality: 95 })
        .toBuffer();
    case 'standard':
    default:
      return scaled
        .greyscale()
        .normalize()
        .sharpen({ sigma: 1.4 })
        .jpeg({ quality: 95 })
        .toBuffer();
  }
}

async function buildPreprocessedBuffers(buffer) {
  const outputs = await Promise.all(
    VARIANTS.map(async (variant) => ({
      variant,
      buffer: await preprocessVariant(buffer, variant),
    })),
  );
  return outputs;
}

/**
 * Detect and split a combined Aadhaar image into front (name/DOB side) and
 * back (address side) buffers.
 *
 * Handles two common formats:
 *  1. Landscape side-by-side: front=left half, back=right half  (ratio >= 2.2)
 *  2. Portrait 2×2 grid (A4 Aadhaar letter): plastic front=bottom-left quadrant,
 *     plastic back=bottom-right quadrant  (ratio < 1.0, height > 800px)
 *
 * Returns { frontBuffer, backBuffer } or null if not a combined image.
 */
async function splitSideBySide(buffer) {
  const meta = await sharp(buffer).metadata();
  const { width = 0, height = 0 } = meta;
  if (width === 0 || height === 0) return null;
  const ratio = width / height;

  // ── Format 1: Landscape side-by-side ──────────────────────────────────────
  if (ratio >= 2.2) {
    const halfWidth = Math.floor(width / 2);
    const [leftBuffer, rightBuffer] = await Promise.all([
      sharp(buffer).extract({ left: 0, top: 0, width: halfWidth, height }).toBuffer(),
      sharp(buffer).extract({ left: halfWidth, top: 0, width: width - halfWidth, height }).toBuffer(),
    ]);
    return { frontBuffer: leftBuffer, backBuffer: rightBuffer };
  }

  // ── Format 2: Portrait 2×2 grid (A4 Aadhaar letter, ratio ≈ 0.8) ─────────
  // Layout:
  //   Top-left    = letter front (name/address in Tamil+English text block)
  //   Top-right   = information/disclaimer panel (not useful)
  //   Bottom-left = plastic front card (photo, name, DOB, Aadhaar No.)
  //   Bottom-right= plastic back card (structured address block)
  //
  // Strategy: merge top-left + bottom-left as "front" (has name & Aadhaar No.)
  //           merge top-left + bottom-right as "back"  (has address)
  // Top-left letter format has the MOST readable address (plain English text).
  if (ratio < 1.1 && height >= 600) {
    const halfW = Math.floor(width / 2);
    const halfH = Math.floor(height / 2);
    const [topLeft, topRight, bottomLeft, bottomRight] = await Promise.all([
      sharp(buffer).extract({ left: 0,     top: 0,     width: halfW,          height: halfH          }).toBuffer(),
      sharp(buffer).extract({ left: halfW, top: 0,     width: width - halfW,  height: halfH          }).toBuffer(),
      sharp(buffer).extract({ left: 0,     top: halfH, width: halfW,          height: height - halfH }).toBuffer(),
      sharp(buffer).extract({ left: halfW, top: halfH, width: width - halfW,  height: height - halfH }).toBuffer(),
    ]);
    // Front = bottom-left plastic card (name, DOB, Aadhaar number)
    // Back  = top-left letter (has full readable address block) + bottom-right plastic back
    // We'll pass top-left as "back" since it has the clearest address text
    const frontBuffer = bottomLeft;
    const backBuffer  = topLeft;   // letter format: "Sub District:", "District:", "State:", "PIN:"
    return { frontBuffer, backBuffer, topRight, bottomRight };
  }

  return null;
}

module.exports = {
  VARIANTS,
  preprocessVariant,
  buildPreprocessedBuffers,
  splitSideBySide,
};
