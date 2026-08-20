/**
 * DigiLocker OAuth 2.0 integration for property document verification.
 *
 * Flow:
 *  1. Flutter app calls GET /api/digilocker/auth-url  → receives authorization URL
 *  2. Flutter opens that URL in a WebView
 *  3. User logs in with Aadhaar OTP on DigiLocker, grants permission
 *  4. DigiLocker redirects to our callback with ?code=...
 *  5. Flutter app calls POST /api/digilocker/exchange with { code }
 *  6. Backend exchanges code for access token, fetches document list
 *  7. Flutter app calls POST /api/digilocker/fetch-document with { accessToken, uri }
 *  8. Backend returns structured document data
 *
 * SANDBOX MODE (default when DIGILOCKER_CLIENT_ID is not set):
 *  Returns mock verified data so development and testing work without approval.
 *
 * PRODUCTION:
 *  Set DIGILOCKER_CLIENT_ID, DIGILOCKER_CLIENT_SECRET, DIGILOCKER_REDIRECT_URI
 *  after your DigiLocker requester registration is approved.
 */

const https = require('https');
const querystring = require('querystring');

const CLIENT_ID = process.env.DIGILOCKER_CLIENT_ID || '';
const CLIENT_SECRET = process.env.DIGILOCKER_CLIENT_SECRET || '';
const REDIRECT_URI =
  process.env.DIGILOCKER_REDIRECT_URI ||
  'https://digilocker.meripehchaan.gov.in/public/oauth2/1/callback';

const SANDBOX_MODE = !CLIENT_ID || !CLIENT_SECRET;

const DIGILOCKER_BASE = 'https://api.digitallocker.gov.in';
const AUTH_BASE = 'https://digilocker.meripehchaan.gov.in';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function httpsPost(url, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const body = typeof data === 'string' ? data : querystring.stringify(data);
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
        ...headers,
      },
    };
    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function httpsGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const options = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers,
    };
    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

// ─── Sandbox mock data ────────────────────────────────────────────────────────

function sandboxAuthUrl(state) {
  // Return a special sandbox URL the Flutter app handles by showing mock flow
  return `openspaceparking://digilocker-sandbox?state=${state}&mock=1`;
}

function sandboxExchange() {
  return {
    access_token: 'sandbox_access_token_' + Date.now(),
    token_type: 'Bearer',
    expires_in: 3600,
    digilockerUserId: 'sandbox_user',
    isMock: true,
  };
}

function sandboxDocumentList() {
  return [
    {
      uri: 'in.gov.tn.revenuerecords/PATTA/1234567890',
      name: 'Patta (Tamil Nadu)',
      type: 'PATTA',
      issuer: 'Tamil Nadu Revenue Department',
      date: '2023-06-15',
      docType: 'Land Ownership Certificate',
    },
  ];
}

function sandboxFetchDocument(uri) {
  return {
    verified: true,
    documentType: 'Patta',
    ownerName: 'Demo Land Owner',
    surveyNumber: '123/4A',
    landArea: '0.45 acres',
    district: 'Chennai',
    village: 'Korattur',
    taluk: 'Ambattur',
    issuedBy: 'Tamil Nadu Revenue Department',
    issuedOn: '2023-06-15',
    verificationUrl:
      'https://verify.digitallocker.gov.in/sandbox/demo-verify-url',
    uri,
    isMock: true,
  };
}

// ─── Real DigiLocker API calls ────────────────────────────────────────────────

function buildAuthUrl(state) {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    state,
    scope: 'openid files.type.PATTA files.type.PATTAB files.type.ECOPY',
    dl_flow: 'signup',
    success_redirect_uri: REDIRECT_URI,
    failure_redirect_uri: REDIRECT_URI,
  });
  return `${AUTH_BASE}/public/oauth2/1/authorize?${params.toString()}`;
}

async function exchangeCode(code) {
  const result = await httpsPost(
    `${DIGILOCKER_BASE}/public/oauth2/1/token`,
    {
      code,
      grant_type: 'authorization_code',
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      redirect_uri: REDIRECT_URI,
    },
  );
  if (result.status !== 200) {
    throw new Error(`DigiLocker token exchange failed: ${JSON.stringify(result.body)}`);
  }
  return result.body;
}

