const http = require('http');
const https = require('https');

const { buildPreprocessedBuffers, splitSideBySide } = require('./ocr_preprocess');
const { extractAadhaarFromQr } = require('./aadhaar_qr');

const ID_TYPES = new Set(['aadhaar', 'pan', 'driving_license', 'voter_id']);
// PSM 6 = uniform block; PSM 4 = single column — helps plastic Aadhaar cards
const OCR_PSMS = ['6', '4'];

function fetchBuffer(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 5) {
      reject(new Error('Too many redirects while fetching image.'));
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

  // Drop any existing transformation segment so we control pg_1 / format.
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

  // Last resort: inject after /upload/ on the original URL shape.
  add(asImage.replace('/upload/', '/upload/f_png,pg_1,q_auto,w_2000/'));
  return candidates;
}

function cloudinaryPdfPageImageUrl(url) {
  return cloudinaryPdfRenderCandidates(url)[0] || null;
}

function looksLikeRasterImage(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 8) return false;
  // PNG
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47
  ) {
    return true;
  }
  // JPEG
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return true;
  }
  // WEBP (RIFF....WEBP)
  if (
    buffer.toString('ascii', 0, 4) === 'RIFF' &&
    buffer.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return true;
  }
  return false;
}

async function bufferToOcrImage(buffer, sourceUrl) {
  if (!isPdfBuffer(buffer)) return buffer;

  const candidates = cloudinaryPdfRenderCandidates(sourceUrl);
  for (const pageUrl of candidates) {
    try {
      const rendered = await fetchBuffer(pageUrl);
      if (looksLikeRasterImage(rendered)) {
        console.log('[OCR] PDF rendered via Cloudinary:', pageUrl);
        return rendered;
      }
      console.warn(
        '[OCR] Cloudinary PDF render returned non-image:',
        pageUrl,
        'bytes=',
        rendered.length,
      );
    } catch (error) {
      console.warn(
        '[OCR] Cloudinary PDF render failed:',
        pageUrl,
        error?.message || error,
      );
    }
  }

  try {
    const sharp = require('sharp');
    // Works only if libvips was built with PDF support (often missing on Render).
    return await sharp(buffer, { density: 220, page: 0 }).png().toBuffer();
  } catch (error) {
    console.warn('[OCR] sharp PDF rasterize failed:', error?.message || error);
    throw new Error(
      'Could not read this Aadhaar PDF automatically. Upload a clear PNG/JPG photo of the card (or a screenshot of the PDF), then tap Re-scan.',
    );
  }
}

async function fetchImageBufferForOcr(url) {
  const buffer = await fetchBuffer(url);
  return bufferToOcrImage(buffer, url);
}

