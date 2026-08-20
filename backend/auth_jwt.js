const crypto = require('crypto');

const TOKEN_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function jwtSecret() {
  const secret = process.env.JWT_SECRET || process.env.OTP_TOKEN_SECRET;
  if (!secret) {
    console.warn(
      'JWT_SECRET is not set — using dev fallback. Set JWT_SECRET in production.',
    );
    return 'osp-dev-jwt-secret-change-me';
  }
  return secret;
}

function base64urlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signAuthToken(claims) {
  const header = base64urlJson({ alg: 'HS256', typ: 'JWT' });
  const expiresAtMs = Date.now() + TOKEN_TTL_MS;
  const payload = {
    sub: String(claims.userId || ''),
    email: String(claims.email || ''),
    displayName: String(claims.displayName || ''),
    role: String(claims.role || ''),
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(expiresAtMs / 1000),
  };
  const encodedPayload = base64urlJson(payload);
  const signature = crypto
    .createHmac('sha256', jwtSecret())
    .update(`${header}.${encodedPayload}`)
    .digest('base64url');
  return {
    jwtToken: `${header}.${encodedPayload}.${signature}`,
    expiresAt: new Date(expiresAtMs).toISOString(),
  };
}

function verifyAuthToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const [header, encodedPayload, signature] = parts;
  const expected = crypto
    .createHmac('sha256', jwtSecret())
    .update(`${header}.${encodedPayload}`)
    .digest('base64url');

  const sigBuf = Buffer.from(signature);
  const expBuf = Buffer.from(expected);
  if (sigBuf.length !== expBuf.length) return null;
  if (!crypto.timingSafeEqual(sigBuf, expBuf)) return null;

  let payload;
  try {
    payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8'));
  } catch {
    return null;
  }

  if (!payload.sub || !payload.role) return null;
  if (typeof payload.exp === 'number' && payload.exp * 1000 < Date.now()) {
    return null;
  }

  return {
    userId: payload.sub,
    email: payload.email || '',
    displayName: payload.displayName || '',
    role: payload.role,
  };
}

function attachSessionToken(baseClaims) {
  const token = signAuthToken(baseClaims);
  return {
    ...baseClaims,
    jwtToken: token.jwtToken,
    expiresAt: token.expiresAt,
  };
}

function requireAuth(req, res, next) {
  const header = String(req.headers.authorization || '');
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    res.status(401).json({ error: 'Authentication required.' });
    return;
  }
  const claims = verifyAuthToken(match[1].trim());
  if (!claims) {
    res.status(401).json({ error: 'Invalid or expired token.' });
    return;
  }
  req.auth = claims;
  next();
}

function requireRole(...roles) {
  const allowed = new Set(roles);
  return (req, res, next) => {
    if (!req.auth) {
      res.status(401).json({ error: 'Authentication required.' });
      return;
    }
    if (!allowed.has(req.auth.role)) {
      res.status(403).json({ error: 'Insufficient permissions.' });
      return;
    }
    next();
  };
}

function parseCorsOrigins() {
  const raw = String(process.env.CORS_ORIGINS || '').trim();
  if (!raw) return null;
  return raw
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

module.exports = {
  attachSessionToken,
  verifyAuthToken,
  requireAuth,
  requireRole,
  parseCorsOrigins,
  signAuthToken,
};
