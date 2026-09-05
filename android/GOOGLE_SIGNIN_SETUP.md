# Google Sign-In — Android fix checklist

Your app package: `com.estar.openspaceparking`  
Firebase project: `open-space-parking` (`794049298844`)

## Why it failed

`android/app/google-services.json` currently has `"oauth_client": []`.  
That means Google has no Android OAuth client for this package/SHA-1, which
shows up as ApiException **10** / developer error.

## Fix (do this in Firebase Console)

1. Open https://console.firebase.google.com/project/open-space-parking/settings/general
2. Select the Android app `com.estar.openspaceparking`
3. Click **Add fingerprint** and paste this **debug SHA-1**:

   ```
   13:2F:78:D3:A7:FA:52:92:F6:70:C4:93:A1:94:49:C9:F4:75:47:6B
   ```

4. Go to **Authentication → Sign-in method → Google → Enable → Save**
5. Back on Project settings, download **google-services.json**
6. Replace `android/app/google-services.json` with the new file  
   (it should list one or more entries under `oauth_client`)
7. In Google Cloud Console for the **same** project, copy the **Web client** ID  
   (`….apps.googleusercontent.com`) and use it as:
   - `GOOGLE_WEB_CLIENT_ID`
   - `GOOGLE_SERVER_CLIENT_ID`
   - `web/index.html` → `meta name="google-signin-client_id"`
8. Fully restart the app (`flutter run` / reinstall), not just hot reload

## Verify SHA-1 again

```powershell
keytool -list -v -alias androiddebugkey -keystore $env:USERPROFILE\.android\debug.keystore -storepass android -keypass android
```
