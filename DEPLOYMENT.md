# Production Deployment Guide

## Prerequisites

- Flutter SDK 3.16+
- MongoDB instance (Atlas or self-hosted)
- Optional: Cloudinary account, Firebase project, Meta/Twilio WhatsApp API

## Build & Run

```bash
flutter pub get
flutter test
flutter run -d chrome --web-port=8080   # web (fixed port)
flutter run -d android  # after flutter create .
```

Web always uses **http://localhost:8080** so Google OAuth and bookmarks stay stable.
Add that origin in Google Cloud Console → Credentials → Authorized JavaScript origins.
### Production build (web)

```bash
flutter build web --release \
  --dart-define=MONGO_CONNECTION_STRING=mongodb+srv://... \
  --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset
```

## Environment Variables (`--dart-define`)

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `MONGO_CONNECTION_STRING` | Yes (prod) | `mongodb://localhost:27017/open_space_parking` | MongoDB connection |
| `CLOUDINARY_CLOUD_NAME` | For uploads | — | Cloudinary cloud name |
| `CLOUDINARY_UPLOAD_PRESET` | For uploads | — | Unsigned upload preset |
| `CLOUDINARY_API_KEY` | For delete | — | Signed delete operations |
| `CLOUDINARY_API_SECRET` | For delete | — | Signed delete operations |
| `ENABLE_FIREBASE` | No | `false` | Set `true` after FlutterFire setup |
| `WHATSAPP_PROVIDER` | No | `none` | `meta`, `twilio`, or `none` |
| `META_WHATSAPP_PHONE_NUMBER_ID` | Meta WA | — | Meta Graph API phone ID |
| `META_WHATSAPP_ACCESS_TOKEN` | Meta WA | — | Meta access token |
| `TWILIO_ACCOUNT_SID` | Twilio WA | — | Twilio account SID |
| `TWILIO_AUTH_TOKEN` | Twilio WA | — | Twilio auth token |
| `TWILIO_WHATSAPP_FROM` | Twilio WA | — | Twilio WhatsApp sender |
| `GOOGLE_WEB_CLIENT_ID` | Google Sign-In | Web client ID | OAuth Web client for Web/Android/iOS |
| `GOOGLE_SERVER_CLIENT_ID` | Google Sign-In | same as web | `serverClientId` for mobile ID tokens |

## Module Integration Map

```
main.dart
  ├── EnvironmentConfig
  ├── configureDependencies()     → GetIt (all repos & services)
  ├── AppBootstrap                → MongoDB + Notifications (graceful fallback)
  └── NotificationBootstrap       → FCM bind + tap routing

Authentication → SessionService → GoRouter role guards → Role dashboards
MongoDB        → Feature repos + canonical MongoDataService layer
Cloudinary     → Land owner document uploads → DocumentMongoRepository
Maps           → LocationService + GoogleMapView + map picker routes
Notifications  → NotificationHelper → MongoDB history + local push
WhatsApp       → Admin assignEmployee + approve/reject status updates
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

## Verification Checklist

- [ ] `flutter analyze` — zero errors
- [ ] `flutter test` — all tests pass
- [ ] Login as vehicle owner → `/vehicle-owner/dashboard`
- [ ] Login as land owner → `/land-owner/dashboard`
- [ ] Admin portal at `/admin/login`
- [ ] Employee portal at `/employee/login`
- [ ] Land owner document upload (Cloudinary configured)
- [ ] Map picker from land owner flow
- [ ] Booking creates notification for vehicle owner
- [ ] Admin ticket assign triggers WhatsApp + notifications
