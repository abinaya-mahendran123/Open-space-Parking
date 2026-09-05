/**
 * Backend-managed OTP service — no Firebase billing required.
 *
 * Flow:
 *  1. POST /api/auth/otp/send   { phone }  → sends 6-digit OTP via SMS
 *  2. POST /api/auth/otp/verify { phone, otp } → verifies OTP, returns a
 *     short-lived signed token that phone-login / phone-register accept
 *
 * SMS Provider: Fast2SMS (https://www.fast2sms.com)
 *   - Set FAST2SMS_API_KEY in .env
 *
 * Fallback: If FAST2SMS_API_KEY is not set, OTP is logged to the server
 *   console (check Render Logs). Set the key for real SMS to phones.
 *
 * Token: HMAC-SHA256 signed, expires in 10 minutes.
 */

const crypto = require('crypto');
const https = require('https');

// In-memory OTP store: phone → { otp, expiresAt, attempts }
// For production with multiple server instances, replace with DB/Redis.
const _otpStore = new Map();
/** IP → { count, windowStart } for send-rate limiting */
const _ipSendWindow = new Map();

const OTP_TTL_MS = 5 * 60 * 1000;       // 5 minutes
const TOKEN_TTL_MS = 10 * 60 * 1000;    // 10 minutes
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 30 * 1000;   // 30 seconds
const IP_SEND_WINDOW_MS = 15 * 60 * 1000;
const IP_SEND_MAX = 10;                 // max OTP sends per IP per window

function _isProduction() {
  return String(process.env.NODE_ENV || '').toLowerCase() === 'production';
}

function _tokenSecret() {
  const secret = process.env.OTP_TOKEN_SECRET || process.env.JWT_SECRET;
  if (!secret) {
    if (_isProduction()) {
      throw new Error('OTP_TOKEN_SECRET or JWT_SECRET must be set in production.');
    }
    return 'otp-dev-secret-change-in-prod';
  }
  return secret;
}

function _clientIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '')
    .split(',')[0]
    .trim();
  return forwarded || req.ip || req.socket?.remoteAddress || 'unknown';
}

function _checkIpSendLimit(ip) {
  const now = Date.now();
  let entry = _ipSendWindow.get(ip);
  if (!entry || now - entry.windowStart > IP_SEND_WINDOW_MS) {
    entry = { count: 0, windowStart: now };
    _ipSendWindow.set(ip, entry);
  }
  if (entry.count >= IP_SEND_MAX) {
    const retrySec = Math.ceil((entry.windowStart + IP_SEND_WINDOW_MS - now) / 1000);
    return { ok: false, retrySec };
  }
  entry.count += 1;
  return { ok: true };
}

function _generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function _signToken(phone) {
  const expires = Date.now() + TOKEN_TTL_MS;
  const payload = `${phone}:${expires}`;
  const sig = crypto.createHmac('sha256', _tokenSecret()).update(payload).digest('hex');
  return Buffer.from(`${payload}:${sig}`).toString('base64url');
}

function verifyOtpToken(token) {
  try {
    const decoded = Buffer.from(token, 'base64url').toString('utf8');
    const parts = decoded.split(':');
    if (parts.length !== 3) return null;
    const [phone, expiresStr, sig] = parts;
    const expires = Number(expiresStr);
    if (isNaN(expires) || Date.now() > expires) return null;
    const payload = `${phone}:${expires}`;
    const expected = crypto.createHmac('sha256', _tokenSecret()).update(payload).digest('hex');
    if (!crypto.timingSafeEqual(Buffer.from(sig, 'hex'), Buffer.from(expected, 'hex'))) {
      return null;
    }
    return phone;
  } catch {
    return null;
  }
}

