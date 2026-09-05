const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const http = require('http');
const https = require('https');

const { logOcr } = require('./ocr_logging');
const { isLowMemoryOcr } = require('./low_memory');

const DEFAULT_SERVICE_URL =
  process.env.PADDLEOCR_SERVICE_URL || 'http://127.0.0.1:8765';
const DEFAULT_TIMEOUT_MS = Number(process.env.PADDLEOCR_TIMEOUT_MS || 180000);
const MAX_CONCURRENT = Number(
  process.env.PADDLEOCR_MAX_CONCURRENT || (isLowMemoryOcr() ? 1 : 2),
);
const HEALTH_CACHE_MS = Number(process.env.PADDLEOCR_HEALTH_CACHE_MS || 60000);

let activeCount = 0;
const waitQueue = [];
const healthCaches = new Map();
let workerRoundRobin = 0;

function listServiceUrls() {
  const multi = String(process.env.PADDLEOCR_SERVICE_URLS || '').trim();
  if (multi) {
    return multi
      .split(',')
      .map((part) => part.trim().replace(/\/$/, ''))
      .filter(Boolean);
  }
  return [DEFAULT_SERVICE_URL.replace(/\/$/, '')];
}

function pickServiceUrl() {
  const urls = listServiceUrls();
  if (urls.length === 1) return urls[0];
  const url = urls[workerRoundRobin % urls.length];
  workerRoundRobin += 1;
  return url;
}

function acquireSlot() {
  return new Promise((resolve) => {
    if (activeCount < MAX_CONCURRENT) {
      activeCount += 1;
      resolve();
      return;
    }
    waitQueue.push(resolve);
  });
}

function releaseSlot() {
  activeCount = Math.max(0, activeCount - 1);
  const next = waitQueue.shift();
  if (next) {
    activeCount += 1;
    next();
  }
}

function pythonExecutable() {
  return (
    process.env.PADDLEOCR_PYTHON ||
    process.env.PYTHON_PATH ||
    (process.platform === 'win32' ? 'python' : 'python3')
  );
}

function paddleScriptPath() {
  if (process.env.PADDLEOCR_SCRIPT) return process.env.PADDLEOCR_SCRIPT;
  return path.join(
    __dirname,
    '..',
    '..',
    'python',
    'paddleocr_service',
    'main.py',
  );
}

function paddleLangs() {
  // English is enough for Aadhaar labels (PO, PIN, Mobile). ta/hi add minutes
  // of cold-start model download and routinely exceed HTTP timeouts on Windows.
  const langs = (process.env.PADDLEOCR_LANGS || 'en')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);
  return langs.length ? langs : ['en'];
}

function effectivePaddleLangs(requested) {
  const allowed = new Set(paddleLangs());
  const picked = (requested || []).filter((lang) => allowed.has(lang));
  return picked.length ? picked : paddleLangs();
}

function paddleHttpTimeoutMs(options = {}) {
  return Number(
    process.env.PADDLEOCR_HTTP_TIMEOUT_MS ||
      process.env.PADDLEOCR_TIMEOUT_MS ||
      options.timeoutMs ||
      DEFAULT_TIMEOUT_MS,
  );
}

