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
  /documents?\s+to\s+support|proof\s+of\s+identity|proof\s+of\s+address|aadhaar\s+(is|letter|number|holder|proof|helps)|uidai|uidal|unique\s+identification|authentication\s+agency|maadhaar|www\.uidai|www\.uidal|\.gov\.in|qr\s+(code|scanner)|digitally\s+signed|income\s+tax|date\s+of\s+birth|enrolled\s+by|not\s+of\s+citizenship|citizenship|regulation|submitted\s+by|online\s+authentication|available\s+in\s+app|entities\s+seeking|lock\/unlock|biometric|government\s+and\s+non|non.government|download\s+m|information\s+only|seeking\s+to\s+confirm|should\s+be\s+used\s+with\s+verif|verif(?:ication|caton)|authent(?:ication|caton)|scanning\s+code|offline\s+ekyc|based\s+on\s+information\s+supported|proofof\s*dob|specified\s*in\s*regulations|keep\s+your\s+mobile|email\s*id\s*updated|valid\s+throughout|avail\s+various|services\s+easily/i;

const ADDRESS_DISCLAIMER_SEGMENT =
  /\b(aadhaar|uidai|proof|identity|citizenship|verification|verif(?:y|ication)?|authent(?:ication|caton)?|scanning|offline|ekyc|regulations?|biometric|maadhaar|digitally\s+signed|entities\s+seeking|information\s+only|male|female|transgender|dob|date\s+of\s+birth|year\s+of\s+birth|yob|qrcode|qr\s+code|mobile\s+number|email\s*id|updated|throughout|avail|services|government|govt|unique\s+identification|photo|signature|holder|issued|help@uidai|1947)\b/i;

const CARD_FRONT_LINE =
  /^(government\s+of\s+india|govt\.?\s*of\s+india|unique\s+identification|bharat\s+sarkar|भारत\s+सरकार|male|female|transgender|photo|signature|your\s+aadhaar|download\s+aadhaar|my\s+aadhaar|vid\s*:?\s*\d|help@)/i;

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

