/**
 * Starts the Node API first (so Render sees 0.0.0.0:PORT), then PaddleOCR.
 *
 * Model downloads are heavy; starting Paddle before Node often prevents the API
 * from binding in time → Render "No open ports detected" / Timed Out.
 * Until Paddle models are ready, OCR falls back to Tesseract.
 */
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const net = require('net');
const path = require('path');

const serviceDir = path.resolve(__dirname, '..', '..', 'python', 'paddleocr_service');
const scriptPath = path.join(serviceDir, 'main.py');
const isWin = process.platform === 'win32';
const venvPython = isWin
  ? path.join(serviceDir, '.venv', 'Scripts', 'python.exe')
  : path.join(serviceDir, '.venv', 'bin', 'python');

const serviceUrl = (
  process.env.PADDLEOCR_SERVICE_URL || 'http://127.0.0.1:8765'
).replace(/\/$/, '');
const paddlePort = Number(process.env.PADDLEOCR_SERVICE_PORT || 8765);
const apiPort = Number(process.env.PORT || 3000);

let paddleChild = null;
let nodeChild = null;
let shuttingDown = false;

function resolvePython() {
  if (process.env.PADDLEOCR_PYTHON && fs.existsSync(process.env.PADDLEOCR_PYTHON)) {
    return process.env.PADDLEOCR_PYTHON;
  }
  if (fs.existsSync(venvPython)) return venvPython;
  return null;
}

function tcpOpen(host, port, timeoutMs = 1500) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port }, () => {
      socket.destroy();
      resolve(true);
    });
    socket.setTimeout(timeoutMs);
    socket.on('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.on('error', () => resolve(false));
  });
}

function healthJson(url, timeoutMs = 2500) {
  return new Promise((resolve) => {
    const parsed = new URL(url);
    const req = http.get(
      {
        hostname: parsed.hostname,
        port: parsed.port || 80,
        path: `${parsed.pathname}${parsed.search}`,
        timeout: timeoutMs,
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (_) {
            resolve({ ok: res.statusCode >= 200 && res.statusCode < 500 });
          }
        });
      },
    );
    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
    req.on('error', () => resolve(null));
  });
}

async function waitUntilApiListening(attempts = 90, delayMs = 1000) {
  for (let i = 0; i < attempts; i += 1) {
    if (await tcpOpen('127.0.0.1', apiPort)) {
      const health = await healthJson(`http://127.0.0.1:${apiPort}/api/health`);
      if (health) {
        console.log(
          `[start_with_ocr] Node API is up on port ${apiPort} (attempt ${i + 1})`,
        );
        return true;
      }
    }
    if (i === 0 || (i + 1) % 15 === 0) {
      console.log(
        `[start_with_ocr] Waiting for Node to bind 0.0.0.0:${apiPort}... (${i + 1}/${attempts})`,
      );
    }
    await new Promise((r) => setTimeout(r, delayMs));
  }
  return false;
}

function watchModelsInBackground() {
  let attempt = 0;
  const timer = setInterval(async () => {
    attempt += 1;
    const health = await healthJson(`${serviceUrl}/health`, 5000);
    if (health && health.modelsReady) {
      console.log('[start_with_ocr] PaddleOCR models ready (background)');
      clearInterval(timer);
      return;
    }
    if (health && health.modelsError) {
      console.warn('[start_with_ocr] PaddleOCR warmup error:', health.modelsError);
      clearInterval(timer);
      return;
    }
    if (attempt === 1 || attempt % 30 === 0) {
      console.log(
        `[start_with_ocr] Models still downloading in background... (${attempt})`,
      );
    }
    if (attempt >= 450) clearInterval(timer);
  }, 2000);
}

function startPaddle(pythonBin) {
  console.log(`[start_with_ocr] Starting PaddleOCR with ${pythonBin}`);
  const env = {
    ...process.env,
    PADDLEOCR_SERVICE_PORT: String(paddlePort),
    PADDLEOCR_SERVICE_HOST: process.env.PADDLEOCR_SERVICE_HOST || '127.0.0.1',
    PADDLEOCR_SERVICE_URL: serviceUrl,
    PADDLEOCR_PYTHON: pythonBin,
    PADDLEOCR_SCRIPT: scriptPath,
  };

  paddleChild = spawn(pythonBin, [scriptPath, 'serve'], {
    cwd: serviceDir,
    env,
    stdio: ['ignore', 'inherit', 'inherit'],
    windowsHide: true,
  });

  paddleChild.on('error', (err) => {
    console.warn('[start_with_ocr] PaddleOCR failed to spawn:', err.message);
    paddleChild = null;
  });

  paddleChild.on('exit', (code, signal) => {
    console.warn(
      `[start_with_ocr] PaddleOCR exited code=${code} signal=${signal || ''}`,
    );
    paddleChild = null;
  });
}

