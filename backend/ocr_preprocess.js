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
 */
async function splitSideBySide(buffer) {
  const meta = await sharp(buffer).metadata();
  const { width = 0, height = 0 } = meta;
  if (width === 0 || height === 0) return null;
  const ratio = width / height;

  if (ratio >= 1.85) {
    const halfWidth = Math.floor(width / 2);
    const [leftBuffer, rightBuffer] = await Promise.all([
      sharp(buffer).extract({ left: 0, top: 0, width: halfWidth, height }).toBuffer(),
      sharp(buffer)
        .extract({ left: halfWidth, top: 0, width: width - halfWidth, height })
        .toBuffer(),
    ]);
    return { frontBuffer: leftBuffer, backBuffer: rightBuffer };
  }

  if (ratio < 1.15 && height >= 700 && width >= 500) {
    const halfW = Math.floor(width / 2);
    const halfH = Math.floor(height / 2);
    const [topLeft, topRight, bottomLeft, bottomRight] = await Promise.all([
      sharp(buffer)
        .extract({ left: 0, top: 0, width: halfW, height: halfH })
        .toBuffer(),
      sharp(buffer)
        .extract({ left: halfW, top: 0, width: width - halfW, height: halfH })
        .toBuffer(),
      sharp(buffer)
        .extract({
          left: 0,
          top: halfH,
          width: halfW,
          height: height - halfH,
        })
        .toBuffer(),
      sharp(buffer)
        .extract({
          left: halfW,
          top: halfH,
          width: width - halfW,
          height: height - halfH,
        })
        .toBuffer(),
    ]);
    return {
      frontBuffer: bottomLeft,
      backBuffer: topLeft,
      topRight,
      bottomRight,
    };
  }

  if (ratio <= 0.85 && height >= 900) {
    const halfH = Math.floor(height / 2);
    const [topBuffer, bottomBuffer] = await Promise.all([
      sharp(buffer).extract({ left: 0, top: 0, width, height: halfH }).toBuffer(),
      sharp(buffer)
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
    if (width < 80 || height < 80) return [];

    // Prefer bottom / lower bands where the 12-digit UID is printed.
    const bands = [
      {
        left: Math.floor(width * 0.08),
        top: Math.floor(height * 0.68),
        width: Math.floor(width * 0.7),
        height: Math.floor(height * 0.28),
      },
      {
        left: Math.floor(width * 0.05),
        top: Math.floor(height * 0.5),
        width: Math.floor(width * 0.9),
        height: Math.floor(height * 0.4),
      },
    ];

    const outs = [];
    for (const band of bands) {
      const w = Math.max(20, Math.min(band.width, width - band.left));
      const h = Math.max(20, Math.min(band.height, height - band.top));
      if (band.left + w > width || band.top + h > height) continue;
      const cropped = await sharp(buffer)
        .rotate()
        .extract({ left: band.left, top: band.top, width: w, height: h })
        .greyscale()
        .normalize()
        .sharpen()
        .resize({ width: Math.min(Math.max(w * 2, 900), 1600), withoutEnlargement: false })
        .jpeg({ quality: 90 })
        .toBuffer();
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
