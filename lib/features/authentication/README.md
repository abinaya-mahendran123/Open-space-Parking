# Authentication Feature

Implemented:

- Splash flow and session restore
- Onboarding
- Role selection (Vehicle Owner, Land Owner)
- Login
- Register
- Forgot password
- Isolated Admin login and Admin portal route
- Riverpod auth state/session providers
- MongoDB-backed authentication repository
- Google Sign-In (official `google_sign_in` plugin) for Android, iOS, and Web

## Google Sign-In

Uses Google's official account picker / Identity Services UI. The app never
collects or stores Google passwords. OAuth **client secrets are not** embedded
in the Flutter app.

### Flow

1. User taps **Sign in with Google** or **Sign up with Google**
2. Google account picker (platform UI)
3. OAuth authentication + ID token verification via backend `/api/auth/google`
4. MongoDB lookup by `googleId` / email
5. Existing user → session with stored role → dashboard  
   New user (Sign Up only) → create with selected Vehicle Owner / Land Owner role

Admin and Employee roles cannot be created through Google Sign-Up.

### Configuration

| Define | Purpose |
|--------|---------|
| `GOOGLE_WEB_CLIENT_ID` | OAuth **Web** client ID (Web + `serverClientId` default) |
| `GOOGLE_SERVER_CLIENT_ID` | Optional override for Android/iOS ID tokens (usually same Web client ID) |

Web also reads the client ID from `web/index.html`:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

**Web origins** (Google Cloud Console → Credentials):

- `http://localhost:8080` (recommended fixed port: `flutter run -d chrome --web-port=8080`)

**Android:**

1. Create an OAuth Android client with package `com.example.open_space_parking` and your debug/release SHA-1
2. Keep the Web client ID for `serverClientId` so ID tokens are returned
3. Internet permission is declared in `AndroidManifest.xml`

**iOS:**

1. Generate the iOS platform if needed: `flutter create . --platforms=ios`
2. Create an OAuth iOS client and add the URL scheme (`REVERSED_CLIENT_ID`) to `ios/Runner/Info.plist`
3. Use the same Web client ID as `serverClientId` / `GOOGLE_SERVER_CLIENT_ID`

### Account switching

Each Google tap clears the cached Google session first (`signOut`), so Google
shows the account chooser / “Add another account” flow again.
