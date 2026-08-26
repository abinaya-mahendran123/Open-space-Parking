/** Field extraction heuristics for government ID OCR. */

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
// Hindi / Devanagari address label (पता)
const HINDI_ADDRESS_LABEL = /[\u0900-\u097F]*\u092A\u0924\u093E|[\u0900-\u097F]/;

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
function cleanAddressLine(raw, options = {}) {
  const { preserveUnicode = false } = options;
  const base = preserveUnicode ? cleanLine(raw) : stripNonLatin(raw);
  return base
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
    // OCR often turns "S/O :" into "/ :" or "/:"
    .replace(/^[\s/|:.-]+/, '')
    .replace(/^(?:s\s*\/\s*o|d\s*\/\s*o|w\s*\/\s*o|c\s*\/\s*o)\s*[:.\-]?\s*/i, (m) =>
      m.replace(/\s+/g, ''),
    )
    .replace(/^\/\s*:\s*/i, 'S/O: ')
    .replace(/^:\s*/, '')
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
function isValidAddressLine(line, options = {}) {
  const { preserveUnicode = false } = options;
  if (!line || line.length < 3) return false;
  if (AADHAAR_BACK_BOILERPLATE.test(line)) return false;
  if (/^\d{4}\s+\d{4}\s+\d{4}/.test(line)) return false; // Aadhaar number
  if (/^(VID|vid)\s*:/.test(line)) return false;

  const alphaNum = (line.match(/[\p{L}\p{N}]/gu) || line.match(/[a-zA-Z0-9]/g) || []).length;
  if (alphaNum < 3) return false;

  if (!preserveUnicode) {
    const latinRatio = (line.match(/[a-zA-Z0-9 ,.\-:\/]/g) || []).length / line.length;
    if (latinRatio < 0.55) return false;
  }

  return true;
}

function extractAddress(text, options = {}) {
  // Work with raw lines first for finding anchors, then clean each selected line
  const rawLines = linesFromText(text);

  // ── Strategy 1: Explicit "Address:" label ──────────────────────────────────
  for (let i = 0; i < rawLines.length; i++) {
    if (!/^address\s*[:\-]?\s*/i.test(rawLines[i])) continue;
    const collected = [];
    const startValue = cleanAddressLine(
      rawLines[i].replace(/^address\s*[:\-]?\s*/i, ''),
      options,
    );
    if (startValue && isValidAddressLine(startValue, options)) collected.push(startValue);

    for (let j = i + 1; j < rawLines.length && collected.length < 10; j++) {
      const ln = cleanAddressLine(rawLines[j], options);
      if (/^(name|dob|date\s+of\s+birth|phone|mobile|gender|sex|uid|pan|dl|voter|year\s+of\s+birth|yob)\b/i.test(ln)) break;
      if (!isValidAddressLine(ln, options)) continue;
      collected.push(ln);
    }
    if (
      collected.length > 0 &&
      (ADDRESS_START.test(collected[0]) || ADDRESS_KEYWORD.test(collected.join(' ')))
    ) {
      return finalizeAddress(collected.join(', '));
    }
  }

  // ── Strategy 1b: Tamil / Hindi address labels followed by English lines ───
  for (let i = 0; i < rawLines.length; i++) {
    const hasIndicLabel =
      TAMIL_ADDRESS_LABEL.test(rawLines[i]) ||
      HINDI_ADDRESS_LABEL.test(rawLines[i]) ||
      /पता|address/i.test(rawLines[i]);
    if (!hasIndicLabel) continue;
    const nextLatin = rawLines[i + 1] ? stripNonLatin(rawLines[i + 1]).trim() : '';
    if (ADDRESS_START.test(nextLatin) || ADDRESS_KEYWORD.test(nextLatin)) {
      const collected = [];
      for (let j = i + 1; j < rawLines.length && collected.length < 10; j++) {
        const ln = cleanAddressLine(rawLines[j], options);
        if (
          (TAMIL_ADDRESS_LABEL.test(rawLines[j]) ||
            HINDI_ADDRESS_LABEL.test(rawLines[j])) &&
          collected.length > 0
        ) {
          break;
        }
        if (!isValidAddressLine(ln, options)) continue;
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
      const ln = cleanAddressLine(rawLines[i], options);
      if (!isValidAddressLine(ln, options)) continue;
      if (/^(mobile|phone|gender|sex|dob|date\s+of\s+birth|signature|aadhaar\s+is)\b/i.test(ln)) break;
      if (/^\d{4}\s+\d{4}\s+\d{4}/.test(ln)) break;
      collected.push(ln);
    }
    if (collected.length > 0 && ADDRESS_KEYWORD.test(collected.join(' '))) {
      return finalizeAddress(collected.join(', '));
    }
  }

  // ── Strategy 2b: S/O anchor (most Aadhaar addresses start here) ───────────
  const soIdx = rawLines.findIndex((l) =>
    /^(s\/o|d\/o|w\/o|c\/o|\/\s*:|\/:)/i.test(stripNonLatin(l).trim()),
  );
  if (soIdx !== -1) {
    const collected = [];
    for (let i = soIdx; i < rawLines.length && collected.length < 15; i++) {
      const ln = cleanAddressLine(rawLines[i], options);
      if (!isValidAddressLine(ln, options)) continue;
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
      const ln = cleanAddressLine(rawLines[i], options);
      if (!isValidAddressLine(ln, options)) continue;
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
  /^(government|india|republic|unique|permanent|account|income|tax|election|commission|driving|license|aadhaar|uidai|epic|authority|department|ministry|of india|enrollment|enrolment|documents?|proof|address|mobile|phone|date|gender|male|female|year|yob|dob|sub\s+district|district|state|pin|taluk|village|post|road|nagar|colony|enrolment|enrollment|signature|digitally|verified|information|entity|entities|madurai|tamil|nadu|vtc|pincode|pin\s*code)/i;

// Mangled OCR of Aadhaar headers ("Government of India" → "Govemmentofingia Pee")
const GOVERNMENT_HEADER_NOISE =
  /gov(?:ern?ment|emment|em?ent)?\s*of?\s*ind|govemmentofingia|governmentofindia|govtofindia|unique\s*ident|uidai|aadhaar|republicofindia|meity|ministryof/i;

/**
 * Normalize OCR mush so "Govemmentofingia Pee" still matches government noise.
 */
function compactForNoiseCheck(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
}

function looksLikeGovernmentHeader(value) {
  const text = String(value || '');
  if (GOVERNMENT_HEADER_NOISE.test(text)) return true;
  const compact = compactForNoiseCheck(text);
  if (!compact) return false;
  if (GOVERNMENT_HEADER_NOISE.test(compact)) return true;
  if (compact.includes('governmentofindia')) return true;
  if (compact.includes('govemmentofingia')) return true;
  if (compact.includes('govtofindia')) return true;
  if (compact.includes('republicofindia')) return true;
  if (compact.includes('uidai')) return true;
  // Very long single token with "india" is almost never a personal name.
  if (compact.includes('india') && compact.length >= 12 && !/\s/.test(text.trim())) {
    return true;
  }
  return false;
}

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
  if (looksLikeGovernmentHeader(line)) return false;
  if (NAME_NOISE.test(line)) return false;
  if (AADHAAR_BACK_BOILERPLATE.test(line)) return false;
  if (/^\d/.test(line)) return false;
  if (/[@#%&*=+<>{}[\]\\|~`]/.test(line)) return false;
  // Address / location lines are not names.
  if (ADDRESS_START.test(line) || ADDRESS_KEYWORD.test(line)) return false;
  if (/\b(street|road|nagar|colony|district|state|pin|mobile|phone|signature)\b/i.test(line)) {
    return false;
  }

  const latinRatio = (line.match(/[a-zA-Z ]/g) || []).length / line.length;
  if (latinRatio < 0.8) return false;
  if ((line.match(/[a-zA-Z]/g) || []).length < 3) return false;

  const words = line.trim().split(/\s+/);
  // Reject OCR mush like "Ef Org Or Did" (many tiny tokens).
  const shortWords = words.filter((w) => w.length <= 2).length;
  if (shortWords >= 2) return false;
  if (words.length >= 3 && words.every((w) => w.length <= 3)) return false;
  // Reject OCR mashups: one huge word with no spaces and odd length.
  if (words.length === 1 && words[0].length > 14) return false;
  // "Govemmentofingia Pee" style: first word too long and not title-case clean.
  if (words[0].length > 12 && !/^[A-Z][a-z]+$/.test(words[0])) return false;

  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+){0,4}$/.test(line)) return true;
  if (/^[A-Z][A-Z ]{2,39}$/.test(line)) return true;
  if (/^[a-zA-Z]+(?: [a-zA-Z]+){0,4}$/.test(line) && words.some((w) => w.length >= 4)) {
    return true;
  }
  return false;
}

/**
 * Strip leading OCR noise tokens from a name candidate.
 * e.g. "Ss Hariharan" → "Hariharan", "fey Hariharan" → "Hariharan"
 */
function cleanNamePrefix(name) {
  return name
    .replace(/^[a-zA-Z]{1,3}\s+(?=[A-Z][a-z]{2,})/, '')
    .trim();
}

function isTamilScript(line) {
  return /[\u0B80-\u0BFF]/.test(line);
}

function isDevanagariScript(line) {
  return /[\u0900-\u097F]/.test(line);
}

function scoreNameCandidate(name) {
  if (!name) return -1;
  if (looksLikeGovernmentHeader(name) || NAME_NOISE.test(name)) return -100;

  let score = Math.min(name.length, 24);
  const words = name.trim().split(/\s+/);

  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+)+$/.test(name)) score += 30;
  else if (/^[A-Z][a-z]+$/.test(name)) score += 22;
  else if (/^[A-Z][A-Z ]{2,}$/.test(name)) score += 10;
  else score += 4;

  if (words.length >= 2 && words.length <= 4) score += 8;
  if (words.some((w) => w.length > 14)) score -= 25;
  if (words.filter((w) => w.length <= 2).length >= 2) score -= 40;
  if (words.length >= 3 && words.every((w) => w.length <= 3)) score -= 50;
  if (/\b(india|government|govemment|uidai|aadhaar|madurai|tamil|org|did)\b/i.test(name)) {
    score -= 80;
  }
  return score;
}

function pickBestName(candidates) {
  let best = '';
  let bestScore = 0;
  for (const candidate of candidates) {
    const cleaned = cleanNamePrefix(String(candidate || '').trim());
    if (!cleaned || !isNameCandidate(cleaned)) continue;
    const score = scoreNameCandidate(cleaned);
    if (score > bestScore) {
      bestScore = score;
      best = cleaned;
    }
  }
  return bestScore >= 12 ? best : '';
}

function extractName(text) {
  const rawLines = String(text || '')
    .split(/\r?\n/)
    .map(cleanLine)
    .filter(Boolean);

  const ranked = [];

  const push = (candidate, bonus = 0) => {
    if (!candidate) return;
    const cleaned = cleanNamePrefix(candidate);
    if (!cleaned || !isNameCandidate(cleaned)) return;
    ranked.push({
      name: cleaned,
      score: scoreNameCandidate(cleaned) + bonus,
    });
  };

  // ── Strategy 1: Explicit "Name:" label ────────────────────────────────────
  for (let i = 0; i < rawLines.length; i++) {
    const m = rawLines[i].match(/^(?:full\s+)?name\s*[:\-]\s*(.+)$/i);
    if (m) push(tryParseName(m[1]), 40);
    if (/^(?:full\s+)?name\s*$/i.test(rawLines[i]) && rawLines[i + 1]) {
      push(tryParseName(rawLines[i + 1]), 40);
    }
  }

  // ── Strategy 1b: "To" block in Aadhaar letter ─────────────────────────────
  const toIdx = rawLines.findIndex((l) =>
    /^To\s*$/.test(stripNonLatin(l).trim()),
  );
  if (toIdx !== -1) {
    for (let i = toIdx + 1; i <= Math.min(toIdx + 5, rawLines.length - 1); i++) {
      push(tryParseName(rawLines[i]), 35);
    }
  }

  // ── Strategy 1c: Name is the English line immediately before S/O / D/O ────
  const soIdx = rawLines.findIndex((l) =>
    /^(s\/o|d\/o|w\/o|c\/o)\b/i.test(stripNonLatin(l).trim()),
  );
  if (soIdx > 0) {
    for (let i = soIdx - 1; i >= Math.max(0, soIdx - 4); i--) {
      const candidate = tryParseName(rawLines[i]);
      if (candidate) {
        push(candidate, 45);
        break;
      }
    }
  }

  // ── Strategy 2: Indic line followed by English name ───────────────────────
  for (let i = 0; i < rawLines.length - 1; i++) {
    if (isTamilScript(rawLines[i]) || isDevanagariScript(rawLines[i])) {
      if (rawLines[i].includes('/')) {
        const parts = rawLines[i].split('/');
        for (const p of parts) push(tryParseName(p.trim()), 30);
      }
      push(tryParseName(rawLines[i + 1]), 30);
    }
  }

  // ── Strategy 3: Name appears just BEFORE DOB on Aadhaar front ─────────────
  const dobIdx = rawLines.findIndex(
    (l) =>
      /\b(dob|date\s+of\s+birth|born|birth|yob|year\s+of\s+birth)\b/i.test(
        stripNonLatin(l),
      ) || /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/.test(l),
  );
  if (dobIdx > 0) {
    for (let i = dobIdx - 1; i >= Math.max(0, dobIdx - 5); i--) {
      push(tryParseName(rawLines[i]), 38);
    }
  }

  // ── Strategy 4: Scan remaining lines, but never prefer header noise ───────
  for (const line of rawLines) {
    push(tryParseName(line), 0);
  }

  ranked.sort((a, b) => b.score - a.score);
  return ranked.length && ranked[0].score >= 12 ? ranked[0].name : '';
}

function extractPhone(text, idType) {
  const raw = String(text || '');
  // Step 1: strip 12-digit Aadhaar and 16-digit VID numbers first
  const cleaned = raw
    .replace(/\bVID\s*[:\-]?\s*\d[\d\s]{14,18}\d\b/gi, '')
    .replace(/\b\d{4}[\s]?\d{4}[\s]?\d{4}[\s]?\d{4}\b/g, '')
    .replace(/\b\d{4}[\s]?\d{4}[\s]?\d{4}\b/g, '');

  // Step 2: labeled mobile line (allow spaces / OCR typos like Moblle)
  const labelMatch = cleaned.match(
    /(?:mob(?:ile|lle|le)?|phone|ph\.?|contact)\s*(?:no\.?|number)?\s*[:\-.]?\s*([6-9][\d\s\-.]{8,14}\d)/i,
  );
  if (labelMatch) {
    const digits = labelMatch[1].replace(/\D/g, '');
    if (/^[6-9]\d{9}$/.test(digits)) return digits;
  }

  // Also accept "Mobile 8148401544" mid-line (address block footers).
  const inlineMatch = cleaned.match(
    /\b(?:mob(?:ile|lle|le)?|phone)\b[^0-9]{0,12}([6-9][\d\s\-.]{8,14}\d)/i,
  );
  if (inlineMatch) {
    const digits = inlineMatch[1].replace(/\D/g, '');
    if (/^[6-9]\d{9}$/.test(digits)) return digits;
  }

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

function mergeExtracted(frontText, backText, idType, options = {}) {
  const combined = `${frontText}\n${backText}`;
  const frontName = extractName(frontText);
  const backName = extractName(backText);
  const frontAddress = extractAddress(frontText, options);
  const backAddress = extractAddress(backText, options);
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


function scoreOcrExtraction(partial) {
  let score = 0;
  if (partial.fullName) score += 30 + Math.min(partial.fullName.length, 40);
  if (partial.address) score += 25 + Math.min(partial.address.length / 4, 40);
  if (partial.governmentIdNumber) {
    score += isValidAadhaarChecksum(partial.governmentIdNumber) ? 50 : 20;
  }
  if (partial.phone) score += 5;
  return score;
}

function mergeBestFields(a = {}, b = {}) {
  return {
    fullName:
      scoreNameCandidate(a.fullName) >= scoreNameCandidate(b.fullName)
        ? a.fullName || b.fullName || ''
        : b.fullName || a.fullName || '',
    address:
      (a.address || '').length >= (b.address || '').length
        ? a.address || b.address || ''
        : b.address || a.address || '',
    phone: a.phone || b.phone || '',
    governmentIdNumber:
      [a.governmentIdNumber, b.governmentIdNumber].find((n) =>
        isValidAadhaarChecksum(n),
      ) ||
      a.governmentIdNumber ||
      b.governmentIdNumber ||
      '',
  };
}

function isCompleteAadhaarQr(qr) {
  return Boolean(
    qr &&
      qr.fullName &&
      qr.address &&
      (qr.governmentIdNumber || qr.aadhaarNumber) &&
      String(qr.governmentIdNumber || qr.aadhaarNumber).replace(/\D/g, '')
        .length === 12,
  );
}

function isUsefulPartialQr(qr) {
  return Boolean(
    qr &&
      ((qr.governmentIdNumber &&
        String(qr.governmentIdNumber).replace(/\D/g, '').length === 12) ||
        qr.fullName ||
        qr.address),
  );
}


const ID_TYPES = new Set(['aadhaar', 'pan', 'driving_license', 'voter_id']);

module.exports = {
  cleanLine,
  stripNonLatin,
  linesFromText,
  latinLinesFromText,
  extractAddress,
  extractName,
  extractPhone,
  extractIdNumber,
  mergeExtracted,
  mergeWithPreference,
  scoreOcrExtraction,
  scoreNameCandidate,
  isValidAadhaarChecksum,
  titleCaseName,
  isCompleteAadhaarQr,
  isUsefulPartialQr,
  mergeBestFields,
  ID_TYPES,
};