function postJson(url, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const payload = JSON.stringify(body);
    const client = parsed.protocol === 'https:' ? https : http;
    const req = client.request(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: `${parsed.pathname}${parsed.search}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
        timeout: timeoutMs,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const raw = Buffer.concat(chunks).toString('utf8');
          try {
            const json = JSON.parse(raw);
            if (res.statusCode >= 400) {
              const err = new Error(json.error || `PaddleOCR HTTP ${res.statusCode}`);
              err.statusCode = res.statusCode;
              err.retryAfterSeconds = json.retryAfterSeconds;
              reject(err);
              return;
            }
            resolve(json);
          } catch (error) {
            reject(new Error(`Invalid PaddleOCR JSON: ${error.message}`));
          }
        });
      },
    );
    req.on('timeout', () => {
      req.destroy(new Error('PaddleOCR HTTP timeout'));
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function getJson(url, timeoutMs) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const client = parsed.protocol === 'https:' ? https : http;
    const req = client.get(
      {
        hostname: parsed.hostname,
        port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
        path: `${parsed.pathname}${parsed.search}`,
        timeout: timeoutMs,
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
          } catch (error) {
            reject(error);
          }
        });
      },
    );
    req.on('timeout', () => req.destroy(new Error('PaddleOCR health timeout')));
    req.on('error', reject);
  });
}

async function ensureServiceHealthy(serviceUrl, timeoutMs) {
  const now = Date.now();
  const cached = healthCaches.get(serviceUrl);
  if (cached?.ok && now - cached.at < HEALTH_CACHE_MS) {
    return;
  }
  const health = await getJson(`${serviceUrl}/health`, timeoutMs);
  if (!health || !health.ok) {
    throw new Error(`PaddleOCR health check failed for ${serviceUrl}`);
  }
  if (health.modelsReady === false) {
    throw new Error(
      health.modelsError ||
        'PaddleOCR models are still downloading/loading. Retry in a minute.',
    );
  }
  healthCaches.set(serviceUrl, { at: now, ok: true });
}

async function writeTempImage(buffer) {
  const dir = path.join(os.tmpdir(), 'osp-ocr');
  fs.mkdirSync(dir, { recursive: true });
  const filePath = path.join(dir, `paddle-${Date.now()}-${Math.random().toString(16).slice(2)}.jpg`);
  await fs.promises.writeFile(filePath, buffer);
  return filePath;
}

async function cleanupTemp(filePath) {
  if (!filePath) return;
  try {
    await fs.promises.unlink(filePath);
  } catch (_) {
    // ignore
  }
}

function runSubprocess(imagePath, langs, timeoutMs) {
  return new Promise((resolve, reject) => {
    const script = paddleScriptPath();
    const args = ['--image', imagePath, '--langs', langs.join(',')];
    const child = spawn(pythonExecutable(), [script, ...args], {
      stdio: ['ignore', 'pipe', 'pipe'],
      windowsHide: true,
      shell: false,
    });

    let stdout = '';
    let stderr = '';
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('PaddleOCR subprocess timeout'));
    }, timeoutMs);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString('utf8');
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString('utf8');
    });
    child.on('error', (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        reject(new Error(stderr.trim() || `PaddleOCR exited with code ${code}`));
        return;
      }
      try {
        const jsonStart = stdout.indexOf('{');
        const jsonText = jsonStart >= 0 ? stdout.slice(jsonStart) : stdout;
        resolve(JSON.parse(jsonText));
      } catch (error) {
        reject(new Error(`PaddleOCR subprocess JSON parse failed: ${error.message}`));
      }
    });
  });
}

async function recognizeBuffer(buffer, options = {}) {
  if (process.env.SKIP_PADDLEOCR_WORKER === '1') {
    const err = new Error('PaddleOCR worker disabled (SKIP_PADDLEOCR_WORKER=1)');
    logOcr('paddle_skip', { reason: err.message });
    throw err;
  }

  const timeoutMs = paddleHttpTimeoutMs(options);
  const langs = effectivePaddleLangs(options.langs || paddleLangs());
  const tried = new Set();
  let serviceUrl = (options.serviceUrl || pickServiceUrl()).replace(/\/$/, '');
  const allowSubprocess = process.env.PADDLEOCR_ALLOW_SUBPROCESS === '1';

  await acquireSlot();
  const started = Date.now();
  let tempPath = null;

  try {
    tempPath = await writeTempImage(buffer);

    while (true) {
      tried.add(serviceUrl);
      try {
        await ensureServiceHealthy(serviceUrl, 2500);
      } catch (healthError) {
        logOcr('paddle_skip', { reason: healthError.message || String(healthError), serviceUrl });
        throw healthError;
      }

      try {
        const result = await postJson(
          `${serviceUrl}/ocr`,
          { imagePath: tempPath, langs },
          timeoutMs,
        );
        logOcr('engine=paddleocr mode=http', {
          paddleTimeMs: Date.now() - started,
          langsUsed: result.langsUsed,
          serviceUrl,
        });
        return { ...result, mode: 'http' };
      } catch (httpError) {
        const reason = httpError.message || String(httpError);
        const statusCode = httpError.statusCode || 0;
        logOcr('paddle_http_failed', { reason, serviceUrl, statusCode });

        const fallbackUrl = listServiceUrls().find((url) => !tried.has(url));
        if (statusCode === 503 && fallbackUrl) {
          serviceUrl = fallbackUrl;
          continue;
        }

        if (!allowSubprocess) throw httpError;
        break;
      }
    }

    if (!allowSubprocess) {
      throw new Error('PaddleOCR HTTP failed and subprocess fallback is disabled');
    }

    const result = await runSubprocess(tempPath, langs, timeoutMs);
    logOcr('engine=paddleocr mode=subprocess', {
      paddleTimeMs: Date.now() - started,
      langsUsed: result.langsUsed,
    });
    return { ...result, mode: 'subprocess' };
  } finally {
    await cleanupTemp(tempPath);
    releaseSlot();
  }
}

async function isServiceHealthy() {
  const serviceUrl = DEFAULT_SERVICE_URL.replace(/\/$/, '');
  try {
    const health = await getJson(`${serviceUrl}/health`, 3000);
    return Boolean(health && health.ok);
  } catch (_) {
    return false;
  }
}

module.exports = {
  recognizeBuffer,
  isServiceHealthy,
  paddleLangs,
  listServiceUrls,
  DEFAULT_TIMEOUT_MS,
};
