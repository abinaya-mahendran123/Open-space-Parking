# Production Deployment Guide

## Prerequisites

- Flutter SDK 3.16+
- MongoDB instance (Atlas or self-hosted)
- Optional: Cloudinary account, Firebase project (required for phone OTP)

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
| `ENABLE_FIREBASE` | Phone OTP / FCM | `false` | `true` after FlutterFire setup, or pass Firebase options below |
| `FIREBASE_API_KEY` | Phone OTP | — | Firebase Web API key |
| `FIREBASE_APP_ID` | Phone OTP | — | Firebase app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Phone OTP | — | Firebase sender ID |
| `FIREBASE_PROJECT_ID` | Phone OTP | — | Firebase project ID |
| `FIREBASE_AUTH_DOMAIN` | Phone OTP (web) | — | `your-project.firebaseapp.com` |
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
- [ ] Admin ticket assign triggers FCM push to assigned employee
