# Open Space Parking

Production-oriented Flutter app with:

- Material 3 theming
- Riverpod state management
- GoRouter navigation
- Clean architecture skeleton
- Repository pattern + GetIt DI
- Node.js API backed by **Supabase PostgreSQL** (no MongoDB server in production)

See [DEPLOYMENT.md](DEPLOYMENT.md) for production setup.

## Run (local)

1. Install Flutter stable SDK and Node.js 18+.
2. Configure `backend/.env` with `DATABASE_URL` (Supabase). Keep `MONGO_CONNECTION_STRING` empty.
3. Start API: `cd backend && npm start` — logs should say `Database: Supabase PostgreSQL`.
4. `flutter pub get`
5. Run against the API:

```bash
flutter run --dart-define=APP_FLAVOR=dev --dart-define=BASE_API_URL=http://localhost:3000
```

Do **not** pass `MONGO_CONNECTION_STRING` for web/mobile/desktop production builds.