function startNode() {
  const env = {
    ...process.env,
    PADDLEOCR_SERVICE_URL: serviceUrl,
  };
  const pythonBin = resolvePython();
  if (pythonBin) {
    env.PADDLEOCR_PYTHON = pythonBin;
    env.PADDLEOCR_SCRIPT = scriptPath;
  }

  console.log(`[start_with_ocr] Starting Node API (bind 0.0.0.0:${apiPort} first)`);
  nodeChild = spawn(process.execPath, ['server.js'], {
    cwd: path.resolve(__dirname, '..'),
    env,
    stdio: 'inherit',
    windowsHide: true,
  });

  nodeChild.on('error', (err) => {
    console.error('[start_with_ocr] Node failed to spawn:', err.message);
    shutdown(1);
  });

  nodeChild.on('exit', (code, signal) => {
    console.warn(
      `[start_with_ocr] Node exited code=${code} signal=${signal || ''}`,
    );
    shutdown(code || 0);
  });
}

async function startPaddleAfterApi() {
  if (process.env.SKIP_PADDLEOCR_WORKER === '1') {
    console.log('[start_with_ocr] SKIP_PADDLEOCR_WORKER=1 — skipping PaddleOCR');
    return;
  }

  const already = await healthJson(`${serviceUrl}/health`);
  if (already && already.ok) {
    console.log('[start_with_ocr] PaddleOCR already up at', serviceUrl);
    if (!already.modelsReady) watchModelsInBackground();
    return;
  }

  const pythonBin = resolvePython();
  if (!pythonBin || !fs.existsSync(scriptPath)) {
    console.warn(
      '[start_with_ocr] PaddleOCR venv/script missing — Tesseract fallback only.',
    );
    return;
  }

  startPaddle(pythonBin);
  watchModelsInBackground();
}

function shutdown(code = 0) {
  if (shuttingDown) return;
  shuttingDown = true;
  if (paddleChild && !paddleChild.killed) {
    try {
      paddleChild.kill('SIGTERM');
    } catch (_) {}
  }
  if (nodeChild && !nodeChild.killed) {
    try {
      nodeChild.kill('SIGTERM');
    } catch (_) {}
  }
  setTimeout(() => process.exit(code), 500);
}

async function main() {
  // Render free/small instances OOM once Paddle models load (~1–2 GB), which
  // kills the whole service mid-OCR. Opt in with ENABLE_PADDLEOCR=1 on a
  // plan with enough RAM; otherwise Tesseract-only is reliable.
  const onRender = Boolean(process.env.RENDER || process.env.RENDER_SERVICE_ID);
  const skipPaddle =
    process.env.SKIP_PADDLEOCR_WORKER === '1' ||
    (onRender && process.env.ENABLE_PADDLEOCR !== '1');

  if (skipPaddle) {
    console.log(
      onRender && process.env.ENABLE_PADDLEOCR !== '1'
        ? '[start_with_ocr] Render detected — skipping PaddleOCR (set ENABLE_PADDLEOCR=1 if you have ≥2GB RAM). Using Tesseract.'
        : '[start_with_ocr] SKIP_PADDLEOCR_WORKER=1 — Node only (Tesseract OCR)',
    );
    startNode();
    return;
  }

  // Critical for Render: bind public PORT before any heavy OCR work.
  startNode();

  const up = await waitUntilApiListening();
  if (!up) {
    console.warn(
      `[start_with_ocr] Node did not bind port ${apiPort} in time; still starting PaddleOCR.`,
    );
  }

  await startPaddleAfterApi();
}

process.on('SIGINT', () => shutdown(0));
process.on('SIGTERM', () => shutdown(0));

main().catch((error) => {
  console.error('[start_with_ocr]', error);
  if (!nodeChild) startNode();
});
