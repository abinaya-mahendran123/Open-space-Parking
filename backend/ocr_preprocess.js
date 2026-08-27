const sharp = require('sharp');

// Keep fast path to 1 variant — Render free tier gateway times out (~60s) otherwise.
const FAST_VARIANTS = ['standard'];
const DEEP_VARIANTS = ['standard', 'contrast'];
const VARIANTS = FAST_VARIANTS;

async function withAutoScale(image) {
  const meta = await image.metadata();
  const width = meta.width || 0;
  if (width <= 0) return image;

  // Cap resolution for speed on hosted free tier (still sharp enough for OCR).
  if (width < 1200) {
    return image.resize({
      width: Math.min(Math.max(width * 2, 1200), 1600),
      withoutEnlargement: false,
    });
  }
  if (width > 1600) {
    return image.resize({ width: 1600, withoutEnlargement: true });
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
        .jpeg({ quality: 85 })
        .toBuffer();
    case 'threshold':
      return scaled
        .greyscale()
        .normalize()
        .threshold(145)
        .jpeg({ quality: 85 })
        .toBuffer();
    case 'inverted':
      return scaled
        .greyscale()
        .negate()
        .normalize()
        .sharpen({ sigma: 1 })
        .jpeg({ quality: 85 })
        .toBuffer();
    case 'denoise':
      return scaled
        .greyscale()
        .normalize()
        .median(1)
        .sharpen({ sigma: 1.1 })
        .jpeg({ quality: 85 })
        .toBuffer();
    case 'bright':
      return scaled
        .greyscale()
        .modulate({ brightness: 1.25 })
        .normalize()
        .sharpen({ sigma: 1.3 })
        .jpeg({ quality: 85 })
        .toBuffer();
    case 'standard':
    default:
      return scaled
        .greyscale()
        .normalize()
        .sharpen({ sigma: 1.4 })
        .jpeg({ quality: 85 })
        .toBuffer();
  }
}

async function buildPreprocessedBuffers(buffer, { deep = false } = {}) {
  const variants = deep ? DEEP_VARIANTS : FAST_VARIANTS;
  const outputs = await Promise.all(
    variants.map(async (variant) => ({
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
 * IMPORTANT: do NOT quarter normal phone photos. That produced tiny crops
 * (e.g. 2x36) and sameBuffer:false double OCR (~200s) on Render.
 * Only split obvious dual-card layouts.
 */
async function splitSideBySide(buffer) {
  const meta = await sharp(buffer).rotate().metadata();
  const { width = 0, height = 0 } = meta;
  if (width === 0 || height === 0) return null;
  const ratio = width / height;

  // Wide: front | back side-by-side
  if (ratio >= 1.85 && width >= 900) {
    const halfWidth = Math.floor(width / 2);
    const [leftBuffer, rightBuffer] = await Promise.all([
      sharp(buffer).rotate().extract({ left: 0, top: 0, width: halfWidth, height }).toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({ left: halfWidth, top: 0, width: width - halfWidth, height })
        .toBuffer(),
    ]);
    return { frontBuffer: leftBuffer, backBuffer: rightBuffer };
  }

  // Very tall: front stacked above back (two full cards)
  if (ratio <= 0.55 && height >= 1400) {
    const halfH = Math.floor(height / 2);
    const [topBuffer, bottomBuffer] = await Promise.all([
      sharp(buffer).rotate().extract({ left: 0, top: 0, width, height: halfH }).toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({ left: 0, top: halfH, width, height: height - halfH })
        .toBuffer(),
    ]);
    return { frontBuffer: topBuffer, backBuffer: bottomBuffer };
  }

  return null;
}

async function buildPaddlePrimaryBuffer(buffer) {
  return preprocessVariant(buffer, 'standard');
}

async function buildPaddleRetryBuffer(buffer) {
  return preprocessVariant(buffer, 'contrast');
}

/**
 * Crops where the 12-digit Aadhaar number usually appears (bottom / mid bands).
 * Used for a fast digits-only Tesseract pass when full OCR misses the UID.
 */
async function cropAadhaarNumberBands(buffer) {
  try {
    const meta = await sharp(buffer).rotate().metadata();
    const width = meta.width || 0;
    const height = meta.height || 0;
    if (width < 120 || height < 120) return [];

    // Prefer bottom / lower bands where the 12-digit UID is printed.
    const bands = [
      {
        left: Math.floor(width * 0.08),
        top: Math.floor(height * 0.62),
        width: Math.floor(width * 0.84),
        height: Math.floor(height * 0.32),
      },
      {
        left: Math.floor(width * 0.05),
        top: Math.floor(height * 0.45),
        width: Math.floor(width * 0.9),
        height: Math.floor(height * 0.35),
      },
    ];

    const outs = [];
    for (const band of bands) {
      const left = Math.max(0, band.left);
      const top = Math.max(0, band.top);
      const w = Math.min(band.width, width - left);
      const h = Math.min(band.height, height - top);
      if (w < 80 || h < 40) continue;
      const cropped = await sharp(buffer)
        .rotate()
        .extract({ left, top, width: w, height: h })
        .greyscale()
        .normalize()
        .sharpen()
        .resize({
          width: Math.min(Math.max(w * 2, 1000), 1600),
          withoutEnlargement: false,
        })
        .jpeg({ quality: 90 })
        .toBuffer();
      const cropMeta = await sharp(cropped).metadata();
      if ((cropMeta.width || 0) < 80 || (cropMeta.height || 0) < 20) continue;
      outs.push(cropped);
    }
    return outs;
  } catch (_) {
    return [];
  }
}

module.exports = {
  VARIANTS,
  preprocessVariant,
  buildPreprocessedBuffers,
  buildPaddlePrimaryBuffer,
  buildPaddleRetryBuffer,
  splitSideBySide,
  cropAadhaarNumberBands,
};