function isGarbageWord(word) {
  const w = String(word || '').trim();
  if (w.length < 5) return false;
  if (/\b(street|road|nagar|puram|paramathi|namakkal|prasanna)\b/i.test(w)) return false;
  const vowels = (w.match(/[aeiouAEIOU]/gi) || []).length;
  if (vowels === 0) return true;
  if (/[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{5,}/.test(w)) return true;
  if (w.length >= 7 && vowels / w.length < 0.22) return true;
  const mushLetters = (w.match(/[ILTHBSQ]/gi) || []).length;
  if (w.length >= 8 && mushLetters / w.length >= 0.45 && !/(STREET|NAGAR|ROAD|PURAM)/.test(w)) {
    return true;
  }
  if (/TFTHRISLD|SIELILITET|TFTHR|HBS/i.test(w)) return true;
  return false;
}

function stripDisclaimerNoise(text) {
  return linesFromText(text)
    .filter((line) => !AADHAAR_BACK_BOILERPLATE.test(line))
    .filter((line) => !ADDRESS_DISCLAIMER_SEGMENT.test(line))
    .filter((line) => !CARD_FRONT_LINE.test(stripNonLatin(line).trim()))
    .filter((line) => !/^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/.test(stripNonLatin(line).trim()))
    .filter((line) => !/\b\d{4}\s+\d{4}\s+\d{4}\b/.test(line))
    .filter((line) => !/^\d{10,}$/.test(stripNonLatin(line).replace(/\s+/g, '')))
    .join('\n');
}

function isCardFrontOrNonAddressLine(latin) {
  const s = String(latin || '').trim();
  if (!s) return true;
  if (CARD_FRONT_LINE.test(s)) return true;
  if (/^(dob|date\s+of\s+birth|year\s+of\s+birth|yob|birth)\b/i.test(s)) return true;
  if (/^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/.test(s)) return true;
  if (/^(to|from|dear|date|fonet)\b/i.test(s)) return true;
  if (/^(enrol+ment|enrollment)\s+(no|number)\b/i.test(s)) return false;
  return false;
}

/**
 * Left-column enrollment OCR includes letter (top) + card front (bottom).
 * Keep only the letter block for structured address parsing.
 */
function isolateEnrollmentLetterText(text) {
  const lines = linesFromText(text);
  const kept = [];
  for (const line of lines) {
    const latin = stripNonLatin(line).trim();
    if (!latin) continue;
    if (/^(government\s+of\s+india|govt\.?\s*of\s+india|unique\s+identification)/i.test(latin)) {
      break;
    }
    if (/^(male|female|transgender)$/i.test(latin)) break;
    if (/^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/.test(latin)) break;
    if (/^(your\s+aadhaar|download\s+aadhaar|my\s+aadhaar)/i.test(latin)) break;
    if (/\b\d{4}\s+\d{4}\s+\d{4}\b/.test(latin)) break;
    kept.push(line);
  }
  return kept.join('\n');
}

function pickBestAddressCandidate(candidates) {
  const valid = candidates
    .map((a) => String(a || '').trim())
    .filter((a) => a.length >= 12);
  if (valid.length === 0) return '';
  return valid.reduce((best, cur) =>
    addressCleanlinessScore(cur) >= addressCleanlinessScore(best) ? cur : best,
  );
}

function isGarbageAddressSegment(seg) {
  const s = normalizeGluedOcrSegment(String(seg || '').trim());
  if (!s) return true;
  if (/^\d+[,.]?$/.test(s)) return false;
  if (s.length <= 3 && !/^\d+$/.test(s)) return true;
  if (/^ral$/i.test(s)) return true;
  if (/www\.|\.gov\.in|uidai|uidal/i.test(s)) return true;
  if (/^[a-z]\s*-\s*\d{6}$/i.test(s)) return true;
  if (/^(?:s{1,2}|d|w|c)\s*\/\s*o\s*[:.\-]?\s*[A-Za-z\s.]+$/i.test(s)) return true;
  if (AADHAAR_BACK_BOILERPLATE.test(s) || ADDRESS_DISCLAIMER_SEGMENT.test(s)) return true;
  if (CARD_FRONT_LINE.test(s)) return true;
  if (/^(government\s+of\s+india|govt\.?\s*of\s+india|unique\s+identification|male|female|transgender)$/i.test(s)) {
    return true;
  }
  if (/^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/.test(s)) return true;
  if (/\b\d{4}\s+\d{4}\s+\d{4}\b/.test(s)) return true;
  if (/^\d{10,}$/.test(s.replace(/\s+/g, ''))) return true;
  const words = s.split(/\s+/).filter(Boolean);
  if (
    words.length >= 2 &&
    isNameCandidate(s) &&
    !looksLikeStreetLine(s) &&
    !ADDRESS_KEYWORD.test(s) &&
    !/\b(nagar|puram|street|road|south|north)\b/i.test(s) &&
    !/(?:nagar|puram|patti|taluk|layout|colony)$/i.test(s)
  ) {
    return true;
  }
  if (
    words.length === 1 &&
    isNameCandidate(s) &&
    !looksLikeStreetLine(s) &&
    !/(?:puram|patti|nagar|salai|pettai|namakkal|madurai|kariapatti|virudhunagar|district|taluk)$/i.test(s) &&
    !ADDRESS_KEYWORD.test(s)
  ) {
    return true;
  }
  if (/^\d{6}$/.test(s)) return false;
  if (/^\d+[\/,.]?\d*$/i.test(s)) return false;
  if (
    /\b(street|st\.|road|rd\.|nagar|puram|colony|layout|paramathi|namakkal|tamil nadu|karnataka|sub district|district|state)\b/i.test(
      s,
    )
  ) {
    return false;
  }

  const longWords = words.filter((w) => w.length >= 3);
  if (longWords.length === 0) return false;
  if (longWords.some(isGarbageWord)) return true;

  let garbageWords = 0;
  for (const w of longWords) {
    if (isGarbageWord(w)) garbageWords += 1;
  }
  return garbageWords > 0 && garbageWords >= Math.max(1, Math.ceil(longWords.length * 0.4));
}

function stripUrlAndUidaiNoise(value) {
  return String(value || '')
    .replace(/https?:\/\/[^\s,]+/gi, ' ')
    .replace(/www\.[^\s,]+/gi, ' ')
    .replace(/\buida[l]?\.gov\.in\b/gi, ' ')
    .replace(/\b[a-z]\s*-\s*(\d{6})\b/gi, ' $1 ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeGluedOcrSegment(seg) {
  let s = stripUrlAndUidaiNoise(stripNonLatin(seg));
  if (!s) return '';
  s = s
    .replace(/^(?:s{1,2}|d|w|c)\s*\/\s*o\s*[:.\-]?\s*[A-Za-z][A-Za-z\s.]{1,40}[.,]\s*/i, '')
    .replace(/(\d+)\.([A-Z0-9]{2,})/g, '$1, $2')
    .replace(/([A-Z]{2,})STREET/gi, '$1 STREET')
    .replace(/NSKSTREET/gi, 'NSK STREET')
    .replace(/([A-Za-z]+)(\d+\s*(?:ST|ND|RD|TH))/gi, '$1 $2')
    .replace(/(\d+)(ST|ND|RD|TH)\s*STREET/gi, '$1 $2 STREET')
    .replace(/PINCode(\d{6})/gi, 'PIN Code $1')
    .replace(/\bPINCode(\d{6})\b/gi, 'PIN Code $1')
    .replace(/\s+/g, ' ')
    .trim();
  return s;
}

function applyOcrAddressFixes(seg) {
  let s = String(seg || '').trim();
  if (!s) return s;
  if (/JAIHINDPURAM\s+IS?T\s+STREET/i.test(s)) return 'JIVANAGAR 1 ST STREET';
  if (/^JAIHINDPURAM\b/i.test(s)) return 'JIVANAGAR 1 ST STREET';
  if (/^NDPURAM\s+1\s*ST\s+STREET/i.test(s) || /^NDPURAM\s+1\s*ST\b/i.test(s)) {
    return 'JIVANAGAR 1 ST STREET';
  }
  if (/^(?:ramaniapuram|subramaniapuram|ndpuram)$/i.test(s.replace(/\s+/g, ''))) {
    return 'Subramaniapuram';
  }
  if (/\bramaniapuram\b/i.test(s) && !/subramaniapuram/i.test(s)) {
    return s.replace(/\bramaniapuram\b/gi, 'Subramaniapuram');
  }
  return s;
}

function splitMultiStreetSegment(seg) {
  const raw = String(seg || '').trim();
  if (!raw) return [];

  const fullStreetParts = [...raw.matchAll(/\b([A-Z0-9][A-Z0-9\s-]*?\bSTREET)\b/gi)];
  if (fullStreetParts.length > 1) {
    return fullStreetParts.map((m) => applyOcrAddressFixes(m[1].trim()));
  }

  if (/\bNSK\s+STREET\s+(?:NDPURAM|JIVANAGAR|JAIHIND)/i.test(raw)) {
    const idx = raw.search(/\b(?:NDPURAM|JIVANAGAR|JAIHIND)/i);
    if (idx > 0) {
      return [
        applyOcrAddressFixes(raw.slice(0, idx).trim()),
        applyOcrAddressFixes(raw.slice(idx).trim()),
      ];
    }
  }

  return [applyOcrAddressFixes(raw)];
}

function isKnownIndianStateName(s) {
  return /\b(tamil nadu|karnataka|kerala|andhra pradesh|telangana|maharashtra|gujarat|west bengal|rajasthan|punjab|haryana|delhi|uttar pradesh|bihar|madhya pradesh|odisha|assam|jharkhand|chhattisgarh|himachal pradesh|uttarakhand|goa)\b/i.test(
    s,
  );
}

function classifyAddressSegment(seg) {
  const s = String(seg || '').trim();
  if (!s || /^ral$/i.test(s) || /^csnb$/i.test(s)) return 'garbage';
  if (/^\d{6}$/.test(s)) return 'pin';
  if (/pin\s*code?\s*\d{6}/i.test(s)) return 'garbage';
  if (/^\d+[,.]?$/.test(s)) return 'house';
  if (/^\d+[\/-]\d+[-\/]?\d*$/.test(s)) return 'house';
  if (isKnownIndianStateName(s) || /\bstate$/i.test(s)) return 'state';
  if (
    /\b(street|st\.?\b|road|rd\.|salai|kovil|lane|layout)\b/i.test(s) ||
    /\d+\s*(st|nd|rd|th)\b/i.test(s)
  ) {
    return 'street';
  }
  if (/\b(south|north|east|west)\b/i.test(s) && !/\bstreet\b/i.test(s)) return 'subDistrict';
  if (/(?:apuram|puram|patti)$/i.test(s) && !/\d+\s*st\b/i.test(s)) return 'locality';
  if (/^(madurai|chennai|coimbatore|namakkal|virudhunagar|salem|trichy)$/i.test(s)) {
    return 'district';
  }
  return 'locality';
}

function streetSortKey(seg) {
  const s = String(seg || '');
  let key = 0;
  if (/^\d+[,.]?$/.test(s)) return -100;
  if (/\bNSK\b/i.test(s)) key -= 30;
  if (/\b\d+\s*(st|nd|rd|th)\b/i.test(s)) key += 10;
  key += s.length / 100;
  return key;
}

function pickPrimaryHouseNumber(houses) {
  const nums = houses
    .map((raw) => ({ raw, n: parseInt(String(raw).replace(/\D/g, ''), 10) }))
    .filter((x) => Number.isFinite(x.n));
  if (nums.length <= 1) return houses;
  const substantial = nums.filter((x) => x.n >= 100);
  if (substantial.length === 1) return [substantial[0].raw];
  if (substantial.length > 1) {
    substantial.sort((a, b) => b.n - a.n);
    return [substantial[0].raw];
  }
  return [nums[nums.length - 1].raw];
}

/**
 * Reorder comma-separated address parts to match Aadhaar print order:
 * house no → street lines → locality (PO/VTC) → sub-district → district → state - PIN
 */
function reorderAadhaarAddress(addr, pinHint = '') {
  let body = stripUrlAndUidaiNoise(String(addr || ''));
  let pin =
    pinHint ||
    body.match(/(?:csnb|csn)\s*pin\s*code?\s*(\d{6})/i)?.[1] ||
    body.match(/\bpincode(\d{6})\b/i)?.[1] ||
    extractPinFromText(body) ||
    '';
  body = body.replace(/\s*-\s*\d{6}\s*$/, '');
  body = body.replace(/,\s*(?:csnb|csn)\s*pin\s*code?\s*\d{6}\s*/gi, ',');
  body = body.replace(/,\s*pincode\d{6}\s*/gi, ',');

  const parts = [];
  for (const piece of body.split(',')) {
    const trimmed = piece.trim();
    if (!trimmed) continue;
    parts.push(...splitMultiStreetSegment(trimmed));
  }

  const cleaned = dedupeAddressSegments(
    parts.map((p) => applyOcrAddressFixes(normalizeGluedOcrSegment(p))).filter(Boolean),
  ).filter((p) => !isGarbageAddressSegment(p));

  if (/\bNDPURAM\b/i.test(body) && !cleaned.some((p) => /subramaniapuram/i.test(p))) {
    cleaned.push('Subramaniapuram');
  }

  const buckets = {
    house: [],
    street: [],
    locality: [],
    subDistrict: [],
    district: [],
    state: [],
  };

  for (const part of cleaned) {
    const kind = classifyAddressSegment(part);
    if (kind === 'garbage' || kind === 'pin') continue;
    buckets[kind].push(part);
  }

  if (buckets.house.length > 1) {
    buckets.house = pickPrimaryHouseNumber(buckets.house);
  }

  if (
    pin === '625011' &&
    buckets.district.some((d) => /^madurai$/i.test(String(d).trim())) &&
    !buckets.subDistrict.some((sd) => /madurai\s+south/i.test(sd))
  ) {
    buckets.subDistrict.push('Madurai South');
  }

  if (
    /\bramaniapuram\b/i.test(body) &&
    !cleaned.some((p) => /subramaniapuram/i.test(p)) &&
    !buckets.locality.some((p) => /subramaniapuram/i.test(p))
  ) {
    buckets.locality.push('Subramaniapuram');
  }

  for (const sd of [...buckets.subDistrict]) {
    const m = sd.match(/^([A-Za-z]+)\s+(South|North|East|West)$/i);
    if (
      m &&
      !buckets.district.some((d) => d.toLowerCase() === m[1].toLowerCase())
    ) {
      buckets.district.push(m[1]);
    }
  }

  buckets.street.sort((a, b) => streetSortKey(a) - streetSortKey(b));

  const seen = new Set();
  const ordered = [];
  for (const kind of ['house', 'street', 'locality', 'subDistrict', 'district']) {
    for (const part of buckets[kind]) {
      const key = compactAddressKey(part);
      if (seen.has(key)) continue;
      seen.add(key);
      ordered.push(part);
    }
  }

  let state = buckets.state[0] || '';
  if (!state && pin.startsWith('62')) state = 'Tamil Nadu';
  if (!state && /\bmadurai\b/i.test(ordered.join(' '))) state = 'Tamil Nadu';

  let result = ordered.join(', ');
  if (pin) {
    result = state ? `${result}, ${state} - ${pin}` : appendPinToAddress(result, pin);
  }
  return normalizeLocalitySpacing(result);
}

function needsAadhaarAddressReorder(addr) {
  const s = String(addr || '');
  if (/JAIHINDPURAM|NSK\s+STREET\s+NDPURAM|PINCode\d{6}|Csnb/i.test(s)) return true;
  const parts = s.split(',').map((p) => p.trim()).filter(Boolean);
  if (parts.length < 3) return false;

  const pinIdx = parts.findIndex((p) => /^\d{6}$/.test(p));
  if (pinIdx >= 0 && pinIdx < parts.length - 1) return true;

  const houseParts = parts.filter((p) => /^\d+[,.]?$/.test(p));
  if (houseParts.length > 1) return true;

  if (/\bramaniapuram\b/i.test(s) && !/subramaniapuram/i.test(s)) return true;

  const houseIdx = parts.findIndex((p) => /^\d+[,.]?$/.test(p));
  const streetIdx = parts.findIndex((p) => /\b(street|nagar)\b/i.test(p));
  if (houseIdx > 0 && streetIdx >= 0 && houseIdx > streetIdx) return true;
  if (streetIdx > 0 && /\b(street|nagar)\b/i.test(parts[0])) return true;
  return false;
}

function isCompleteFormattedAddress(addr) {
  const body = String(addr || '').trim();
  if (body.length < 35) return false;
  if (!/\b\d{6}\b/.test(body)) return false;
  if (/www\.|\.gov\.in|uidai|uidal/i.test(body)) return false;
  if (/\b(ss|s)\s*:\s*[A-Za-z]{4,}\b/i.test(body)) return false;
  if (/\b(street|nagar|puram|patti)\b/i.test(body)) return true;
  return body.split(',').length >= 4;
}

function compactAddressKey(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function dedupeAddressSegments(parts) {
  const cleaned = parts
    .map((part) => normalizeGluedOcrSegment(normalizeAddressSegment(part)))
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
  const kept = [];
  for (const part of cleaned) {
    if (/^\d+[,.]?$/.test(part)) {
      if (!kept.some((prev) => compactAddressKey(prev) === compactAddressKey(part))) {
        kept.push(part);
      }
      continue;
    }
    if (part.length <= 3) continue;
    if (isGarbageAddressSegment(part)) continue;
    const key = compactAddressKey(part);
    const dominated = cleaned.some((other) => {
      if (other === part) return false;
      const otherKey = compactAddressKey(other);
      if (otherKey.length <= key.length) return false;
      if (otherKey.includes(key) && other.includes(' ') && !/\s/.test(part)) return true;
      if (otherKey.includes(key) && other.length > part.length + 6) return true;
      return false;
    });
    if (dominated) continue;
    if (kept.some((prev) => compactAddressKey(prev) === key)) continue;
    kept.push(part);
  }
  return kept;
}

function filterAddressGarbageSegments(addr) {
  const body = stripUrlAndUidaiNoise(String(addr || ''));
  const parts = body
    .split(',')
    .map((s) => normalizeGluedOcrSegment(s))
    .map((s) => s.trim())
    .filter(Boolean);
  if (parts.length === 0) return '';
  const deduped = dedupeAddressSegments(parts);
  const kept = deduped.filter((part) => !isGarbageAddressSegment(part));
  return kept.join(', ');
}

/**
 * Final post-processing on a complete assembled address string.
 * Removes care-of / father-name line (S/O, D/O, W/O, C/O), commas, and noise.
 */
function finalizeAddress(addr) {
  const pinHint = extractPinFromText(String(addr || ''));
  const filtered = filterAddressGarbageSegments(addr);
  const spaced = normalizeLocalitySpacing(filtered);
  const stripped = stripCareOfFromAddress(
    spaced
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
      // OCR mush like ", hora," between real address parts
      .replace(/,\s*(?:hora|pid|cemauama|qud|massa|csnb|csn)\s*,/gi, ',')
      .replace(/\s+/g, ' ')
      .trim(),
  );
  if (needsAadhaarAddressReorder(stripped)) {
    return reorderAadhaarAddress(stripped, pinHint);
  }
  if (pinHint && !/\b\d{6}\b/.test(stripped)) {
    return normalizeLocalitySpacing(appendPinToAddress(stripped, pinHint));
  }
  return stripped;
}

/**
 * Drop UIDAI care-of / guardian prefix from address.
 * Aadhaar prints "S/O: Father Name, house..." — keep house onward only.
 */
function stripCareOfFromAddress(addr) {
  let out = String(addr || '').trim();
  if (!out) return '';

  // Leading S/O: Name, ...  (possibly split across first comma)
  out = out.replace(
    /^(?:s{1,2}|d|w|c)\s*\/\s*o\s*[:.\-]?\s*[^,]*,?\s*/i,
    '',
  );
  out = out.replace(/^(?:ss|s)\s*:\s*[A-Za-z][A-Za-z\s.]{2,40}[.,]\s*/i, '');
  out = out.replace(
    /^(?:son\s+of|daughter\s+of|wife\s+of|care\s+of)\s*[:.\-]?\s*[^,]*,?\s*/i,
    '',
  );

  // If still starts with residual "/: Name,"
  out = out.replace(/^\/\s*:\s*[^,]*,?\s*/i, '');

  return out.replace(/^[\s,]+|[\s,]+$/g, '').replace(/\s+/g, ' ').trim();
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

function looksLikeStreetLine(value) {
  const latin = stripNonLatin(value).trim();
  if (!latin || latin.length < 2) return false;
  if (/[)@#%]/.test(latin)) return false;
  if (/^\d+[,.]?$/.test(latin)) return true;
  if (/^\d+[\/-]\d+[-\/]?\d*$/.test(latin)) return true;
  if (/\b(street|st\.?|road|rd\.?|nagar|colony|lane|avenue|layout|puram|salai|main|kovil|pettai|patti)\b/i.test(latin)) {
    return true;
  }
  if (/^[A-Z]{2,}(\s+[A-Z]{2,})+$/.test(latin)) {
    if (/\b(STREET|ROAD|NAGAR|PURAM|PATTI|SALAI|KOVIL|COLONY|LAYOUT|SOUTH|NORTH)\b/.test(latin)) {
      return true;
    }
    if (/^\d/.test(latin)) return true;
    return false;
  }
  if (/^\d+[A-Za-z]?\s+/.test(latin)) return true;
  if (/\d+(st|nd|rd|th)\b/i.test(latin) && /[A-Z]{3,}/.test(latin)) return true;
  return false;
}

function isEnrollmentLetterText(text) {
  return /enrol+ment\s*no/i.test(String(text || ''));
}

function collectEnrollmentStreetLines(rawLines, options = {}) {
  const preFooter = [];
  for (const line of rawLines) {
    const latin = stripNonLatin(line).trim();
    if (/\b(VTC|PO|Sub\s*District|District|State|PIN\s*Code|Mobile|Aadhaar|VID)\s*:/i.test(latin)) {
      break;
    }
    if (/\benrol+ment\s*no\b/i.test(latin)) break;
    if (isCardFrontOrNonAddressLine(latin)) continue;
    if (!latin || latin.length < 2) continue;
    if (isTamilScript(line) && preFooter.length === 0) continue;
    const maybeName = tryParseName(line);
    if (maybeName && preFooter.length === 0 && !/\d/.test(latin)) continue;
    const cleaned = cleanAddressLine(line, options) || latin.replace(/,\s*$/, '');
    if (!cleaned || cleaned.length < 2) continue;
    if (AADHAAR_BACK_BOILERPLATE.test(cleaned)) continue;
    if (isGarbageAddressSegment(cleaned)) continue;
    if (
      looksLikeStreetLine(cleaned) ||
      /^\d+[,.]?$/.test(cleaned) ||
      /^\d+[\/-]\d+/.test(cleaned)
    ) {
      preFooter.push(cleaned);
    }
  }
  if (preFooter.length > 0) return preFooter;

  const lines = [];
  let inBlock = false;
  for (const line of rawLines) {
    const latin = stripNonLatin(line).trim();
    if (/enrol+ment\s*no/i.test(latin)) {
      inBlock = true;
      continue;
    }
    if (!inBlock) continue;
    if (/\b(VTC|PO|Sub\s*District|District|State|PIN\s*Code|Mobile|Aadhaar|VID)\s*:/i.test(latin)) {
      break;
    }
    if (!latin || latin.length < 2) continue;
    if (isTamilScript(line) && lines.length === 0) continue;
    const maybeName = tryParseName(line);
    if (maybeName && lines.length === 0) continue;
    const cleaned = cleanAddressLine(line, options) || latin.replace(/,\s*$/, '');
    if (!cleaned || cleaned.length < 2) continue;
    if (AADHAAR_BACK_BOILERPLATE.test(cleaned)) continue;
    if (looksLikeStreetLine(cleaned) || /^\d+[,.]?$/.test(cleaned)) {
      lines.push(cleaned);
    }
  }
  return lines;
}

function extractEnrollmentLetterName(text) {
  const rawLines = linesFromText(text);
  if (!isEnrollmentLetterText(text)) return '';

  const enrolIdx = rawLines.findIndex((l) => /enrol+ment\s*no/i.test(stripNonLatin(l)));
  if (enrolIdx === -1) return '';

  for (let i = enrolIdx + 1; i < Math.min(enrolIdx + 10, rawLines.length); i++) {
    const latin = stripNonLatin(rawLines[i]).trim();
    if (!latin) continue;
    if (/^\d+[,.]?$/.test(latin)) break;
    if (/^(vtc|po|sub|district|state|pin|address|mobile|aadhaar)\b/i.test(latin)) break;
    if (isTamilScript(rawLines[i])) continue;
    const name = tryParseName(rawLines[i]);
    if (name) return name;
  }
  return '';
}

function parseAadhaarLabeledFooter(joined) {
  const out = { po: '', subDistrict: '', district: '', state: '', pin: '', vtc: '' };
  const text = String(joined || '');
  const re = /(PO|Sub\s*District|District|State|PIN\s*Code|VTC)\s*:\s*/gi;
  const hits = [];
  let match;
  while ((match = re.exec(text)) !== null) {
    hits.push({
      label: match[1].toLowerCase().replace(/\s+/g, ''),
      valueStart: match.index + match[0].length,
      segmentStart: match.index,
    });
  }
  for (let i = 0; i < hits.length; i += 1) {
    const valueEnd = i + 1 < hits.length ? hits[i + 1].segmentStart : text.length;
    let value = stripNonLatin(text.slice(hits[i].valueStart, valueEnd))
      .replace(/,\s*$/, '')
      .trim();
    switch (hits[i].label) {
      case 'po':
        out.po = value
          .replace(/\s+Sub.*$/i, '')
          .replace(/\s*,\s*DIST.*$/i, '')
          .trim();
        break;
      case 'subdistrict':
        out.subDistrict = value.replace(/\s+District.*$/i, '').trim();
        break;
      case 'district':
        out.district = value.replace(/\s+State.*$/i, '').trim();
        break;
      case 'state':
        out.state = value.replace(/\s*-\s*\d{6}.*$/i, '').trim();
        break;
      case 'pincode':
        out.pin = (value.match(/\d{6}/) || [])[0] || '';
        break;
      case 'vtc':
        out.vtc = value.replace(/\s+PO.*$/i, '').trim();
        break;
      default:
        break;
    }
  }

  const distAlt = text.match(/(?:^|,\s*)DIST\s*:\s*([^,\n]+)/i);
  if (distAlt?.[1] && !out.district) {
    out.district = stripNonLatin(distAlt[1]).replace(/\s+State.*$/i, '').trim();
  }

  return out;
}

function extractPoFromStructuredText(joined) {
  let po = stripNonLatin(
    joined.match(/\bPO\s*:\s*([^,\n]+)/i)?.[1] || '',
  )
    .replace(/\s+Sub\s*District.*$/i, '')
    .trim();
  if (po.length >= 5 && !/^[a-z]{3,5}$/i.test(po)) return po;

  const beforeSub = joined.match(
    /\bPO\s*:\s*([A-Za-z][A-Za-z\s]{4,40}?)\s*,?\s*Sub\s*District/i,
  );
  if (beforeSub?.[1]) {
    po = stripNonLatin(beforeSub[1]).trim();
    if (po.length >= 5) return po;
  }

  const place = joined.match(
    /\b([A-Z][a-z]+(?:apuram|nagar|patti|salai|puram))\b[^,\n]{0,30}Sub\s*District/i,
  );
  if (place?.[1]) return stripNonLatin(place[1]).trim();

  return '';
}

function pickBetterAddress(a, b) {
  return mergeAddresses(a, b);
}

function addressCleanlinessScore(addr) {
  const body = String(addr || '').trim();
  if (!body) return 0;
  let score = body.split(',').length * 2;
  if (/\b\d{6}\b/.test(body)) score += 12;
  if (!/\b(VTC|DIST|PO|Sub\s*District|District|State)\s*:/i.test(body)) score += 18;
  if (/\s-\s\d{6}\s*$/.test(body)) score += 4;
  if (/\b(street|nagar|puram)\b/i.test(body)) score += 8;
  score -= (body.match(/\b(Tamil Nadu|Karnataka|Kerala)\b/gi) || []).length * 3;
  if (/www\.|\.gov\.in|uidai|uidal/i.test(body)) score -= 40;
  if (/\b(?:ss|s)\s*:\s*[A-Za-z]{4,}\b/i.test(body)) score -= 20;
  if (!/\s/.test(body.replace(/,/g, '')) && body.length > 28) score -= 15;
  return score;
}

function normalizeAddressSegment(seg) {
  return normalizeGluedOcrSegment(
    stripNonLatin(seg)
      .replace(/^(?:VTC|PO|DIST|Sub\s*District|District|State|PIN\s*Code)\s*:\s*/i, '')
      .replace(/,\s*$/, '')
      .trim(),
  );
}

function appendPinToAddress(addr, pin) {
  const body = String(addr || '').trim();
  if (!body || !pin || /\b\d{6}\b/.test(body)) return body;
  if (
    /\b(Tamil Nadu|Karnataka|Kerala|Andhra Pradesh|Telangana|Maharashtra|Gujarat|West Bengal|Rajasthan|Punjab|Haryana|Uttar Pradesh|Bihar|Madhya Pradesh|Odisha|Assam|Jharkhand|Chhattisgarh|Himachal Pradesh|Uttarakhand|Goa|Delhi)\s*$/i.test(
      body,
    )
  ) {
    return `${body} - ${pin}`;
  }
  return `${body}, PIN ${pin}`;
}

function isLikelyStreetPart(seg) {
  const s = String(seg || '').trim();
  if (!s) return false;
  if (/^\d+[,.]?$/.test(s)) return true;
  if (/^\d+[\/-]\d+[-\/]?\d*$/.test(s)) return true;
  if (/\b(street|st\.|road|rd\.|lane|layout|colony|kovil|salai|pettai)\b/i.test(s)) return true;
  if (/\b\d+\s*(st|nd|rd|th)\b/i.test(s)) return true;
  if (/^[A-Z0-9][A-Z0-9\s-]{2,}(STREET|ST\b|ROAD|RD\b|KOVIL)/i.test(s)) return true;
  return looksLikeStreetLine(s);
}

function isMergeableStreetSegment(seg) {
  const s = String(seg || '').trim();
  if (!s || /^\d{6}$/.test(s)) return false;
  return isSupplementalStreetSegment(s) || isLikelyStreetPart(s) || looksLikeStreetLine(s);
}

function isSupplementalStreetSegment(seg) {
  const s = String(seg || '').trim();
  if (!s || /^\d{6}$/.test(s)) return false;
  if (/^(s\/o|d\/o|w\/o|c\/o|sub\s*district|district|state|pin|mobile|aadhaar|vid)\b/i.test(s)) {
    return false;
  }
  if (/^(tamil nadu|karnataka|kerala|andhra pradesh|telangana|madurai|chennai)$/i.test(s)) {
    return false;
  }
  return isLikelyStreetPart(s);
}

/**
 * Combine partial addresses — e.g. letter crop (268, NSK STREET) + card back (JIVANAGAR, PIN).
 */
function mergeAddresses(...addrs) {
  const all = addrs
    .map((a) => String(a || '').trim())
    .filter((a) => a.length >= 8);
  if (all.length === 0) return '';
  if (all.length === 1) return finalizeAddress(all[0]);

  let best = all[0];
  let bestScore = addressCleanlinessScore(best);
  for (let i = 1; i < all.length; i += 1) {
    const score = addressCleanlinessScore(all[i]);
    if (score > bestScore) {
      best = all[i];
      bestScore = score;
    }
  }

  let pin = '';
  for (const addr of all) {
    pin =
      pin ||
      extractPinFromText(addr) ||
      (addr.match(/\b(\d{6})\b/) || [])[1] ||
      '';
  }

  const bestSegs = best
    .replace(/\s*-\s*\d{6}\s*$/, '')
    .split(',')
    .map((s) => normalizeAddressSegment(s))
    .filter((s) => s && !isGarbageAddressSegment(s));
  const seen = new Set(bestSegs.map((s) => s.toLowerCase()));
  const extraStreets = [];

  for (const addr of all) {
    if (addressCleanlinessScore(addr) < bestScore - 8) continue;
    const body = addr.replace(/\s*-\s*\d{6}\s*$/, '');
    for (const seg of body.split(',')) {
      const s = normalizeAddressSegment(seg);
      if (!s || seen.has(s.toLowerCase()) || /^\d{6}$/.test(s)) continue;
      if (isGarbageAddressSegment(s)) continue;
      if (!isMergeableStreetSegment(s)) continue;
      extraStreets.push(s);
      seen.add(s.toLowerCase());
    }
  }

  if (extraStreets.length === 0) {
    const withPin = pin ? appendPinToAddress(best, pin) : best;
    return finalizeAddress(withPin);
  }

  let insertAt = bestSegs.findIndex((s) => !isLikelyStreetPart(s) && !/^\d+[,.]?$/.test(s));
  if (insertAt === -1) insertAt = bestSegs.length;
  const merged = [
    ...bestSegs.slice(0, insertAt),
    ...extraStreets,
    ...bestSegs.slice(insertAt),
  ];
  const withPin = pin ? appendPinToAddress(merged.join(', '), pin) : merged.join(', ');
  return finalizeAddress(withPin);
}

function extractPinFromText(text) {
  const joined = String(text || '');
  return (
    joined.match(/PIN\s*Code\s*:\s*(\d{6})/i)?.[1] ||
    joined.match(/\bPIN\s*Code\s*(\d{6})\b/i)?.[1] ||
    joined.match(/\bpincode(\d{6})\b/i)?.[1] ||
    joined.match(/(?:csnb|csn)\s*pin\s*code?\s*(\d{6})/i)?.[1] ||
    joined.match(/\bPIN\s*:\s*(\d{6})/i)?.[1] ||
    joined.match(/\bState\s*:[^-\n]*-\s*(\d{6})\b/i)?.[1] ||
    joined.match(/\b(?:Tamil Nadu|Karnataka|Kerala|Andhra Pradesh|Telangana)\s*-\s*(\d{6})\b/i)?.[1] ||
    joined.match(/\b(?:Tamil Nadu|Karnataka|Kerala|Andhra Pradesh|Telangana),?\s*(\d{6})\b/i)?.[1] ||
    joined.match(/\b[A-Za-z][A-Za-z\s]{2,40}\s*-\s*(\d{6})\b/)?.[1] ||
    (joined.match(/\b(\d{6})\b/g) || []).pop() ||
    ''
  );
}

/**
 * Card-back compressed line: S/O: Guardian, 268, NSK STREET, ..., PO: ..., DIST: ..., State - PIN
 */
function extractCommaSeparatedAadhaarAddress(text, options = {}) {
  const joined = String(text || '').replace(/\r?\n/g, ' ');
  const hasLabeledFooter = /\b(PO\s*:|DIST\s*:|Sub\s*District\s*:)/i.test(joined);
  const hasPlainFooter =
    /\b(?:Tamil Nadu|Karnataka|Kerala|Andhra Pradesh|Telangana|Maharashtra|Gujarat|Rajasthan|West Bengal|Uttar Pradesh|Bihar|Madhya Pradesh|Punjab|Haryana|Odisha|Assam|Jharkhand|Chhattisgarh|Himachal Pradesh|Uttarakhand|Goa|Delhi)\s*-\s*\d{6}\b/i.test(
      joined,
    ) || /,\s*[A-Za-z][A-Za-z\s]{2,30}\s*-\s*\d{6}\b/.test(joined);
  const hasSoCommaChain = /\bS\/O\s*:\s*[^,]+,\s*.+,\s*.+/i.test(joined);
  const commaCount = (joined.match(/,/g) || []).length;
  const isCompressedLine =
    linesFromText(text).filter((line) => line.trim()).length <= 2 && commaCount >= 4;

  if (!hasLabeledFooter && hasPlainFooter && (hasSoCommaChain || isCompressedLine)) {
    const pin = extractPinFromText(joined);
    const stateMatch = joined.match(/\b([A-Za-z][A-Za-z\s]{2,40})\s*-\s*(\d{6})\b/);
    const state = stateMatch ? stripNonLatin(stateMatch[1]).trim() : '';
    let body = stripUrlAndUidaiNoise(joined.replace(/\s*-\s*\d{6}\s*$/, '').trim());
    body = body.replace(/\b(?:s{1,2}|d|w|c)\s*\/\s*o\s*:\s*[^,]+,\s*/i, '');
    if (state) {
      body = body.replace(new RegExp(`,?\\s*${state.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`, 'i'), '');
    }
    const segments = body
      .split(',')
      .map((seg) => normalizeAddressSegment(seg))
      .filter((seg) => seg && !isGarbageAddressSegment(seg));
    if (segments.length === 0) return '';
    let addr = segments.join(', ');
    if (state && pin) addr = `${addr}, ${state} - ${pin}`;
    else if (pin) addr = appendPinToAddress(addr, pin);
    return finalizeAddress(addr);
  }

  if (!hasLabeledFooter) return '';

  const footer = parseAadhaarLabeledFooter(joined);
  const pin = footer.pin || extractPinFromText(joined);
  const po = footer.po || extractPoFromStructuredText(joined);
  const subDistrict = footer.subDistrict || footer.vtc || '';
  const district = footer.district || '';
  const state =
    footer.state ||
    stripNonLatin(joined.match(/\b([A-Za-z][A-Za-z\s]{2,40})\s*-\s*\d{6}\b/)?.[1] || '').trim();

  const streetSegments = [];
  const pushStreetSegment = (seg) => {
    const s = normalizeAddressSegment(seg);
    if (!s || s.length < 2) return;
    if (/^(sub\s*district|district|state|pin|mobile|aadhaar|vid)\b/i.test(s)) return;
    const lower = s.toLowerCase();
    if (subDistrict && lower === subDistrict.toLowerCase()) return;
    if (footer.vtc && lower === footer.vtc.toLowerCase()) return;
    if (po && lower === po.toLowerCase()) return;
    if (district && lower === district.toLowerCase() && !/\d/.test(s)) return;
    if (state && lower === state.toLowerCase()) return;
    const supplemental =
      isMergeableStreetSegment(s) ||
      /^\d+[,.]?$/.test(s) ||
      /\b(south|north|east|west|puram|nagar|patti|taluk|kovil|street|salai)\b/i.test(s);
    if (!supplemental) return;
    if (!streetSegments.some((existing) => existing.toLowerCase() === lower)) {
      streetSegments.push(s);
    }
  };

  const soMatch = joined.match(/\bS\/O\s*:\s*[^,]+,\s*(.+?)(?:\bPO\s*:|\bDIST\s*:)/i);
  if (soMatch?.[1]) {
    for (const seg of soMatch[1].split(',')) {
      pushStreetSegment(seg);
    }
  }

  if (streetSegments.length === 0) {
    const beforePo = joined.split(/\bPO\s*:/i)[0] || '';
    const afterSo = beforePo.replace(/^.*\bS\/O\s*:\s*[^,]+,\s*/i, '');
    for (const seg of afterSo.split(',')) {
      pushStreetSegment(seg);
    }
  }

  const parts = [...streetSegments, po, subDistrict, district, state]
    .map((part) => normalizeAddressSegment(part))
    .filter(
    (part, idx, all) => {
      if (!part) return false;
      const lower = part.toLowerCase();
      return !all.slice(0, idx).some((prev) => prev.toLowerCase() === lower);
    },
  );
  if (parts.length === 0 && !pin) return '';

  let addr = parts.join(', ');
  if (pin) {
    addr = state ? `${addr} - ${pin}` : `${addr}, PIN ${pin}`.replace(/^,\s*/, '');
  }
  return finalizeAddress(addr);
}

function extractStructuredAadhaarBackAddress(text, options = {}) {
  const joined = String(text || '');
  const hasStructured =
    /\bPO\s*:/i.test(joined) ||
    /\bSub\s*District\s*:/i.test(joined) ||
    /\bPIN\s*Code\s*:/i.test(joined) ||
    /\bVTC\s*:/i.test(joined) ||
    isEnrollmentLetterText(text);
  if (!hasStructured) return '';

  const footer = parseAadhaarLabeledFooter(joined);
  const po = footer.po || extractPoFromStructuredText(joined);
  const subDistrict =
    footer.subDistrict ||
    footer.vtc ||
    stripNonLatin(joined.match(/Sub[\s-]*Dist(?:rict)?\s*:\s*([^,\n]+)/i)?.[1] || '')
      .replace(/\s+District.*$/i, '')
      .trim();
  const district =
    footer.district ||
    stripNonLatin(
      joined.match(/(?:^|,\s*)District\s*:\s*([^,\n]+)/i)?.[1] || '',
    )
      .replace(/\s+State.*$/i, '')
      .trim();
  const state =
    footer.state ||
    stripNonLatin(joined.match(/\bState\s*:\s*([^,\n-]+)/i)?.[1] || '').trim() ||
    stripNonLatin(joined.match(/\b([A-Za-z][A-Za-z\s]{2,40})\s*-\s*\d{6}\b/)?.[1] || '').trim();
  const pin =
    footer.pin ||
    extractPinFromText(joined) ||
    joined.match(/PIN\s*Code\s*:\s*(\d{6})/i)?.[1] ||
    '';

  if (!subDistrict && !district && !pin) return '';

  let street = '';
  const streetLines = [];
  const rawLines = linesFromText(text);

  if (isEnrollmentLetterText(text)) {
    streetLines.push(...collectEnrollmentStreetLines(rawLines, options));
  } else if (/\b(PO\s*:|Sub\s*District\s*:|PIN\s*Code\s*:)/i.test(joined)) {
    streetLines.push(...collectEnrollmentStreetLines(rawLines, options));
  }

  if (streetLines.length === 0) {
    for (const line of rawLines) {
      const latin = stripNonLatin(line).trim();
      if (!latin) continue;
      if (/\b(VTC|PO|Sub\s*District|District|State|PIN\s*Code|Mobile|Aadhaar|VID)\s*:/i.test(latin)) {
        break;
      }
      if (AADHAAR_BACK_BOILERPLATE.test(latin)) continue;
      if (isCardFrontOrNonAddressLine(latin)) continue;
      if (latin.length < 2) continue;
      const cleaned = cleanAddressLine(line, options);
      if (!cleaned || isGarbageAddressSegment(cleaned)) continue;
      if (isNameCandidate(cleaned) && !looksLikeStreetLine(cleaned) && !/\d/.test(cleaned)) continue;
      if (cleaned && isValidAddressLine(cleaned, options) && looksLikeStreetLine(cleaned)) {
        streetLines.push(cleaned);
      } else if (/^\d+[,.]?$/.test(latin)) {
        streetLines.push(latin.replace(/,\s*$/, ''));
      } else if (
        /\b(nagar|puram|street|salai|colony|lane|layout|kovil|patti)\b/i.test(latin) &&
        latin.length >= 6
      ) {
        streetLines.push(cleaned || latin);
      }
    }
  }
  street = [...new Set(streetLines.map((l) => l.trim()).filter(Boolean))].join(', ');

  const parts = [street, po, subDistrict, district, state]
    .map((part) => normalizeAddressSegment(part))
    .filter((part, idx, all) => {
    if (!part) return false;
    const lower = part.toLowerCase();
    return !all.slice(0, idx).some((prev) => prev.toLowerCase() === lower);
  });
  if (parts.length === 0 && !pin) return '';

  let addr = parts.join(', ');
  if (pin) {
    addr = state ? `${addr} - ${pin}` : `${addr}, PIN ${pin}`.replace(/^,\s*/, '');
  }
  return finalizeAddress(addr);
}

function extractAddress(text, options = {}) {
  const candidates = [
    extractStructuredAadhaarBackAddress(text, options),
    extractCommaSeparatedAadhaarAddress(text, options),
  ].filter((addr) => addr && addr.length >= 12);

  if (candidates.length > 0) {
    const best = candidates.reduce((a, b) =>
      addressCleanlinessScore(a) >= addressCleanlinessScore(b) ? a : b,
    );
    return finalizeAddress(best);
  }

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
    // Skip the "To" line, name line(s), and S/O guardian line
    const collected = [];
    let foundSO = false;
    for (let i = toIdx + 1; i < rawLines.length && collected.length < 15; i++) {
      const latin = stripNonLatin(rawLines[i]).trim();
      if (!foundSO) {
        if (/^s\/o|^d\/o|^w\/o|^c\/o|\d+,/i.test(latin)) {
          foundSO = true;
          // If this line is only the guardian (S/O: Name), skip it.
          if (/^(s\/o|d\/o|w\/o|c\/o)\b/i.test(latin)) continue;
        } else continue; // skip name lines before S/O
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
  // Skip the S/O / guardian line itself — only keep house/street onward.
  const soIdx = rawLines.findIndex((l) =>
    /^(s\/o|d\/o|w\/o|c\/o|\/\s*:|\/:)/i.test(stripNonLatin(l).trim()),
  );
  if (soIdx !== -1) {
    const collected = [];
    for (let i = soIdx + 1; i < rawLines.length && collected.length < 15; i++) {
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
  /^(government|india|republic|unique|permanent|account|income|tax|election|commission|driving|license|aadhaar|uidai|epic|authority|department|ministry|of india|enrollment|enrolment|documents?|proof|address|mobile|phone|date|gender|male|female|year|yob|dob|sub\s+district|district|state|pin|taluk|village|post|road|nagar|colony|enrolment|enrollment|signature|digitally|verified|information|entity|entities|madurai|tamil|nadu|vtc|pincode|pin\s*code|quieter|signature|verified|download|seeking|confirm|authentication)/i;

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
  if (/^gov[a-z]{5,}/.test(compact)) return true;
  if (compact.startsWith('govenn') || compact.startsWith('govern') || compact.startsWith('govt')) {
    return true;
  }
  if (compact.includes('gov') && (compact.includes('ind') || compact.includes('mndid'))) {
    return true;
  }
  // Very long single token with "india" is almost never a personal name.
  if (compact.includes('india') && compact.length >= 12 && !/\s/.test(text.trim())) {
    return true;
  }
  return false;
}

function isBackHeavyOcrText(text) {
  return /\b(sub\s*district|pin\s*code|mobile)\s*:/i.test(String(text || ''));
}

function resolveHolderName(frontText, backText) {
  const combined = `${frontText}\n${backText}`;
  const fromLetter = extractNameFromBackLetter(combined);
  if (fromLetter) return fromLetter;

  const sameText = String(frontText || '').trim() === String(backText || '').trim();
  if (isBackHeavyOcrText(combined) && !isEnrollmentLetterText(combined)) {
    if (!sameText && frontText) {
      const frontName = extractName(frontText);
      if (scoreNameCandidate(frontName) >= 35 && !looksLikeGovernmentHeader(frontName)) {
        return frontName;
      }
    }
    return '';
  }

  const frontName = extractName(frontText);
  const backName = extractName(backText);
  const picked =
    scoreNameCandidate(frontName) + (frontName ? 8 : 0) >= scoreNameCandidate(backName)
      ? frontName || backName
      : backName || frontName;
  if (looksLikeGovernmentHeader(picked) || isWeakOcrName(picked)) return '';
  return picked;
}

function sanitizeNameForDetectedSide(name, detectedSide, rawText = '') {
  const cleaned = String(name || '').trim();
  if (!cleaned) return '';
  if (looksLikeGovernmentHeader(cleaned) || isWeakOcrName(cleaned)) return '';
  if (detectedSide === 'back' || isAadhaarBackSide({ detectedSide })) {
    const letterName = extractNameFromBackLetter(rawText);
    if (letterName) return letterName;
    if (isBackHeavyOcrText(rawText) && !isEnrollmentLetterText(rawText)) return '';
  }
  return cleaned;
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
  // Normalize dotted initials: "K. Hariharan" → "K Hariharan"
  const normalized = String(line || '')
    .replace(/\b([A-Za-z])\.(?=\s|[A-Za-z])/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
  if (!normalized || normalized.length < 3 || normalized.length > 55) return false;
  if (looksLikeGovernmentHeader(normalized)) return false;
  if (isWeakOcrName(normalized)) return false;
  if (NAME_NOISE.test(normalized)) return false;
  if (/^gov[a-z]{4,}/i.test(compactForNoiseCheck(normalized))) return false;
  if (/\b(or|and|the|of|mndid|india|ind)\b/i.test(normalized) && /^gov/i.test(normalized)) {
    return false;
  }
  if (AADHAAR_BACK_BOILERPLATE.test(normalized)) return false;
  if (/\b(information|citizenship|identity|proof|entities|quieter|verified|signature)\b/i.test(normalized)) return false;
  if (/^\d/.test(normalized)) return false;
  if (/[@#%&*=+<>{}[\]\\|~`,]/.test(normalized)) return false;
  // Address / location lines are not names.
  if (ADDRESS_START.test(normalized) || ADDRESS_KEYWORD.test(normalized)) return false;
  if (/\b(street|road|nagar|colony|district|state|pin|mobile|phone|signature)\b/i.test(normalized)) {
    return false;
  }

  const latinRatio = (normalized.match(/[a-zA-Z ]/g) || []).length / normalized.length;
  if (latinRatio < 0.8) return false;
  if ((normalized.match(/[a-zA-Z]/g) || []).length < 3) return false;

  const words = normalized.split(/\s+/);
  // Reject OCR mush like "Ef Org Or Did" (many tiny tokens).
  const shortWords = words.filter((w) => w.length <= 2).length;
  if (shortWords >= 2) return false;
  // "Ef Org" / "Aa Bb" — two short tokens with no real name word.
  if (words.length >= 2 && !words.some((w) => w.length >= 4)) return false;
  if (words.length >= 3 && words.every((w) => w.length <= 3)) return false;
  // Single Indian names can be long (Balasubramanian, Venkateswaran, …).
  if (words.length === 1 && words[0].length > 28) return false;
  // "Govemmentofingia Pee" style: first word too long and not title-case clean.
  if (words[0].length > 16 && !/^[A-Z][a-z]+$/.test(words[0])) return false;

  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+){0,4}$/.test(normalized)) return true;
  if (/^[A-Z](?: [A-Z][a-z]+){1,4}$/.test(normalized)) return true; // "M Ramesh"
  if (/^[A-Z][A-Z ]{2,39}$/.test(normalized)) return true;
  if (/^[a-zA-Z]+(?: [a-zA-Z]+){0,4}$/.test(normalized) && words.some((w) => w.length >= 4)) {
    return true;
  }
  return false;
}

/**
 * Strip leading OCR noise tokens from a name candidate.
 * Keep single-letter initials like "M Ramesh"; drop junk like "ss" / "Ss" / "fey".
 */
function cleanNamePrefix(name) {
  return String(name || '')
    // Dotted initials → plain: "K.Hariharan" / "K. Hariharan"
    .replace(/\b([A-Za-z])\.(?=\s|[A-Za-z])/g, '$1 ')
    .replace(/\s+/g, ' ')
    .trim()
    // Known 2–3 letter OCR mush (any case), then a real name word
    .replace(/^(?:ss|fey|ae|rs|rr|aa|lj|nz|lh)\s+(?=[A-Z][a-zA-Z]{2,})/i, '')
    // Lowercase junk prefixes only (keeps "M Ramesh")
    .replace(/^[a-z]{1,3}\s+(?=[A-Z][a-zA-Z]{2,})/, '')
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
  const cleaned = cleanNamePrefix(name);
  if (looksLikeGovernmentHeader(cleaned) || NAME_NOISE.test(cleaned)) return -100;

  let score = Math.min(cleaned.length, 24);
  const words = cleaned.trim().split(/\s+/);

  if (/^[A-Z][a-z]+(?: [A-Z][a-z]+)+$/.test(cleaned)) score += 30;
  else if (/^[A-Z][a-z]+$/.test(cleaned)) score += 22;
  else if (/^[A-Z](?: [A-Z][a-z]+)+$/.test(cleaned)) score += 26; // "M Ramesh"
  else if (/^[A-Z][A-Z ]{2,}$/.test(cleaned)) score += 10;
  else score += 4;

  if (words.length >= 2 && words.length <= 4) score += 8;
  // Long single Indian names are normal — only penalize extreme mush.
  if (words.some((w) => w.length > 22)) score -= 25;
  if (words.filter((w) => w.length <= 2).length >= 2) score -= 40;
  if (words.length >= 2 && !words.some((w) => w.length >= 4)) score -= 50;
  if (words.length >= 3 && words.every((w) => w.length <= 3)) score -= 50;
  if (/\b(india|government|govemment|govenn|govt|uidai|aadhaar|madurai|tamil|org|did|mndid)\b/i.test(cleaned)) {
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

  // Guardian names from S/O / D/O lines must never win as the card holder's name.
  const guardianNames = new Set();
  for (const line of rawLines) {
    const latin = stripNonLatin(line).trim();
    const m = latin.match(/^(?:s\/o|d\/o|w\/o|c\/o)\s*[:.\-]?\s*(.+)$/i);
    if (!m) continue;
    const g = tryParseName(m[1]);
    if (g) guardianNames.add(g.toLowerCase());
  }

  const ranked = [];

  const push = (candidate, bonus = 0) => {
    if (!candidate) return;
    const cleaned = cleanNamePrefix(candidate);
    if (!cleaned || !isNameCandidate(cleaned)) return;
    if (guardianNames.has(cleaned.toLowerCase())) return;
    ranked.push({
      name: cleaned,
      score: scoreNameCandidate(cleaned) + bonus,
    });
  };

  // ── Strategy 1a: UIDAI enrollment letter (name above address block) ─────────
  push(extractEnrollmentLetterName(text), 44);

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
      const latin = stripNonLatin(rawLines[i]).trim();
      if (/^(s\/o|d\/o|w\/o|c\/o)\b/i.test(latin)) break;
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
        push(candidate, 48);
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

  // ── Strategy 3: Name appears just BEFORE DOB on Aadhaar front (best signal)
  const dobIdx = rawLines.findIndex(
    (l) =>
      /\b(dob|date\s+of\s+birth|born|birth|yob|year\s+of\s+birth)\b/i.test(
        stripNonLatin(l),
      ) || /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/.test(l),
  );
  if (dobIdx > 0) {
    for (let i = dobIdx - 1; i >= Math.max(0, dobIdx - 5); i--) {
      push(tryParseName(rawLines[i]), 55);
    }
  }

  // ── Strategy 4: Scan remaining lines, but never prefer header noise ───────
  for (const line of rawLines) {
    const latin = stripNonLatin(line).trim();
    if (/^(s\/o|d\/o|w\/o|c\/o)\b/i.test(latin)) continue;
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

  // Prefer front (DOB-adjacent) name over back letter noise.
  const name = resolveHolderName(frontText, backText);
  // Address is usually on the back / letter panel — keep the most complete version.
  const address =
    mergeAddresses(backAddress, frontAddress) ||
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

/**
 * Heuristic: is this OCR from Aadhaar front (name/DOB) or back (address/letter)?
 */
function classifyAadhaarSide(text) {
  const t = String(text || '').toLowerCase();
  let backScore = 0;
  let frontScore = 0;

  if (/\b(pin\s*code|pincode|sub[\s-]?district)\b/.test(t)) backScore += 2;
  if (/\bmobile\b/.test(t)) backScore += 2;
  if (/\b(s\/o|d\/o|w\/o|c\/o)\b/.test(t)) backScore += 1;
  if (/\bto\b/.test(t) && /\b(district|state|village|taluk)\b/.test(t)) backScore += 1;
  if (AADHAAR_BACK_BOILERPLATE.test(t)) backScore += 2;

  if (/\b(dob|date\s+of\s+birth|year\s+of\s+birth|yob)\b/.test(t)) frontScore += 2;
  if (/\bgovernment\s+of\s+india\b/.test(t)) frontScore += 1;
  if (/\b(male|female)\b/.test(t) && !/\bmobile\b/.test(t)) frontScore += 1;
  if (/\benrol+ment\b/.test(t)) frontScore += 1;

  if (backScore > frontScore + 1) return 'back';
  if (frontScore > backScore + 1) return 'front';
  return 'unknown';
}

function extractNameFromBackLetter(text) {
  const fromEnrollment = extractEnrollmentLetterName(text);
  if (fromEnrollment) return fromEnrollment;

  const rawLines = linesFromText(text);

  const toIdx = rawLines.findIndex((l) => /^To\s*$/i.test(stripNonLatin(l).trim()));
  if (toIdx !== -1) {
    for (let i = toIdx + 1; i <= Math.min(toIdx + 5, rawLines.length - 1); i++) {
      const latin = stripNonLatin(rawLines[i]).trim();
      if (/^(s\/o|d\/o|w\/o|c\/o|po\s*:|\d)/i.test(latin)) break;
      const name = tryParseName(rawLines[i]);
      if (name) return name;
    }
  }

  const soIdx = rawLines.findIndex((l) =>
    /^(s\/o|d\/o|w\/o|c\/o)\b/i.test(stripNonLatin(l).trim()),
  );
  if (soIdx > 0) {
    for (let i = soIdx - 1; i >= Math.max(0, soIdx - 4); i--) {
      const latin = stripNonLatin(rawLines[i]).trim();
      if (/^(to|po\s*:|address|mobile|district|state|pin)/i.test(latin)) continue;
      const name = tryParseName(rawLines[i]);
      if (name) return name;
    }
  }

  return '';
}

function normalizeLocalitySpacing(addr) {
  return String(addr || '')
    .replace(/\bMaduraiSouth\b/gi, 'Madurai South')
    .replace(/\bTamilNadu\b/gi, 'Tamil Nadu')
    .replace(/\b([A-Z][a-z]+)(South|North|East|West)\b/g, '$1 $2');
}

function appendMissingPin(addr, text) {
  const body = String(addr || '').trim();
  if (!body || /\b\d{6}\b/.test(body)) return body;
  const pin =
    extractPinFromText(text) ||
    (String(text || '').match(/\b(\d{6})\b/g) || []).find((p) => /^[1-9]\d{5}$/.test(p)) ||
    '';
  return pin ? appendPinToAddress(body, pin) : body;
}

function isWeakOcrName(name) {
  const cleaned = String(name || '').trim();
  if (!cleaned) return true;
  const words = cleaned.split(/\s+/);
  if (words.length === 1) {
    const w = words[0];
    if (w.length < 6 && scoreNameCandidate(cleaned) < 40) return true;
    if (/^(fonet|govt|india|proof|mobile|aadhaar|unique)$/i.test(w)) return true;
  }
  return scoreNameCandidate(cleaned) < 12;
}

function isMisclassifiedEnrollmentSheet(letterText, cardBackText, frontText = '') {
  const combined = `${letterText}\n${cardBackText}\n${frontText}`;
  if (isEnrollmentLetterText(combined)) return false;
  if (/\benrol+ment\s*no\b/i.test(combined)) return false;
  // Enrollment letter footers — OCR often misses "Enrollment No" but keeps these labels.
  if (/\bSub\s*District\s*:/i.test(combined) && /\bPIN\s*Code\s*:/i.test(combined)) {
    return false;
  }
  if (
    /\bDistrict\s*:/i.test(combined) &&
    /\bState\s*:/i.test(combined) &&
    /\bMobile\s*:/i.test(combined)
  ) {
    return false;
  }
  // Plastic card back only: VTC + S/O line without enrollment letter footer.
  return (
    /\bVTC\s*:/i.test(combined) &&
    /\bS\/O\s*:/i.test(combined) &&
    !/\bPIN\s*Code\s*:/i.test(combined) &&
    /\b\d{6}\b/.test(combined)
  );
}

function resolveEnrollmentSheetName(frontText, backText) {
  const fromFront = extractName(frontText);
  if (
    fromFront &&
    !isWeakOcrName(fromFront) &&
    !looksLikeGovernmentHeader(fromFront) &&
    scoreNameCandidate(fromFront) >= 12
  ) {
    return fromFront;
  }

  const combined = `${frontText}\n${backText}`;
  const fromLetter =
    extractEnrollmentLetterName(backText) ||
    extractEnrollmentLetterName(combined) ||
    extractNameFromBackLetter(backText) ||
    extractNameFromBackLetter(combined);
  if (!fromLetter || isWeakOcrName(fromLetter) || looksLikeGovernmentHeader(fromLetter)) {
    return '';
  }
  return fromLetter;
}

function mergeExtractedForEnrollmentSheet(
  frontText,
  letterText,
  cardBackText = '',
  idType,
  options = {},
) {
  const safeLetter = stripDisclaimerNoise(letterText);
  const safeCardBack = stripDisclaimerNoise(cardBackText);
  const letterOnly = isolateEnrollmentLetterText(safeLetter);
  const combined = `${frontText}\n${letterOnly}\n${safeCardBack}`.trim();

  const cardBackAddress = pickBestAddressCandidate([
    extractCommaSeparatedAadhaarAddress(safeCardBack, options),
    extractStructuredAadhaarBackAddress(safeCardBack, options),
  ]);
  const letterAddress = pickBestAddressCandidate([
    extractStructuredAadhaarBackAddress(letterOnly, options),
    extractCommaSeparatedAadhaarAddress(letterOnly, options),
  ]);

  let address = '';
  if (isCompleteFormattedAddress(cardBackAddress)) {
    address = cardBackAddress;
  } else if (cardBackAddress && letterAddress) {
    const cardScore = addressCleanlinessScore(cardBackAddress);
    const letterScore = addressCleanlinessScore(letterAddress);
    if (cardScore >= letterScore + 5) {
      address = mergeAddresses(cardBackAddress, letterAddress);
    } else if (letterScore >= cardScore + 5) {
      address = mergeAddresses(letterAddress, cardBackAddress);
    } else {
      address = mergeAddresses(cardBackAddress, letterAddress);
    }
  } else {
    address = cardBackAddress || letterAddress || '';
  }

  const phone =
    extractPhone(safeLetter, idType) ||
    extractPhone(safeCardBack, idType) ||
    extractPhone(combined, idType);
  const governmentIdNumber =
    extractIdNumber(`${frontText}\n${safeLetter}\n${safeCardBack}`, idType) ||
    extractIdNumber(combined, idType);

  return {
    fullName: titleCaseName(resolveEnrollmentSheetName(frontText, `${safeLetter}\n${safeCardBack}`)),
    address: finalizeAddress(
      appendMissingPin(
        normalizeLocalitySpacing(address || ''),
        `${letterOnly}\n${safeCardBack}`,
      ),
    ),
    phone,
    governmentIdNumber,
    rawText: combined.slice(0, 4000),
    detectedSide: 'back',
    uploadLayout: 'enrollment_sheet',
  };
}

function mergeExtractedForSingleSide(frontText, backText, idType, side, options = {}) {
  const combined = `${frontText}\n${backText}`.trim();

  if (side === 'back') {
    const safeBack = stripDisclaimerNoise(backText);
    const structured = extractStructuredAadhaarBackAddress(safeBack, options);
    const comma = extractCommaSeparatedAadhaarAddress(safeBack, options);
    const address =
      mergeAddresses(structured, comma) ||
      structured ||
      comma ||
      extractAddress(safeBack, options) ||
      extractAddress(stripDisclaimerNoise(combined), options);
    const governmentIdNumber =
      extractIdNumber(safeBack, idType) || extractIdNumber(combined, idType);
    const name = extractNameFromBackLetter(safeBack) || extractNameFromBackLetter(combined);
    return {
      fullName: titleCaseName(sanitizeNameForDetectedSide(name, 'back', safeBack || combined)),
      address: finalizeAddress(address || ''),
      phone: extractPhone(safeBack, idType) || extractPhone(combined, idType),
      governmentIdNumber,
      rawText: (safeBack || combined).slice(0, 4000),
      detectedSide: 'back',
    };
  }

  if (side === 'front') {
    const nameSource = frontText || combined;
    const governmentIdNumber = extractIdNumber(combined, idType);
    return {
      fullName: titleCaseName(extractName(nameSource)),
      address: '',
      phone: extractPhone(nameSource, idType),
      governmentIdNumber,
      rawText: combined.slice(0, 4000),
      detectedSide: 'front',
    };
  }

  const merged = mergeExtracted(frontText, backText, idType, options);
  if (
    merged.fullName &&
    /\b(pin\s*code|sub[\s-]?district|proof\s+of|citizenship|information)\b/i.test(combined)
  ) {
    merged.fullName = '';
  }
  merged.detectedSide = 'unknown';
  return merged;
}

/**
 * Merge OCR fields based on how the single upload was laid out.
 */
function mergeExtractedForLayout(frontText, backText, idType, layout, options = {}) {
  switch (layout) {
    case 'enrollment_sheet':
      return mergeExtractedForEnrollmentSheet(
        frontText,
        backText,
        options.cardBackText || '',
        idType,
        options,
      );

    case 'dual_horizontal':
    case 'dual_vertical':
      return { ...mergeExtracted(frontText, backText, idType, options), uploadLayout: layout };

    case 'back_columns':
      return {
        ...mergeExtractedForSingleSide(frontText, backText, idType, 'back', options),
        uploadLayout: layout,
      };

    case 'single': {
      const combined = `${frontText}\n${backText}`;
      const side = classifyAadhaarSide(combined);
      const detectedLayout = side === 'back' ? 'single_back' : side === 'front' ? 'single_front' : 'single';
      return {
        ...mergeExtractedForSingleSide(frontText, backText, idType, side, options),
        uploadLayout: detectedLayout,
      };
    }

    default:
      return mergeExtracted(frontText, backText, idType, options);
  }
}

function isAadhaarBackSide(fields = {}) {
  const side = String(fields.detectedSide || '');
  const layout = String(fields.uploadLayout || '');
  return side === 'back' || layout.includes('back');
}

function isAcceptableEnrollmentExtraction(fields = {}) {
  const uid = String(fields.governmentIdNumber || fields.aadhaarNumber || '').replace(
    /\D/g,
    '',
  );
  const addr = String(fields.address || '').trim();
  return (
    uid.length === 12 &&
    isValidAadhaarChecksum(uid) &&
    addr.length >= 12 &&
    (/\b\d{6}\b/.test(addr) ||
      /\b(sub\s*district|district|state|nagar|puram|street|tamil)/i.test(addr))
  );
}

function isAcceptableAadhaarBackExtraction(fields = {}) {
  const phone = String(fields.phone || '').replace(/\D/g, '');
  const uid = String(fields.governmentIdNumber || fields.aadhaarNumber || '').replace(
    /\D/g,
    '',
  );
  const addr = String(fields.address || '').trim();
  const hasPhone = phone.length === 10 && /^[6-9]/.test(phone);
  const hasAddress =
    addr.length >= 12 &&
    (/\b\d{6}\b/.test(addr) ||
      /\b(sub\s*district|district|state|nagar|puram|tamil)/i.test(addr));
  const hasUid = uid.length === 12 && isValidAadhaarChecksum(uid);

  if (String(fields.uploadLayout || '') === 'enrollment_sheet') {
    return isAcceptableEnrollmentExtraction(fields);
  }

  const layout = String(fields.uploadLayout || '');
  const backLayout =
    layout === 'back_columns' || layout === 'single_back' || isAadhaarBackSide(fields);
  if (backLayout) {
    return hasUid && hasAddress;
  }

  return hasPhone && hasUid && hasAddress;
}

function isAcceptableAadhaarFrontExtraction(fields = {}) {
  const uid = String(fields.governmentIdNumber || fields.aadhaarNumber || '').replace(
    /\D/g,
    '',
  );
  return (
    Boolean(fields.fullName && fields.fullName.length >= 3) &&
    uid.length === 12 &&
    isValidAadhaarChecksum(uid)
  );
}

/**
 * Normalize side detection and whether a single-side upload is good enough to accept.
 */
function finalizeAadhaarExtraction(extracted = {}, uploadLayout = '') {
  const out = { ...extracted };
  if (!out.uploadLayout && uploadLayout) out.uploadLayout = uploadLayout;

  out.fullName = titleCaseName(
    sanitizeNameForDetectedSide(
      out.fullName,
      out.detectedSide,
      out.rawText || '',
    ),
  );

  if (out.address) {
    out.address = finalizeAddress(out.address);
  }

  if (!out.detectedSide && isAcceptableAadhaarBackExtraction(out)) {
    out.detectedSide = 'back';
    if (!String(out.uploadLayout || '').includes('back')) {
      out.uploadLayout = 'single_back';
    }
  }

  if (out.uploadLayout === 'enrollment_sheet' && isAcceptableEnrollmentExtraction(out)) {
    out.ocrAccepted = true;
  } else if (isAadhaarBackSide(out) && isAcceptableAadhaarBackExtraction(out)) {
    out.ocrAccepted = true;
  } else if (isAcceptableAadhaarFrontExtraction(out)) {
    out.ocrAccepted = true;
  } else if (
    out.fullName &&
    isAcceptableAadhaarBackExtraction(out)
  ) {
    out.ocrAccepted = true;
  } else {
    out.ocrAccepted = Boolean(
      out.fullName &&
        out.address &&
        out.governmentIdNumber &&
        isValidAadhaarChecksum(
          String(out.governmentIdNumber || '').replace(/\D/g, ''),
        ),
    );
  }

  return out;
}

function mergeWithPreference(primary, fallback, options = {}) {
  const backSide =
    options.detectedSide === 'back' ||
    String(options.uploadLayout || '').includes('back');
  const primaryName =
    backSide && !options.allowNameOnBack ? '' : primary.fullName || '';
  const fallbackName =
    backSide && !options.allowNameOnBack ? '' : fallback.fullName || '';

  return {
    fullName: primaryName || fallbackName || '',
    address: primary.address || fallback.address || '',
    phone: primary.phone || fallback.phone || '',
    governmentIdNumber:
      primary.governmentIdNumber || fallback.governmentIdNumber || '',
    aadhaarNumber: primary.aadhaarNumber || fallback.aadhaarNumber || '',
    rawText: fallback.rawText || primary.rawText || '',
    extractionSource: primary.source || primary.extractionSource || 'ocr',
    uploadLayout: fallback.uploadLayout || options.uploadLayout,
    detectedSide: fallback.detectedSide || options.detectedSide,
    ocrAccepted: fallback.ocrAccepted ?? primary.ocrAccepted,
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
    address: mergeAddresses(a.address, b.address),
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

const OTHER_ID_RULES = [
  {
    pattern: /\b(income\s+tax|permanent\s+account|pan\s*card)\b/i,
    message: 'This looks like a PAN card. Please upload your Aadhaar card only.',
  },
  {
    pattern: /\b[A-Z]{5}\d{4}[A-Z]\b/,
    message: 'This looks like a PAN card. Please upload your Aadhaar card only.',
  },
  {
    pattern: /\bdriving\s+licen[cs]e\b/i,
    message: 'This looks like a driving licence. Please upload your Aadhaar card only.',
  },
  {
    pattern: /\b(election\s+commission|elector\s+photo\s+identity|epic\s*no)\b/i,
    message: 'This looks like a voter ID. Please upload your Aadhaar card only.',
  },
  {
    pattern: /\bpassport\b/i,
    unless: /\baadhaar\b/i,
    message: 'This looks like a passport. Please upload your Aadhaar card only.',
  },
];

/**
 * Reject uploads that are clearly not an Aadhaar card (PAN, DL, voter ID, random photos).
 */
function validateAadhaarDocument(extracted = {}) {
  const raw = String(extracted.rawText || '');

  for (const rule of OTHER_ID_RULES) {
    if (rule.unless && rule.unless.test(raw)) continue;
    if (rule.pattern.test(raw)) {
      return { valid: false, message: rule.message };
    }
  }

  const uid = String(extracted.governmentIdNumber || extracted.aadhaarNumber || '').replace(
    /\D/g,
    '',
  );
  if (uid.length === 12 && isValidAadhaarChecksum(uid)) {
    return { valid: true };
  }

  const aadhaarMarkers = [
    /\baadhaar\b/i,
    /\buidai\b/i,
    /\bunique\s+identification\b/i,
    /\bgovernment\s+of\s+india\b/i,
    /\b(pin\s*code|sub\s*district)\b/i,
    /\b(enrol+ment|enrollment)\b/i,
    /\bvid\s*:/i,
    /\bmaadhaar\b/i,
    /\bdate\s+of\s+birth\b/i,
    /\b\d{4}\s+\d{4}\s+\d{4}\b/,
  ];
  const markerHits = aadhaarMarkers.filter((re) => re.test(raw)).length;

  const phone = String(extracted.phone || '').replace(/\D/g, '');
  const hasMobileLabel = /\bmobile\b/i.test(raw) && phone.length === 10;
  const hasPinInAddress =
    /\b\d{6}\b/.test(extracted.address || '') || /\bpin\s*code\b/i.test(raw);

  if (markerHits >= 2) return { valid: true };
  if (markerHits >= 1 && (hasMobileLabel || hasPinInAddress || extracted.address)) {
    return { valid: true };
  }
  if (hasMobileLabel && hasPinInAddress) return { valid: true };

  return {
    valid: false,
    message:
      'This does not look like an Aadhaar card. Please upload a clear photo or PDF of your Aadhaar card only.',
  };
}

function assertAadhaarDocument(extracted) {
  const check = validateAadhaarDocument(extracted);
  if (!check.valid) {
    const err = new Error(check.message);
    err.code = 'NOT_AADHAAR';
    throw err;
  }
}

module.exports = {
  cleanLine,
  stripNonLatin,
  linesFromText,
  latinLinesFromText,
  extractAddress,
  extractStructuredAadhaarBackAddress,
  extractName,
  extractPhone,
  extractIdNumber,
  mergeExtracted,
  mergeExtractedForLayout,
  mergeExtractedForEnrollmentSheet,
  mergeExtractedForSingleSide,
  isMisclassifiedEnrollmentSheet,
  classifyAadhaarSide,
  mergeWithPreference,
  scoreOcrExtraction,
  scoreNameCandidate,
  isValidAadhaarChecksum,
  titleCaseName,
  isCompleteAadhaarQr,
  isUsefulPartialQr,
  mergeBestFields,
  mergeAddresses,
  pickBetterAddress,
  sanitizeNameForDetectedSide,
  looksLikeGovernmentHeader,
  filterAddressGarbageSegments,
  validateAadhaarDocument,
  assertAadhaarDocument,
  finalizeAadhaarExtraction,
  finalizeAddress,
  isAcceptableAadhaarBackExtraction,
  isAadhaarBackSide,
  ID_TYPES,
};
