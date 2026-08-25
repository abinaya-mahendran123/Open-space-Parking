/**
 * Installs Python deps for PaddleOCR into python/paddleocr_service/.venv
 * Run during Render Build Command (or locally before first OCR).
 *
 * Usage: node scripts/setup_paddleocr.js
 */
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const serviceDir = path.resolve(__dirname, '..', '..', 'python', 'paddleocr_service');
const requirements = path.join(serviceDir, 'requirements.txt');
const venvDir = path.join(serviceDir, '.venv');
const isWin = process.platform === 'win32';
const venvPython = isWin
  ? path.join(venvDir, 'Scripts', 'python.exe')
  : path.join(venvDir, 'bin', 'python');

function run(command, args, opts = {}) {
  console.log(`[setup_paddleocr] ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, {
    stdio: 'inherit',
    shell: false,
    env: process.env,
    ...opts,
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`${command} exited with code ${result.status}`);
  }
}

function findPython() {
  const candidates = isWin
    ? ['python', 'py', 'python3']
    : ['python3', 'python'];
  for (const cmd of candidates) {
    const probe = spawnSync(cmd, ['--version'], { encoding: 'utf8' });
    if (probe.status === 0) {
      return cmd;
    }
  }
  return null;
}

function main() {
  if (!fs.existsSync(requirements)) {
    console.warn(`[setup_paddleocr] Missing ${requirements} — skip OCR install.`);
    return;
  }

  if (process.env.SKIP_PADDLEOCR_SETUP === '1') {
    console.log('[setup_paddleocr] SKIP_PADDLEOCR_SETUP=1 — skipping.');
    return;
  }

  const python = findPython();
  if (!python) {
    console.warn(
      '[setup_paddleocr] No Python found. OCR will fall back to Tesseract only.',
    );
    return;
  }

  console.log(`[setup_paddleocr] Using ${python}`);
  console.log(`[setup_paddleocr] Service dir: ${serviceDir}`);

  if (!fs.existsSync(venvPython)) {
    run(python, ['-m', 'venv', venvDir]);
  }

  // Upgrade pip first for reliable wheels on Render.
  run(venvPython, ['-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel']);
  run(venvPython, [
    '-m',
    'pip',
    'install',
    '-r',
    requirements,
    '--timeout',
    '180',
  ]);

  // Verify OpenCV (cv2) is importable — this was the Render failure.
  const verify = spawnSync(
    venvPython,
    ['-c', 'import cv2; import flask; print("cv2", cv2.__version__)'],
    { encoding: 'utf8' },
  );
  if (verify.status !== 0) {
    console.error(verify.stderr || verify.stdout);
    throw new Error('PaddleOCR venv installed but import cv2 failed.');
  }
  console.log(`[setup_paddleocr] OK — ${verify.stdout.trim()}`);
  console.log(`[setup_paddleocr] Set PADDLEOCR_PYTHON=${venvPython}`);
}

try {
  main();
} catch (error) {
  console.error(`[setup_paddleocr] ${error.message}`);
  // Do not fail the whole Node deploy if OCR setup fails — Tesseract still works.
  if (process.env.REQUIRE_PADDLEOCR_SETUP === '1') {
    process.exit(1);
  }
  process.exit(0);
}
