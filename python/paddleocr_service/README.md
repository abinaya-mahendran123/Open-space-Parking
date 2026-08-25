# PaddleOCR Service

Long-running Python worker for government-ID OCR. Node.js calls this service over HTTP (preferred) or via CLI subprocess fallback.

## Versions

| Package | Version |
|---------|---------|
| Python | 3.9–3.11 recommended |
| paddleocr | 2.9.1 |
| paddlepaddle | 2.6.2 (CPU) |
| Languages | `en`, `ta`, `hi` |

## Install

```bash
cd python/paddleocr_service
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate
pip install -r requirements.txt
```

First run downloads OCR models (~100–200 MB per language).

## Run HTTP service

```bash
python main.py
# or
python main.py serve
```

Default: `http://127.0.0.1:8765`

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `PADDLEOCR_SERVICE_PORT` | `8765` | HTTP port |
| `PADDLEOCR_SERVICE_HOST` | `127.0.0.1` | Bind address |
| `PADDLEOCR_LANGS` | `en,ta,hi` | Languages per request |
| `PADDLEOCR_USE_GPU` | `false` | GPU inference |

Node backend reads `PADDLEOCR_SERVICE_URL` (default `http://127.0.0.1:8765`).

## CLI (subprocess fallback)

```bash
python main.py --image /path/to/image.jpg --langs en,ta,hi
```

## Render deployment

Node + PaddleOCR can run on **one** Render web service.

### Build / Start (required)

In the Render dashboard (Root Directory = **repo root**, empty):

| Setting | Value |
|---------|--------|
| Build Command | `cd backend && npm install && npm run setup:ocr` |
| Start Command | `cd backend && npm start` |

`setup:ocr` creates `python/paddleocr_service/.venv` and installs `opencv-python-headless` (fixes `No module named 'cv2'`).  
`npm start` runs `scripts/start_with_ocr.js`, which starts this Flask app on `:8765`, then Node.

### Env

```env
PADDLEOCR_SERVICE_URL=http://127.0.0.1:8765
PADDLEOCR_SERVICE_PORT=8765
PADDLEOCR_LANGS=en,ta,hi
```

### Options

1. **Two Render services**: Node web + Python worker (set `PADDLEOCR_SERVICE_URL` to the worker URL; set `SKIP_PADDLEOCR_WORKER=1` on Node).
2. **Single VPS** with systemd/supervisor.
3. **Tesseract only**: `SKIP_PADDLEOCR_SETUP=1` and `SKIP_PADDLEOCR_WORKER=1`.

PaddleOCR needs ~1–2 GB RAM. Free tier often falls back to Tesseract after OOM.
