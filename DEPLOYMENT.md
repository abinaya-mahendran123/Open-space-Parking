# Production Deployment Guide

## Architecture (Supabase-only)

```text
Flutter web / Android / iOS
        ↓  BASE_API_URL
Node.js backend (Express)
        ↓  DATABASE_URL
Supabase PostgreSQL

No MongoDB server is required for production.
```

The Flutter app talks to the **Node API only**. Repository class names still say `Mongo*` for historical reasons, but mobile/web/desktop production builds use the HTTP API path — they never open a MongoDB socket.

## Prerequisites

- Flutter SDK 3.16+
- Node.js 18+ for the backend
- **Supabase** project with Postgres (run `backend/supabase/schema.sql`)
- Hosting for the Node API (Render, Railway, Fly.io, VPS, etc.)
- Optional: Cloudinary, Firebase (OTP / FCM), Razorpay

## Backend setup

1. Copy env file:

```bash
cd backend
cp .env.example .env
```

2. Set **only** Supabase Postgres (leave Mongo empty):

```env
PORT=3000
DATABASE_URL=postgresql://postgres.YOUR_PROJECT:YOUR_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres
MONGO_CONNECTION_STRING=
```

3. Apply schema in Supabase SQL Editor: `backend/supabase/schema.sql`

4. Start the API:

```bash
npm install
npm start
```

Confirm logs show:

```text
Database: Supabase PostgreSQL
```

Health check:

```bash
curl https://YOUR_API_HOST/api/health
```

Expected:

```json
{ "ok": true, "database": "supabase", ... }
```

If `"database": "mongodb"`, `DATABASE_URL` is missing — fix `.env` and restart.

## PaddleOCR (government ID photo OCR)

Land-owner Aadhaar extraction uses **PaddleOCR** (primary) with **Tesseract.js** fallback. QR decoding remains first when readable.

### Local development

1. Install Python 3.9–3.11 and create a venv in `python/paddleocr_service/` (see that folder's README).
2. Start the PaddleOCR worker:

```bash
cd python/paddleocr_service
pip install -r requirements.txt
python main.py
```

3. In `backend/.env`:

```env
PADDLEOCR_SERVICE_URL=http://127.0.0.1:8765
PADDLEOCR_LANGS=en,ta,hi
```

4. Restart the Node API. If PaddleOCR is unavailable, OCR falls back to Tesseract automatically.

### Render / production

PaddleOCR is CPU/RAM intensive (~500 MB+ with models). Recommended:

- **Option A:** Second Render **Background Worker** or private service running `python main.py`, with `PADDLEOCR_SERVICE_URL` pointing to it from the Node service.
- **Option B:** Single VPS with Node + Python managed by systemd/supervisor.
- **Option C:** Subprocess fallback on the same host (higher latency on cold model load).

Do not assume PaddleOCR runs on Render free tier without verifying instance RAM (≥2 GB recommended).

See `backend/ocr/README.md` for architecture details.

## Flutter production build

**Do not pass `MONGO_CONNECTION_STRING`.** Point the app at your deployed API.

### Web

```bash
flutter build web --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=BASE_API_URL=https://YOUR_API_HOST \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset \
  --dart-define=ENABLE_FIREBASE=true
```

### Android / iOS

```bash
flutter build apk --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=BASE_API_URL=https://YOUR_API_HOST \
  --dart-define=HOST_LAN_IP= \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset \
  --dart-define=ENABLE_FIREBASE=true
```

Local phone testing against a PC backend still works with `adb reverse` / LAN discovery; production builds should use a public HTTPS `BASE_API_URL`.

## Environment Variables (`--dart-define`)

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `BASE_API_URL` | **Yes (prod)** | `http://localhost:3000` | Deployed Node API URL |
| `HOST_LAN_IP` | Dev only | — | Local LAN fallback for phones |
| `MONGO_CONNECTION_STRING` | **No** | empty | Unused in production; keep empty |
| `USE_DIRECT_MONGO` | No | `false` | Dev escape hatch only — do not enable in prod |
| `CLOUDINARY_CLOUD_NAME` | For uploads | — | Cloudinary cloud name |
| `CLOUDINARY_UPLOAD_PRESET` | For uploads | — | Unsigned upload preset |
| `CLOUDINARY_API_KEY` | For delete | — | Signed delete operations |
| `CLOUDINARY_API_SECRET` | For delete | — | Signed delete operations |
| `ENABLE_FIREBASE` | Phone OTP / FCM | `false` | `true` after Firebase setup |
| `FIREBASE_*` / `GOOGLE_*` | As needed | — | Auth and push |

## Module Integration Map

```
main.dart
  ├── EnvironmentConfig          → BASE_API_URL (+ optional Cloudinary/Firebase)
  ├── configureDependencies()    → GetIt (HTTP-backed data services)
  ├── AppBootstrap               → API health check + Notifications
  └── NotificationBootstrap      → FCM bind + tap routing

Authentication → SessionService → GoRouter role guards → Role dashboards
Data access    → Feature repos → HTTP /api/mongo/* → Node → Supabase
Cloudinary     → Land owner document uploads
Maps           → LocationService + GoogleMapView
Notifications  → NotificationHelper → DB history + FCM push
```

## Platform Setup

### Mobile (Android/iOS)

```bash
flutter create .
```

- Add Google Maps API key to `AndroidManifest.xml` / `AppDelegate`
- Run `flutterfire configure` for FCM, then set `ENABLE_FIREBASE=true`
- Configure Cloudinary unsigned preset for client uploads

### Web

- Add Google Maps JavaScript API script to `web/index.html` when deploying maps on web
- Register `https://YOUR_WEB_ORIGIN` in Google OAuth authorized origins

### Desktop

Desktop also uses the HTTP API (no direct Mongo). Prefer web/mobile for production clients.

## Launch expectations

Suitable for early / moderate traffic with refresh-based updates (pull-to-refresh, reopen screens). Not yet tuned for thousands of concurrent nearby searches without further SQL optimization.

## Verification Checklist

- [ ] `GET /api/health` → `"database": "supabase"`
- [ ] No MongoDB process required on the server
- [ ] Flutter build uses `BASE_API_URL` only (no Mongo URI)
- [ ] `flutter analyze` — zero errors
- [ ] Login as vehicle owner → `/vehicle-owner/dashboard`
- [ ] Login as land owner → `/land-owner/dashboard`
- [ ] Admin portal at `/admin/login`
- [ ] Employee portal at `/employee/login`
- [ ] Land owner document upload (Cloudinary configured)
- [ ] Find Nearby Parking returns approved, available, compatible spots
- [ ] Booking creates notification for vehicle owner
- [ ] Admin ticket assign triggers FCM push to assigned employee
