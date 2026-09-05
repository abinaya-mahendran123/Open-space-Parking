const sharp = require('sharp');
const { isLowMemoryOcr, preprocessLimits } = require('./ocr/low_memory');

// Cap Sharp thread/cache use — big win on 512MB–2GB hosts.
try {
  sharp.cache(isLowMemoryOcr() ? false : { memory: 32, files: 20, items: 100 });
  sharp.concurrency(isLowMemoryOcr() ? 1 : 2);
} catch (_) {
  // older sharp — ignore
}

// Keep fast path to 1 variant — Render free tier gateway times out (~60s) otherwise.
const FAST_VARIANTS = ['standard'];
const DEEP_VARIANTS = ['standard', 'contrast'];
const VARIANTS = FAST_VARIANTS;

async function withAutoScale(image, options = {}) {
  const limits = preprocessLimits();
  const maxWidth = Number(options.maxWidth || limits.maxWidth);
  const minUpscale = Number(options.minUpscale || limits.minUpscale);
  const meta = await image.metadata();
  const width = meta.width || 0;
  if (width <= 0) return image;

  // Cap resolution for speed / RAM on hosted free tier.
  if (width < minUpscale) {
    return image.resize({
      width: Math.min(Math.max(width * 2, minUpscale), maxWidth),
      withoutEnlargement: false,
    });
  }
  if (width > maxWidth) {
    return image.resize({ width: maxWidth, withoutEnlargement: true });
  }
  return image;
}

async function preprocessVariant(buffer, variant, preprocessOptions = {}) {
  const limits = preprocessLimits();
  const jpegQuality =
    Number(preprocessOptions.jpegQuality || limits.jpegQuality) || limits.jpegQuality;
  const rotated = sharp(buffer).rotate();
  const scaled = await withAutoScale(rotated, preprocessOptions);

  switch (variant) {
    case 'contrast':
      return scaled
        .greyscale()
        .normalize()
        .linear(1.45, -(128 * 0.35))
        .sharpen({ sigma: 1.2 })
        .jpeg({ quality: jpegQuality })
        .toBuffer();
    case 'threshold':
      return scaled
        .greyscale()
        .normalize()
        .threshold(145)
        .jpeg({ quality: jpegQuality })
        .toBuffer();
    case 'inverted':
      return scaled
        .greyscale()
        .negate()
        .normalize()
        .sharpen({ sigma: 1 })
        .jpeg({ quality: jpegQuality })
        .toBuffer();
    case 'denoise':
      return scaled
        .greyscale()
        .normalize()
        .median(1)
        .sharpen({ sigma: 1.1 })
        .jpeg({ quality: jpegQuality })
        .toBuffer();
    case 'bright':
      return scaled
        .greyscale()
        .modulate({ brightness: 1.25 })
        .normalize()
        .sharpen({ sigma: 1.3 })
        .jpeg({ quality: jpegQuality })
        .toBuffer();
    case 'standard':
    default:
      return scaled
        .greyscale()
        .normalize()
        .sharpen({ sigma: 1.4 })
        .jpeg({ quality: jpegQuality })
        .toBuffer();
  }
}

async function buildPreprocessedBuffers(buffer, { deep = false } = {}) {
  const variants = deep ? DEEP_VARIANTS : FAST_VARIANTS;
  // Sequential on low RAM — parallel Sharp spikes memory.
  if (isLowMemoryOcr()) {
    const outputs = [];
    for (const variant of variants) {
      outputs.push({
        variant,
        buffer: await preprocessVariant(buffer, variant),
      });
    }
    return outputs;
  }
  const outputs = await Promise.all(
    variants.map(async (variant) => ({
      variant,
      buffer: await preprocessVariant(buffer, variant),
    })),
  );
  return outputs;
}

/**
 * Prepare front/back buffers from one Aadhaar upload.
 *
 * Layouts:
 * - dual_horizontal / dual_vertical — front and back in one image
 * - back_columns — single back with address (left) + disclaimer (right)
 * - single — one card side only (front or back detected from OCR text)
 */
