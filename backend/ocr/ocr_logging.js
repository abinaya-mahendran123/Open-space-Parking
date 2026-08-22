/**
 * Safe OCR logging — never log PII (name, address, Aadhaar, phone, raw text).
 */

function maskAadhaar(value) {
  const digits = String(value || '').replace(/\D/g, '');
  if (digits.length < 4) return '****';
  return `XXXX XXXX ${digits.slice(-4)}`;
}

function maskPhone(value) {
  const digits = String(value || '').replace(/\D/g, '');
  if (digits.length < 4) return '******';
  return `******${digits.slice(-4)}`;
}

function logOcr(event, fields = {}) {
  const safe = { ...fields };
  if (safe.aadhaar) safe.aadhaar = maskAadhaar(safe.aadhaar);
  if (safe.phone) safe.phone = maskPhone(safe.phone);
  delete safe.fullName;
  delete safe.address;
  delete safe.rawText;
  console.log(`[OCR] ${event}`, safe);
}

module.exports = { logOcr, maskAadhaar, maskPhone };