function cleanLine(value) {
  return String(value || '')
    .replace(/\|/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Remove non-ASCII / Indic script characters from a string while preserving
 * English letters, digits, and common punctuation used in addresses/names.
 * This strips Tamil, Hindi, etc. Unicode that Tesseract (eng-only) misreads
 * as garbage symbols.
 */
function stripNonLatin(value) {
  return String(value || '')
    // Remove characters outside the basic ASCII printable range
    // Keep: letters, digits, space, common punctuation (,:./\-'())
    .replace(/[^\x20-\x7E]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function linesFromText(text) {
  return String(text || '')
    .split(/\r?\n/)
    .map(cleanLine)
    .filter(Boolean);
}

/**
 * Split OCR text into lines, stripping Indic/Tamil Unicode garbage from each line.
 * Use this when we specifically want only the English-readable content.
 */
function latinLinesFromText(text) {
  return String(text || '')
    .split(/\r?\n/)
    .map((l) => stripNonLatin(cleanLine(l)))
    .filter((l) => l.length > 1);
}

/**
 * Decide if a line is "mostly noise" after stripping non-latin characters —
 * i.e. the line was almost entirely Indic script and has nothing useful.
 */
function isMostlyNoise(line) {
  const latin = stripNonLatin(line);
  // If more than 60% of the original line's characters were stripped, it's noise
  if (line.length === 0) return true;
  return latin.length < line.length * 0.4 || latin.replace(/\s/g, '').length < 2;
}

function valueAfterLabel(text, labels) {
  const lines = linesFromText(text);
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    for (const label of labels) {
      const regex = new RegExp(`^${label}\\s*[:\\-]\\s*(.+)$`, 'i');
      const match = line.match(regex);
      if (match?.[1]) return stripNonLatin(cleanLine(match[1]));

      if (line.toLowerCase() === label.toLowerCase() && lines[i + 1]) {
        return stripNonLatin(lines[i + 1]);
      }
    }
  }
  return '';
}

// Boilerplate text on Aadhaar back that should never be treated as address
const AADHAAR_BACK_BOILERPLATE =
  /documents?\s+to\s+support|proof\s+of\s+identity|proof\s+of\s+address|aadhaar\s+(is|letter|number|holder)|uidai|unique\s+identification|authentication\s+agency|maadhaar|www\.uidai|qr\s+(code|scanner)|digitally\s+signed|income\s+tax|date\s+of\s+birth|enrolled\s+by|not\s+of\s+citizenship|regulation|submitted\s+by|online\s+authentication|available\s+in\s+app|entities\s+seeking|lock\/unlock|biometric|government\s+and\s+non|non.government|download\s+m/i;

// Aadhaar address anchor: starts with S/O, D/O, W/O, C/O or a house/building number
// Also matches "To" which precedes the address block in Aadhaar letter format
const ADDRESS_START =
  /^(s\/o|d\/o|w\/o|c\/o|so\s*:|do\s*:|wo\s*:|co\s*:|h\.?no\.?|house\s*no|flat\s*no|door\s*no|plot\s*no|\d+[,\/]|\d+\s+[a-z]|^To$)/i;

// Tamil script address label (முகவரி = Address in Tamil)
const TAMIL_ADDRESS_LABEL = /[\u0B80-\u0BFF]/;

// Known Aadhaar address field keywords
const ADDRESS_KEYWORD =
  /\b(street|road|nagar|colony|district|sub\s+district|state|pin\s+code|pincode|taluk|mandal|village|post|vtc|po\s*:|vtc\s*:)\b/i;

// Short noise tokens that commonly appear in Tamil OCR output mixed into address lines.
// These are OCR misreads of Tamil characters that survived Latin-strip.
const ADDRESS_NOISE_TOKEN =
  /\b(ae|Rs|SERIE|ERS|RRL|RR|Aa|LJ|AN|CRT|NZ|LH|AZ|HL|siy|mSLD|gaa|mas|adug|seLw|nagH|inanar|sme|Gigw|Siog|Inns|CaP|snap|clef|aauhH|IUD|SWH|fey|udCap|WHDIL|FMT|UME|Coma|Qum|aya|hse|aacop|udC|HFC|Hm|Hms|FHID|UMG|SHBCOR|whHpih|aged|gue|asi|Uday|Camauaamats|mAachaar|welianis|uHalimasab|auamuCwun|Quol|fide|Ceri|Ungar|muCwnQulflaay|CLEC|CV)\b/g;

/**
 * Clean up a raw OCR address line:
 * - Strip non-Latin characters (Tamil/Hindi OCR garbage)
 * - Remove noise tokens from Tamil OCR
 * - Remove leftover OCR symbols
 * - Normalize whitespace
 */
function cleanAddressLine(raw) {
  return stripNonLatin(raw)
    // Remove repeated punctuation / symbols
    .replace(/[!@#$%^&*(){}\[\]<>?~`'"\\]{2,}/g, ' ')
    // Remove stray single non-letter chars surrounded by spaces
    .replace(/(^|\s)[^a-zA-Z0-9,.\-:\/\s](\s|$)/g, ' ')
    // Remove known Tamil OCR noise tokens
    .replace(ADDRESS_NOISE_TOKEN, ' ')
    // Remove isolated 1-2 char tokens that aren't known abbreviations
    .replace(/(?<![a-zA-Z])\b([a-zA-Z]{1,2})\b(?![a-zA-Z])/g, (m) => {
      // Keep known abbreviations: PO, VTC, ST, NS, Dr, No
      const keep = /^(po|vtc|st|ns|dr|no|sq|ft|mr|ms|so|do|wo|co|nsk|rd)$/i.test(m);
      return keep ? m : ' ';
    })
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Final post-processing on a complete assembled address string.
 * Removes trailing/leading commas, double commas, and noise remnants.
 */
function finalizeAddress(addr) {
  return addr
    // Remove noise tokens that survived line-level cleaning
    .replace(ADDRESS_NOISE_TOKEN, ' ')
    // Collapse ",  ," style double commas
    .replace(/,\s*,+/g, ',')
    // Remove comma at start/end
    .replace(/^[\s,]+|[\s,]+$/g, '')
    // Remove short (1-3 char) noise segments between commas: ", ae," → ","
    .replace(/,\s*[a-zA-Z]{1,3}\s*,/g, ',')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Check if an address line looks like a real address component.
 * Accepts lines with known keywords, or lines with mostly alphanumeric + common punctuation.
 */
function isValidAddressLine(line) {
  if (!line || line.length < 3) return false;
  if (AADHAAR_BACK_BOILERPLATE.test(line)) return false;
  if (/^\d{4}\s+\d{4}\s+\d{4}/.test(line)) return false; // Aadhaar number
  if (/^(VID|vid)\s*:/.test(line)) return false;

  // Must have enough alphanumeric content
  const alphaNum = (line.match(/[a-zA-Z0-9]/g) || []).length;
  if (alphaNum < 3) return false;

  // Must be mostly Latin (not Indic noise)
  const latinRatio = (line.match(/[a-zA-Z0-9 ,.\-:\/]/g) || []).length / line.length;
  if (latinRatio < 0.55) return false;

  return true;
}

function extractAddress(text) {
  // Work with raw lines first for finding anchors, then clean each selected line
  const rawLines = linesFromText(text);

  // ── Strategy 1: Explicit "Address:" label ──────────────────────────────────
  for (let i = 0; i < rawLines.length; i++) {
    if (!/^address\s*[:\-]?\s*/i.test(rawLines[i])) continue;
    const collected = [];
    const startValue = cleanAddressLine(rawLines[i].replace(/^address\s*[:\-]?\s*/i, ''));
    if (startValue && isValidAddressLine(startValue)) collected.push(startValue);

    for (let j = i + 1; j < rawLines.length && collected.length < 10; j++) {
      const ln = cleanAddressLine(rawLines[j]);
      if (/^(name|dob|date\s+of\s+birth|phone|mobile|gender|sex|uid|pan|dl|voter|year\s+of\s+birth|yob)\b/i.test(ln)) break;
      if (!isValidAddressLine(ln)) continue;
      collected.push(ln);
    }
    if (
      collected.length > 0 &&
      (ADDRESS_START.test(collected[0]) || ADDRESS_KEYWORD.test(collected.join(' ')))
    ) {
      return finalizeAddress(collected.join(', '));
    }
  }

  // ── Strategy 1b: Tamil label "முகவரி" followed by address lines ──────────
  for (let i = 0; i < rawLines.length; i++) {
    if (!TAMIL_ADDRESS_LABEL.test(rawLines[i])) continue;
    const nextLatin = rawLines[i + 1] ? stripNonLatin(rawLines[i + 1]).trim() : '';
    if (ADDRESS_START.test(nextLatin) || ADDRESS_KEYWORD.test(nextLatin)) {
      const collected = [];
      for (let j = i + 1; j < rawLines.length && collected.length < 10; j++) {
        const ln = cleanAddressLine(rawLines[j]);
        if (TAMIL_ADDRESS_LABEL.test(rawLines[j]) && collected.length > 0) break;
        if (!isValidAddressLine(ln)) continue;
        if (/^(name|dob|mobile|gender|sex)\b/i.test(ln)) break;
        collected.push(ln);
      }
      if (collected.length > 0 && ADDRESS_KEYWORD.test(collected.join(' '))) {
        return finalizeAddress(collected.join(', '));
      }
    }
  }

  // ── Strategy 2: "To" block in Aadhaar letter (To → name → S/O: → address) ─
  const toIdx = rawLines.findIndex((l) => /^To\s*$/.test(stripNonLatin(l).trim()));
  if (toIdx !== -1) {
    // Skip the "To" line and name line(s), collect from S/O: onward
    const collected = [];
    let foundSO = false;
    for (let i = toIdx + 1; i < rawLines.length && collected.length < 15; i++) {
      const latin = stripNonLatin(rawLines[i]).trim();
      if (!foundSO) {
        if (/^s\/o|^d\/o|^w\/o|^c\/o|\d+,/i.test(latin)) foundSO = true;
        else continue; // skip name lines before S/O
      }
      const ln = cleanAddressLine(rawLines[i]);
      if (!isValidAddressLine(ln)) continue;
      if (/^(mobile|phone|gender|sex|dob|date\s+of\s+birth|signature|aadhaar\s+is)\b/i.test(ln)) break;
      if (/^\d{4}\s+\d{4}\s+\d{4}/.test(ln)) break;
      collected.push(ln);
    }
    if (collected.length > 0 && ADDRESS_KEYWORD.test(collected.join(' '))) {
      return finalizeAddress(collected.join(', '));
    }
  }

  // ── Strategy 2b: S/O anchor (most Aadhaar addresses start here) ───────────
  const soIdx = rawLines.findIndex((l) => /^(s\/o|d\/o|w\/o|c\/o)/i.test(stripNonLatin(l).trim()));
  if (soIdx !== -1) {
    const collected = [];
    for (let i = soIdx; i < rawLines.length && collected.length < 15; i++) {
      const ln = cleanAddressLine(rawLines[i]);
      if (!isValidAddressLine(ln)) continue;
      if (/^(mobile|phone|gender|sex|dob|date\s+of\s+birth|signature|aadhaar\s+is|documents?\s+to)\b/i.test(ln)) break;
      if (/^\d{4}\s+\d{4}\s+\d{4}/.test(ln)) break;
      collected.push(ln);
    }
    if (collected.length > 0) return finalizeAddress(collected.join(', '));
  }

  // ── Strategy 3: District/State anchor ────────────────────────────────────
  const distIdx = rawLines.findIndex((l) => /\b(sub\s+district|district|taluk|mandal)\b/i.test(stripNonLatin(l)));
  if (distIdx !== -1) {
    const start = Math.max(0, distIdx - 6);
    const collected = [];
    for (let i = start; i < rawLines.length && collected.length < 12; i++) {
      const ln = cleanAddressLine(rawLines[i]);
      if (!isValidAddressLine(ln)) continue;
      if (/^\d{4}\s+\d{4}\s+\d{4}/.test(ln)) break;
      if (/^(mobile|phone|gender|sex|signature)\b/i.test(ln)) break;
      collected.push(ln);
    }
    if (collected.length > 0) return finalizeAddress(collected.join(', '));
  }

  return '';
}

// Noise patterns — lines that are definitely NOT a person's name
const NAME_NOISE =
  /^(government|india|republic|unique|permanent|account|income|tax|election|commission|driving|license|aadhaar|uidai|epic|authority|department|ministry|of india|enrollment|enrolment|documents?|proof|address|mobile|phone|date|gender|male|female|year|yob|dob|sub\s+district|district|state|pin|taluk|village|post|road|nagar|colony|enrolment|enrollment|signature|digitally|verified|information|entity|entities)/i;

/**
 * Try to extract a clean English name from a raw OCR line.
 * Aadhaar bilingual lines look like: "ஹரிஹரன் / Hariharan" or "Hariharan"
 * Returns the name string or null.
 */
function tryParseName(rawLine) {
  // Case 1: bilingual format — "Tamil text / English Name"
  if (/\//.test(rawLine)) {
    const parts = rawLine.split('/');
    for (let i = parts.length - 1; i >= 0; i--) {
      const part = stripNonLatin(parts[i]).trim();
      if (isNameCandidate(part)) return cleanNamePrefix(part);
    }
  }

  // Case 2: pure English line
  const latin = stripNonLatin(rawLine).trim();
  if (isNameCandidate(latin)) return cleanNamePrefix(latin);

  return null;
}

function isNameCandidate(line) {
  if (!line || line.length < 3 || line.length > 55) return false;
  if (NAME_NOISE.test(line)) return false;
  if (AADHAAR_BACK_BOILERPLATE.test(line)) return false;
  // Address / relationship lines are not names
  if (/^(s\/o|d\/o|w\/o|c\/o)\b/i.test(line)) return false;
  if (ADDRESS_KEYWORD.test(line)) return false;
  if (/^\d/.test(line)) return false;
  if (/[@#%&*=+<>{}[\]\\|~`]/.test(line)) return false;
  const latinRatio = (line.match(/[a-zA-Z ]/g) || []).length / line.length;
  if (latinRatio < 0.8) return false;
  if ((line.match(/[a-zA-Z]/g) || []).length < 3) return false;
  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+){0,4}$/.test(line)) return true;
  if (/^[A-Z][A-Z ]{2,39}$/.test(line)) return true;
  if (/^[a-zA-Z]+(?: [a-zA-Z]+){0,4}$/.test(line)) return true;
  return false;
}

/**
 * Strip leading OCR noise tokens from a name candidate.
 * e.g. "Ss Hariharan" → "Hariharan", "fey Hariharan" → "Hariharan"
 */
function cleanNamePrefix(name) {
  // Remove leading 1-3 char noise word if a real capitalized name word follows
  return name
    .replace(/^[a-zA-Z]{1,3}\s+(?=[A-Z][a-z]{2,})/, '')
    .trim();
}

function isTamilScript(line) {
  // Tamil Unicode block: U+0B80–U+0BFF
  return /[\u0B80-\u0BFF]/.test(line);
}

function extractName(text) {
  const rawLines = String(text || '').split(/\r?\n/).map(cleanLine).filter(Boolean);

  // ── Strategy 1: Explicit "Name:" label ────────────────────────────────────
  for (let i = 0; i < rawLines.length; i++) {
    const m = rawLines[i].match(/^(?:full\s+)?name\s*[:\-]\s*(.+)$/i);
    if (m) {
      const candidate = tryParseName(m[1]);
      if (candidate) return candidate;
    }
    if (/^(?:full\s+)?name\s*$/i.test(rawLines[i]) && rawLines[i + 1]) {
      const candidate = tryParseName(rawLines[i + 1]);
      if (candidate) return candidate;
    }
  }

  // ── Strategy 1b: "To" block in Aadhaar letter — name is 1-2 lines after "To" ──
  // Letter format: "To\nஹரிஹரன்\nHariharan\nS/O:..."
  const toIdx = rawLines.findIndex((l) => /^To\s*$/.test(stripNonLatin(l).trim()));
  if (toIdx !== -1) {
    for (let i = toIdx + 1; i <= Math.min(toIdx + 4, rawLines.length - 1); i++) {
      const candidate = tryParseName(rawLines[i]);
      if (candidate) return candidate;
    }
  }

  // ── Strategy 2: Tamil line immediately followed by English name line ──────
  // On Aadhaar letter/plastic format: Tamil name on line N, English name on N+1.
  // Also handles "Tamil / English" slash-separated on same line.
  for (let i = 0; i < rawLines.length - 1; i++) {
    if (isTamilScript(rawLines[i])) {
      // Check same line after slash
      if (rawLines[i].includes('/')) {
        const parts = rawLines[i].split('/');
        for (const p of parts) {
          const c = tryParseName(p.trim());
          if (c) return c;
        }
      }
      // Check next line
      const next = rawLines[i + 1];
      const candidate = tryParseName(next);
      if (candidate) return candidate;
    }
  }

  // ── Strategy 3: Name appears just BEFORE DOB on Aadhaar front ─────────────
  const dobIdx = rawLines.findIndex((l) =>
    /\b(dob|date\s+of\s+birth|born|birth)\b/i.test(stripNonLatin(l)) ||
    /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/.test(l),
  );
  if (dobIdx > 0) {
    for (let i = dobIdx - 1; i >= Math.max(0, dobIdx - 5); i--) {
      const candidate = tryParseName(rawLines[i]);
      if (candidate) return candidate;
    }
  }

  // ── Strategy 4: Scan all lines for a name-like line ───────────────────────
  for (const line of rawLines) {
    const candidate = tryParseName(line);
    if (candidate) return candidate;
  }

  return '';
}

function extractPhone(text, idType) {
  const raw = String(text || '');
  // Step 1: strip 12-digit Aadhaar and 16-digit VID numbers first
  const cleaned = raw
    .replace(/\bVID\s*[:\-]?\s*\d[\d\s]{14,18}\d\b/gi, '')
    .replace(/\b\d{4}[\s]?\d{4}[\s]?\d{4}[\s]?\d{4}\b/g, '')
    .replace(/\b\d{4}[\s]?\d{4}[\s]?\d{4}\b/g, '');

  // Step 2: labeled mobile line takes highest priority
  const labelMatch = cleaned.match(
    /(?:mobile|mob\.?|phone|ph\.?|contact)\s*(?:no\.?|number)?\s*[:\-]?\s*([6-9]\d{9})/i,
  );
  if (labelMatch) return labelMatch[1];

  // Plastic Aadhaar usually has no phone — do not guess from random digits.
  if (idType === 'aadhaar') return '';

  // Step 3: any standalone 10-digit Indian mobile number
  const allMatches = cleaned.match(/(?<!\d)([6-9]\d{9})(?!\d)/g) || [];
  for (const m of allMatches) {
    if (/^[6-9]\d{9}$/.test(m)) return m;
  }
  return '';
}

/** Verhoeff checksum used by UIDAI for Aadhaar numbers. */
function isValidAadhaarChecksum(aadhaar) {
  const d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];
  const p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];
  const digits = String(aadhaar || '').replace(/\D/g, '');
  if (!/^\d{12}$/.test(digits)) return false;
  let c = 0;
  const reversed = digits.split('').reverse().map((x) => Number(x));
  for (let i = 0; i < reversed.length; i += 1) {
    c = d[c][p[i % 8][reversed[i]]];
  }
  return c === 0;
}

function scoreNameCandidate(name) {
  if (!name) return -1;
  let score = name.length;
  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+)+$/.test(name)) score += 20;
  if (/^[A-Z][A-Z ]{2,}$/.test(name)) score += 8;
  if (NAME_NOISE.test(name)) score -= 50;
  return score;
}

function titleCaseName(name) {
  return String(name || '')
    .toLowerCase()
    .replace(/\b([a-z])/g, (m) => m.toUpperCase())
    .trim();
}

function fixOcrIdNumber(value, idType) {
  let compact = String(value || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');

  if (idType === 'aadhaar') {
    // Common OCR confusions on printed Aadhaar digits
    compact = compact
      .replace(/[OQD]/g, '0')
      .replace(/[IL|]/g, '1')
      .replace(/[SZ]/g, '5')
      .replace(/[BG]/g, '8')
      .replace(/A/g, '4')
      .replace(/T/g, '7');
    if (/^\d{12}$/.test(compact)) return compact;
    const spaced = String(value || '')
      .replace(/[OQD]/gi, '0')
      .replace(/[IL|]/gi, '1')
      .replace(/[SZ]/gi, '5')
      .replace(/[BG]/gi, '8');
    const match = spaced.match(/\b([0-9OQDILSZBG]{4}[\s\-]?[0-9OQDILSZBG]{4}[\s\-]?[0-9OQDILSZBG]{4})\b/i);
    return match ? fixOcrIdNumber(match[1], idType) : compact.replace(/\D/g, '').slice(0, 12);
  }

  if (idType === 'pan') {
    compact = compact
      .replace(/^([A-Z]{5})0(\d{4})([A-Z])$/, '$1O$2$3')
      .replace(/([A-Z]{5})(\d{4})([A-Z])/, '$1$2$3');
    if (/^[A-Z]{5}\d{4}[A-Z]$/.test(compact)) return compact;
  }

  return compact;
}

function extractIdNumber(text, idType) {
  const raw = String(text || '');

  if (idType === 'aadhaar') {
    const candidates = new Set();

    const labelMatch = raw.match(
      /(?:aadhaar\s*no\.?|your\s+aadhaar\s*no\.?|uid\s*(?:no\.?|number)?)\s*[:\-]?\s*([0-9OQDILSZBG][0-9OQDILSZBG\s\-]{10,18}[0-9OQDILSZBG])/i,
    );
    if (labelMatch) {
      const fixed = fixOcrIdNumber(labelMatch[1], idType);
      if (fixed) candidates.add(fixed);
    }

    // Strip VID (16 digits) then collect all 12-digit-looking groups
    const noVid = raw.replace(/\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b/g, '');
    const groups = noVid.match(/\b([0-9OQDILSZBG]{4}[\s\-]?[0-9OQDILSZBG]{4}[\s\-]?[0-9OQDILSZBG]{4})\b/gi) || [];
    for (const g of groups) {
      const fixed = fixOcrIdNumber(g, idType);
      if (/^\d{12}$/.test(fixed)) candidates.add(fixed);
    }

    const list = [...candidates];
    if (list.length === 0) return '';

    // Prefer Verhoeff-valid Aadhaar numbers
    const valid = list.find((n) => isValidAadhaarChecksum(n));
    return valid || list[0];
  }

  if (idType === 'pan') {
    const match = raw.toUpperCase().match(/\b([A-Z]{5}\d{4}[A-Z])\b/);
    return fixOcrIdNumber(match ? match[1] : '', idType);
  }

  if (idType === 'voter_id') {
    const match = raw.toUpperCase().match(/\b([A-Z]{3}\d{7})\b/);
    return match ? match[1] : '';
  }

  const dlMatch = raw.toUpperCase().match(/\b([A-Z0-9]{5,20})\b/);
  return dlMatch ? dlMatch[1] : '';
}

function mergeExtracted(frontText, backText, idType) {
  const combined = `${frontText}\n${backText}`;
  const frontName = extractName(frontText);
  const backName = extractName(backText);
  const frontAddress = extractAddress(frontText);
  const backAddress = extractAddress(backText);
  const frontPhone = extractPhone(frontText, idType);
  const backPhone = extractPhone(backText, idType);
  const frontId = extractIdNumber(frontText, idType);
  const backId = extractIdNumber(backText, idType);
  const combinedId = extractIdNumber(combined, idType);

  // Prefer the stronger name candidate (plastic front vs letter back).
  const name =
    scoreNameCandidate(frontName) >= scoreNameCandidate(backName)
      ? frontName || backName
      : backName || frontName;
  // Address is usually on the back / letter panel.
  const address =
    (backAddress && backAddress.length >= (frontAddress || '').length
      ? backAddress
      : frontAddress) ||
    backAddress ||
    frontAddress;
  const phone = frontPhone || backPhone;
  const governmentIdNumber =
    [combinedId, frontId, backId].find((n) => isValidAadhaarChecksum(n)) ||
    combinedId ||
    frontId ||
    backId;

  return {
    fullName: titleCaseName(name),
    address: finalizeAddress(address || ''),
    phone,
    governmentIdNumber,
    rawText: combined.slice(0, 4000),
  };
}

function mergeWithPreference(primary, fallback) {
  return {
    fullName: primary.fullName || fallback.fullName || '',
    address: primary.address || fallback.address || '',
    phone: primary.phone || fallback.phone || '',
    governmentIdNumber:
      primary.governmentIdNumber || fallback.governmentIdNumber || '',
    aadhaarNumber: primary.aadhaarNumber || fallback.aadhaarNumber || '',
    rawText: fallback.rawText || '',
    extractionSource: primary.source || 'ocr',
  };
}

let _workerEng = null;
let _workerTam = null;

async function getWorkerEng() {
  if (!_workerEng) {
    const { createWorker } = require('tesseract.js');
    _workerEng = await createWorker('eng');
  }
  return _workerEng;
}

async function getWorkerTam() {
  if (!_workerTam) {
    const { createWorker } = require('tesseract.js');
    // eng+tam so Tesseract correctly segments bilingual Aadhaar text.
    // Tamil labels (முகவரி = Address, பெயர் = Name) help it find field boundaries.
    _workerTam = await createWorker('eng+tam');
  }
  return _workerTam;
}

async function recognizeWithPsm(worker, buffer, psm) {
  await worker.setParameters({ tessedit_pageseg_mode: psm });
  const { data } = await worker.recognize(buffer);
  return { text: data.text || '', confidence: data.confidence || 0 };
}

async function recognizeMultiPass(buffer, { useTamil = false } = {}) {
  const worker = useTamil ? await getWorkerTam() : await getWorkerEng();
  const preprocessed = await buildPreprocessedBuffers(buffer);
  const runs = [];

  for (const item of preprocessed) {
    for (const psm of OCR_PSMS) {
      const result = await recognizeWithPsm(worker, item.buffer, psm);
      runs.push({ ...result, variant: item.variant, psm });
    }
  }

  // Extra English-only pass for Aadhaar — cleaner Latin name/address than eng+tam.
  if (useTamil) {
    try {
      const engWorker = await getWorkerEng();
      const standard = preprocessed.find((p) => p.variant === 'standard') || preprocessed[0];
      if (standard) {
        const engRun = await recognizeWithPsm(engWorker, standard.buffer, '6');
        runs.push({ ...engRun, variant: 'eng_only', psm: '6' });
      }
    } catch (_) {
      /* optional */
    }
  }

  runs.sort((a, b) => b.confidence - a.confidence);
  const mergedText = runs.map((r) => r.text.trim()).filter(Boolean).join('\n');
  const best = runs[0] || { text: '', confidence: 0 };
  return { text: mergedText || best.text, confidence: best.confidence, passes: runs.length };
}

async function extractGovernmentIdDetails({ frontUrl, backUrl, idType }) {
  if (!ID_TYPES.has(idType)) {
    throw new Error('Unsupported government ID type.');
  }
  if (!frontUrl) {
    throw new Error('Image URL is required.');
  }

  // Avoid downloading/processing the same image twice when front === back
  const sameUrl = frontUrl === backUrl;
  let frontBuffer, backBuffer;
  let extraBackBuffer = null; // bottom-right plastic back card (for portrait 2×2)
  if (sameUrl) {
    const rawBuffer = await fetchImageBufferForOcr(frontUrl);
    const split = await splitSideBySide(rawBuffer);
    if (split) {
      frontBuffer = split.frontBuffer;
      backBuffer = split.backBuffer;
      if (split.bottomRight) extraBackBuffer = split.bottomRight;
    } else {
      frontBuffer = rawBuffer;
      backBuffer = rawBuffer;
    }
  } else {
    [frontBuffer, backBuffer] = await Promise.all([
      fetchImageBufferForOcr(frontUrl),
      fetchImageBufferForOcr(backUrl),
    ]);
  }

  // For Aadhaar: try QR code first on ALL available buffers — instant and 100% accurate.
  // Try the raw original buffer too (before splitting) in case the split degraded QR quality.
  let qrExtracted = null;
  if (idType === 'aadhaar') {
    const qrCandidates = [frontBuffer, backBuffer];
    // If we split, also try QR on the raw (unsplit) buffer
    if (sameUrl) {
      try {
        const rawBuffer = await fetchImageBufferForOcr(frontUrl);
        qrCandidates.unshift(rawBuffer); // raw full image first = highest quality
      } catch (_) { /* ignore */ }
    }
    for (const buf of qrCandidates) {
      qrExtracted = await extractAadhaarFromQr(buf);
      if (qrExtracted && (qrExtracted.fullName || qrExtracted.address)) break;
    }
  }

  const sameBuffer = frontBuffer === backBuffer;
  const useTamil = idType === 'aadhaar';

  const frontOcr = await recognizeMultiPass(frontBuffer, { useTamil });
  const backOcr = sameBuffer
    ? frontOcr
    : await recognizeMultiPass(backBuffer, { useTamil });

  // For portrait 2×2 layout: also OCR the bottom-right plastic back card
  // Merge its text into the back text so address extraction has more material
  let combinedBackText = backOcr.text;
  if (extraBackBuffer) {
    const extraOcr = await recognizeMultiPass(extraBackBuffer, { useTamil });
    combinedBackText = `${backOcr.text}\n${extraOcr.text}`;
    console.log('[OCR] Extra back text preview:', extraOcr.text.substring(0, 200).replace(/\n/g, ' | '));
  }

  console.log('[OCR] Front text preview:', frontOcr.text.substring(0, 200).replace(/\n/g, ' | '));
  console.log('[OCR] Back text preview:', backOcr.text.substring(0, 200).replace(/\n/g, ' | '));

  const ocrExtracted = mergeExtracted(frontOcr.text, combinedBackText, idType);
  ocrExtracted.ocrConfidence = Math.max(frontOcr.confidence, backOcr.confidence);
  ocrExtracted.ocrPasses = sameBuffer ? frontOcr.passes : frontOcr.passes + backOcr.passes;

  let extracted = ocrExtracted;
  if (qrExtracted) {
    extracted = mergeWithPreference(qrExtracted, ocrExtracted);
  }

  if (idType === 'aadhaar' && extracted.governmentIdNumber) {
    extracted.aadhaarNumber = extracted.governmentIdNumber;
  }

  return extracted;
}

async function terminateWorkers() {
  if (_workerEng) { try { await _workerEng.terminate(); } catch (_) {} _workerEng = null; }
  if (_workerTam) { try { await _workerTam.terminate(); } catch (_) {} _workerTam = null; }
}

module.exports = {
  extractGovernmentIdDetails,
  mergeExtracted,
  mergeWithPreference,
  recognizeMultiPass,
  terminateWorkers,
  cloudinaryPdfRenderCandidates,
  bufferToOcrImage,
};
