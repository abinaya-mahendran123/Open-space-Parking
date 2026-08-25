# Government ID OCR Architecture

```text
Flutter POST /api/ocr/government-id
        ↓
government_id_ocr.js (orchestrator)
        ↓
Fetch Cloudinary URL → PDF/image normalize (sharp)
        ↓
Combined image split (ocr_preprocess.splitSideBySide)
        ↓
Aadhaar QR decode FIRST (aadhaar_qr.js + jsQR)
        ↓
Complete QR? → return extractionSource=aadhaar_qr
        ↓
ocr_pipeline.js
        ↓
PaddleOCR PRIMARY (paddleocr_client → Python service)
        ↓
field_extraction.js (name, address, phone, Aadhaar + Verhoeff)
        ↓
Weak / missing phone? → Tesseract FALLBACK (tesseract_engine.js)
        ↓
Merge QR partial + OCR → API response
```

## Engines

| Engine | Role | Languages |
|--------|------|-----------|
| **jsQR** | Aadhaar secure QR (preferred) | N/A |
| **PaddleOCR** | Primary photo OCR | `en`, `ta`, `hi` |
| **Tesseract.js** | Fallback OCR | `eng` (+ optional `tam`/`hin` workers) |

## Python service

See [python/paddleocr_service/README.md](../../python/paddleocr_service/README.md).

Start before the Node API:

```bash
cd python/paddleocr_service
pip install -r requirements.txt
python main.py
```

Node env: `PADDLEOCR_SERVICE_URL=http://127.0.0.1:8765`

### Production (Render)

```bash
cd backend
npm run setup:ocr   # install cv2 + paddle into python/paddleocr_service/.venv
npm start           # starts Paddle worker + Node API
```

Render **Build Command**: `cd backend && npm install && npm run setup:ocr`  
Render **Start Command**: `cd backend && npm start`  
(Root Directory = repo root, not `backend`)

If the HTTP service is unavailable, Node falls back to a Python subprocess (same `main.py` CLI), then Tesseract.js.

## Tests

```bash
cd backend
npm run test:ocr
```

## Benchmark (authorized test images only)

```bash
npm run benchmark:ocr -- --image path/to/test.jpg
```

## Security

- No PII in server logs (`ocr_logging.js`)
- Temp OCR files cleaned after each Paddle request
- No shell injection (spawn with argument array, no shell)