async function getIssuedFiles(accessToken) {
  const result = await httpsGet(
    `${DIGILOCKER_BASE}/public/oauth2/3/files/issued`,
    { Authorization: `Bearer ${accessToken}` },
  );
  if (result.status !== 200) {
    throw new Error(`DigiLocker file list failed: ${JSON.stringify(result.body)}`);
  }
  // Filter to land-related document types
  const landTypes = ['PATTA', 'PATTAB', 'ECOPY', 'RTC', 'PAHANI', 'SATBARA', 'KHATAUNI', 'ADANGAL'];
  const items = result.body?.items || result.body?.files || [];
  return items.filter((f) => landTypes.includes(f.type?.toUpperCase()));
}

async function fetchDocumentDetails(accessToken, uri) {
  // Pull document metadata (XML/JSON from DigiLocker)
  const encoded = encodeURIComponent(uri);
  const result = await httpsGet(
    `${DIGILOCKER_BASE}/public/oauth2/3/xml/${encoded}`,
    { Authorization: `Bearer ${accessToken}` },
  );

  if (result.status !== 200) {
    throw new Error(`DigiLocker fetch document failed: ${JSON.stringify(result.body)}`);
  }

  // Parse the returned data — DigiLocker returns different shapes per state
  const data = result.body;
  return {
    verified: true,
    documentType: data.CertificateType || data.doctype || 'Property Document',
    ownerName: data.HolderName || data.name || data.OwnerName || '',
    surveyNumber: data.SurveyNumber || data.survey_no || data.SNo || '',
    landArea: data.Area || data.area || data.LandExtent || '',
    district: data.District || data.district || '',
    village: data.Village || data.village || '',
    taluk: data.Taluk || data.taluk || '',
    issuedBy: data.IssuedBy || data.issuer || '',
    issuedOn: data.IssuedDate || data.issue_date || '',
    verificationUrl: `https://verify.digitallocker.gov.in/${uri}`,
    uri,
    isMock: false,
  };
}

// ─── Express route handlers ───────────────────────────────────────────────────

/**
 * GET /api/digilocker/auth-url?state=<random>
 * Returns the URL for the land owner to open in a WebView.
 */
function handleAuthUrl(req, res) {
  const state = req.query.state || Math.random().toString(36).slice(2);

  if (SANDBOX_MODE) {
    return res.json({
      ok: true,
      url: sandboxAuthUrl(state),
      isSandbox: true,
      state,
      message:
        'DigiLocker is in sandbox mode. Set DIGILOCKER_CLIENT_ID and ' +
        'DIGILOCKER_CLIENT_SECRET in .env for production.',
    });
  }

  return res.json({ ok: true, url: buildAuthUrl(state), isSandbox: false, state });
}

/**
 * POST /api/digilocker/exchange
 * Body: { code: string }
 * Returns access token + issued document list.
 */
async function handleExchange(req, res) {
  const { code, isMock } = req.body || {};

  if (SANDBOX_MODE || isMock) {
    const token = sandboxExchange();
    const files = sandboxDocumentList();
    return res.json({ ok: true, ...token, files });
  }

  if (!code) return res.status(400).json({ error: 'code is required' });

  try {
    const token = await exchangeCode(code);
    const files = await getIssuedFiles(token.access_token);
    return res.json({ ok: true, ...token, files });
  } catch (err) {
    console.error('[DigiLocker] exchange error:', err.message);
    return res.status(502).json({ error: err.message });
  }
}

/**
 * POST /api/digilocker/fetch-document
 * Body: { accessToken: string, uri: string, isMock?: bool }
 * Returns structured property document data.
 */
async function handleFetchDocument(req, res) {
  const { accessToken, uri, isMock } = req.body || {};

  if (SANDBOX_MODE || isMock) {
    return res.json({ ok: true, document: sandboxFetchDocument(uri || 'mock/uri') });
  }

  if (!accessToken || !uri) {
    return res.status(400).json({ error: 'accessToken and uri are required' });
  }

  try {
    const document = await fetchDocumentDetails(accessToken, uri);
    return res.json({ ok: true, document });
  } catch (err) {
    console.error('[DigiLocker] fetch-document error:', err.message);
    return res.status(502).json({ error: err.message });
  }
}

module.exports = { handleAuthUrl, handleExchange, handleFetchDocument, SANDBOX_MODE };
