# Open Space Parking

Initial production-ready Flutter foundation with:

- Material 3 theming
- Riverpod state management
- GoRouter navigation
- Clean architecture skeleton
- Repository pattern base abstractions
- Dependency injection (GetIt)
- Reusable shared widgets
- Environment configuration and MongoDB service layer

## Run

1. Install Flutter stable SDK.
2. Run lutter pub get.
3. Run with environment values:
   - lutter run --dart-define=APP_FLAVOR=dev --dart-define=BASE_API_URL=https://api.example.com --dart-define=MONGO_CONNECTION_STRING=mongodb://localhost:27017/open_space_parking
