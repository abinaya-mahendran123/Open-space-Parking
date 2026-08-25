/**
 * Starts PaddleOCR HTTP worker (if installed), then the Node API.
 * Used as `npm start` on Render so OCR does not rely on a separate service.
 */
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
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
const port = Number(process.env.PADDLEOCR_SERVICE_PORT || 8765);

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

function healthCheck(timeoutMs = 2500) {
  return new Promise((resolve) => {
    const url = new URL(`${serviceUrl}/health`);
    const req = http.get(
      {
        hostname: url.hostname,
        port: url.port || 80,
        path: url.pathname,
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
            resolve(null);
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

async function waitForHealthy(attempts = 40, delayMs = 1500) {
  for (let i = 0; i < attempts; i += 1) {
    const health = await healthCheck();
    if (health && health.ok) return true;
    await new Promise((r) => setTimeout(r, delayMs));
  }
  return false;
}

/** Wait until Paddle models finished downloading (first boot can take several minutes). */
async function waitForModelsReady(attempts = 180, delayMs = 2000) {
  for (let i = 0; i < attempts; i += 1) {
    const health = await healthCheck(5000);
    if (health && health.modelsReady) {
      console.log('[start_with_ocr] PaddleOCR models ready');
      return true;
    }
    if (health && health.modelsError) {
      console.warn('[start_with_ocr] PaddleOCR warmup error:', health.modelsError);
      return false;
    }
    if (i === 0 || i % 15 === 0) {
      console.log(
        `[start_with_ocr] Waiting for PaddleOCR model download/warmup... (${i + 1}/${attempts})`,
      );
    }
    await new Promise((r) => setTimeout(r, delayMs));
  }
  return false;
}

function startPaddle(pythonBin) {
  console.log(`[start_with_ocr] Starting PaddleOCR with ${pythonBin}`);
  const env = {
    ...process.env,
    PADDLEOCR_SERVICE_PORT: String(port),
    PADDLEOCR_SERVICE_HOST: process.env.PADDLEOCR_SERVICE_HOST || '127.0.0.1',
    // Point Node client at this worker (and subprocess fallback to same venv).
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

  console.log('[start_with_ocr] Starting Node API');
  nodeChild = spawn(process.execPath, ['server.js'], {
    cwd: path.resolve(__dirname, '..'),
    env,
    stdio: 'inherit',
    windowsHide: true,
  });

  nodeChild.on('exit', (code, signal) => {
    console.warn(
      `[start_with_ocr] Node exited code=${code} signal=${signal || ''}`,
    );
    shutdown(code || 0);
  });
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
  if (process.env.SKIP_PADDLEOCR_WORKER === '1') {
    console.log('[start_with_ocr] SKIP_PADDLEOCR_WORKER=1 — Node only');
    startNode();
    return;
  }

  const already = await healthCheck();
  if (already && already.ok && already.modelsReady) {
    console.log('[start_with_ocr] PaddleOCR already healthy at', serviceUrl);
    startNode();
    return;
  }

  const pythonBin = resolvePython();
  if (!pythonBin || !fs.existsSync(scriptPath)) {
    console.warn(
      '[start_with_ocr] PaddleOCR venv/script missing — Node will use Tesseract fallback.',
    );
    console.warn(
      '[start_with_ocr] Run: npm run setup:ocr  (or include it in Render Build Command)',
    );
    startNode();
    return;
  }

  if (!(already && already.ok)) {
    startPaddle(pythonBin);
    const healthy = await waitForHealthy();
    if (!healthy) {
      console.warn(
        '[start_with_ocr] PaddleOCR HTTP did not start — continuing with Tesseract fallback.',
      );
      startNode();
      return;
    }
  }

  // First deploy downloads PP-OCR models; wait so the first Aadhaar scan does not time out.
  const modelsReady = await waitForModelsReady();
  if (!modelsReady) {
    console.warn(
      '[start_with_ocr] Models not ready yet — OCR may fall back to Tesseract until warmup finishes.',
    );
  } else {
    console.log('[start_with_ocr] PaddleOCR ready at', serviceUrl);
  }

  startNode();
}

process.on('SIGINT', () => shutdown(0));
process.on('SIGTERM', () => shutdown(0));

main().catch((error) => {
  console.error('[start_with_ocr]', error);
  startNode();
});