async function prepareAadhaarUpload(buffer) {
  const meta = await sharp(buffer).rotate().metadata();
  const { width = 0, height = 0 } = meta;
  if (width === 0 || height === 0) {
    return {
      layout: 'single',
      frontBuffer: buffer,
      backBuffer: buffer,
      sameBuffer: true,
    };
  }

  const ratio = width / height;
  const minHalf = 280;

  // Wide: front | back side-by-side (two portrait cards)
  if (ratio >= 1.55 && width >= 700) {
    const halfWidth = Math.floor(width / 2);
    if (halfWidth < minHalf) {
      return {
        layout: 'single',
        frontBuffer: buffer,
        backBuffer: buffer,
        sameBuffer: true,
      };
    }
    const leftBuffer = await sharp(buffer)
      .rotate()
      .extract({ left: 0, top: 0, width: halfWidth, height })
      .toBuffer();
    const rightBuffer = await sharp(buffer)
      .rotate()
      .extract({ left: halfWidth, top: 0, width: width - halfWidth, height })
      .toBuffer();
    return {
      layout: 'dual_horizontal',
      frontBuffer: leftBuffer,
      backBuffer: rightBuffer,
      sameBuffer: false,
    };
  }

  // Two cards stacked — only very tall/narrow images (not a single portrait card photo).
  if (ratio <= 0.4 && height >= 1400) {
    const halfH = Math.floor(height / 2);
    if (halfH < minHalf || width < minHalf) {
      return {
        layout: 'single',
        frontBuffer: buffer,
        backBuffer: buffer,
        sameBuffer: true,
      };
    }
    const [topBuffer, bottomBuffer] = await Promise.all([
      sharp(buffer).rotate().extract({ left: 0, top: 0, width, height: halfH }).toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({ left: 0, top: halfH, width, height: height - halfH })
        .toBuffer(),
    ]);
    return {
      layout: 'dual_vertical',
      frontBuffer: topBuffer,
      backBuffer: bottomBuffer,
      sameBuffer: false,
    };
  }

  // Single back card: address column (left) + legal disclaimer (right)
  if (ratio >= 1.15 && ratio < 1.55 && width >= 500) {
    const leftWidth = Math.max(1, Math.floor(width * 0.62));
    const leftBuffer = await sharp(buffer)
      .rotate()
      .extract({ left: 0, top: 0, width: leftWidth, height })
      .toBuffer();
    return {
      layout: 'back_columns',
      frontBuffer: buffer,
      backBuffer: leftBuffer,
      sameBuffer: false,
    };
  }

  // Portrait enrollment sheet — full-page letter + card (very tall scans only).
  if (ratio >= 0.45 && ratio < 0.92 && width >= 480 && height >= 1700) {
    const leftWidth = Math.max(1, Math.floor(width * 0.55));
    const topHeight = Math.max(1, Math.floor(height * 0.46));
    const bottomTop = topHeight;
    const bottomHeight = Math.max(1, height - bottomTop);
    const [letterCrop, cardFrontCrop, cardBackCrop, leftBuffer] = await Promise.all([
      sharp(buffer)
        .rotate()
        .extract({ left: 0, top: 0, width: leftWidth, height: topHeight })
        .toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({ left: 0, top: bottomTop, width: leftWidth, height: bottomHeight })
        .toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({
          left: leftWidth,
          top: bottomTop,
          width: Math.max(1, width - leftWidth),
          height: bottomHeight,
        })
        .toBuffer(),
      sharp(buffer)
        .rotate()
        .extract({ left: 0, top: 0, width: Math.floor(width * 0.68), height })
        .toBuffer(),
    ]);
    return {
      layout: 'enrollment_sheet',
      frontBuffer: cardFrontCrop,
      backBuffer: letterCrop,
      cardBackBuffer: cardBackCrop,
      addressCropBuffer: leftBuffer,
      sameBuffer: false,
    };
  }

  // Portrait single-card photo — keep left crop for back-side address OCR.
  if (ratio >= 0.45 && ratio < 1.15 && width >= 480) {
    const leftWidth = Math.max(1, Math.floor(width * 0.68));
    const leftBuffer = await sharp(buffer)
      .rotate()
      .extract({ left: 0, top: 0, width: leftWidth, height })
      .toBuffer();
    return {
      layout: 'single',
      frontBuffer: buffer,
      backBuffer: buffer,
      addressCropBuffer: leftBuffer,
      sameBuffer: true,
    };
  }

  return {
    layout: 'single',
    frontBuffer: buffer,
    backBuffer: buffer,
    sameBuffer: true,
  };
}

/** @deprecated Use prepareAadhaarUpload — kept for callers that only want dual-card splits. */
async function splitSideBySide(buffer) {
  const prepared = await prepareAadhaarUpload(buffer);
  if (
    prepared.layout === 'dual_horizontal' ||
    prepared.layout === 'dual_vertical'
  ) {
    return {
      frontBuffer: prepared.frontBuffer,
      backBuffer: prepared.backBuffer,
    };
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
          width: Math.min(
            Math.max(w * 2, 1000),
            preprocessLimits().bandMaxWidth,
          ),
          withoutEnlargement: false,
        })
        .jpeg({ quality: preprocessLimits().bandJpegQuality })
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

async function bufferMeetsMinOcrSize(buffer, minDim = 24) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length < 64) return false;
  try {
    const meta = await sharp(buffer).metadata();
    return (meta.width || 0) >= minDim && (meta.height || 0) >= minDim;
  } catch (_) {
    return false;
  }
}

module.exports = {
  VARIANTS,
  preprocessVariant,
  buildPreprocessedBuffers,
  buildPaddlePrimaryBuffer,
  buildPaddleRetryBuffer,
  prepareAadhaarUpload,
  splitSideBySide,
  cropAadhaarNumberBands,
  bufferMeetsMinOcrSize,
};
