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

PaddleOCR is CPU/RAM heavy. Recommended options:

1. **Two Render services**: Node web service + Python worker service (private network URL).
2. **Single VPS** with both processes managed by systemd/supervisor.
3. **Subprocess on same host** only if instance has ≥2 GB RAM and acceptable cold-start latency.

Do not assume PaddleOCR works on Render free tier without verifying instance size.