async function sendSms(phone, otp) {
  const apiKey = (process.env.FAST2SMS_API_KEY || '').trim();

  if (!apiKey) {
    // Prefer setting FAST2SMS_API_KEY on Render for real SMS.
    // Without it, OTP is only in server logs (Render → Logs).
    console.warn(
      `\n[OTP DEV] Phone: ${phone}  OTP: ${otp}  (Set FAST2SMS_API_KEY for SMS)\n`,
    );
    return { ok: true, dev: true };
  }

  const message = `${otp} is your OTP for Open Space Parking. Valid for 5 minutes. Do not share.`;

  return new Promise((resolve) => {
    const body = JSON.stringify({
      route: 'q',
      message,
      language: 'english',
      flash: 0,
      numbers: phone.replace(/^\+91/, '').replace(/\D/g, ''),
    });

    const options = {
      hostname: 'www.fast2sms.com',
      path: '/dev/bulkV2',
      method: 'POST',
      headers: {
        authorization: apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try {
          const data = JSON.parse(raw);
          if (data.return === true) {
            resolve({ ok: true });
          } else {
            console.error('[Fast2SMS] Send failed:', raw);
            resolve({ ok: false, error: data.message || 'SMS delivery failed' });
          }
        } catch {
          resolve({ ok: false, error: 'Invalid SMS provider response' });
        }
      });
    });

    req.on('error', (err) => {
      console.error('[Fast2SMS] Request error:', err.message);
      resolve({ ok: false, error: err.message });
    });

    req.write(body);
    req.end();
  });
}

// ── Route handlers ────────────────────────────────────────────────────────────

async function handleSendOtp(req, res) {
  const raw = String(req.body?.phone || '').trim();
  if (!raw) return res.status(400).json({ error: 'Phone number is required.' });

  // Normalize to 10 digits
  const digits = raw.replace(/\D/g, '');
  const last10 = digits.slice(-10);
  if (last10.length !== 10 || !/^[6-9]/.test(last10)) {
    return res.status(400).json({ error: 'Enter a valid 10-digit Indian mobile number.' });
  }
  const phone = `+91${last10}`;

  const ipLimit = _checkIpSendLimit(_clientIp(req));
  if (!ipLimit.ok) {
    return res.status(429).json({
      error: `Too many OTP requests from this network. Try again in ${ipLimit.retrySec} seconds.`,
    });
  }

  // Cooldown check
  const existing = _otpStore.get(phone);
  if (existing) {
    const cooldownRemaining = (existing.sentAt + RESEND_COOLDOWN_MS) - Date.now();
    if (cooldownRemaining > 0) {
      return res.status(429).json({
        error: `Please wait ${Math.ceil(cooldownRemaining / 1000)} seconds before requesting a new OTP.`,
      });
    }
  }

  const otp = _generateOtp();
  _otpStore.set(phone, {
    otp,
    expiresAt: Date.now() + OTP_TTL_MS,
    sentAt: Date.now(),
    attempts: 0,
  });

  const smsResult = await sendSms(phone, otp);
  if (!smsResult.ok) {
    _otpStore.delete(phone);
    return res.status(502).json({
      error: `Could not send OTP SMS: ${smsResult.error}. Try again.`,
    });
  }

  return res.json({
    ok: true,
    phone,
    dev: smsResult.dev ?? false,
    message: smsResult.dev
      ? 'OTP logged to server console (SMS not configured).'
      : `OTP sent to ${phone.slice(0, 5)}*****${phone.slice(-2)}`,
  });
}

async function handleVerifyOtp(req, res) {
  const raw = String(req.body?.phone || '').trim();
  const otp = String(req.body?.otp || '').trim();

  if (!raw || !otp) {
    return res.status(400).json({ error: 'Phone and OTP are required.' });
  }

  const digits = raw.replace(/\D/g, '');
  const last10 = digits.slice(-10);
  const phone = `+91${last10}`;

  const record = _otpStore.get(phone);
  if (!record) {
    return res.status(400).json({ error: 'No OTP was sent to this number. Request a new OTP.' });
  }

  if (Date.now() > record.expiresAt) {
    _otpStore.delete(phone);
    return res.status(400).json({ error: 'OTP has expired. Request a new one.' });
  }

  record.attempts += 1;
  if (record.attempts > MAX_ATTEMPTS) {
    _otpStore.delete(phone);
    return res.status(429).json({ error: 'Too many incorrect attempts. Request a new OTP.' });
  }

  if (record.otp !== otp) {
    return res.status(400).json({
      error: `Incorrect OTP. ${MAX_ATTEMPTS - record.attempts} attempts remaining.`,
    });
  }

  // Correct OTP — consume it and issue a token
  _otpStore.delete(phone);
  const token = _signToken(phone);
  return res.json({ ok: true, phone, token });
}

module.exports = { handleSendOtp, handleVerifyOtp, verifyOtpToken };
