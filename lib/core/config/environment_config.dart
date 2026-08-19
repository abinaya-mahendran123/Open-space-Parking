import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EnvironmentConfig {
  EnvironmentConfig._();
  static late final String appFlavor;
  static late String baseApiUrl;
  static late final String mongoConnectionString;
  static late final String cloudinaryCloudName;
  static late final String cloudinaryUploadPreset;
  static late final String cloudinaryApiKey;
  static late final String cloudinaryApiSecret;

  static Future<void> initialize() async {
    appFlavor = const String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'dev',
    );

    // Chrome: localhost is this PC. Phone: localhost is the phone unless
    // `adb reverse` is set, so we also probe 127.0.0.1, emulator, and LAN IP.
    const configuredApiUrl = String.fromEnvironment(
      'BASE_API_URL',
      defaultValue: 'http://localhost:3000',
    );
    const hostLanIp = String.fromEnvironment(
      'HOST_LAN_IP',
      defaultValue: '192.168.88.10',
    );

    _configuredApiUrl = configuredApiUrl;
    _hostLanIp = hostLanIp;

    baseApiUrl = kIsWeb
        ? configuredApiUrl
        : await resolveReachableApiUrl(
            configured: configuredApiUrl,
            lanIp: hostLanIp,
          );

    mongoConnectionString = const String.fromEnvironment(
      'MONGO_CONNECTION_STRING',
      defaultValue: 'mongodb://localhost:27017/open_space_parking',
    );

    cloudinaryCloudName = const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: '',
    );

    cloudinaryUploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: '',
    );

    cloudinaryApiKey = const String.fromEnvironment(
      'CLOUDINARY_API_KEY',
      defaultValue: '',
    );

    cloudinaryApiSecret = const String.fromEnvironment(
      'CLOUDINARY_API_SECRET',
      defaultValue: '',
    );

    firebaseApiKey = const String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: 'AIzaSyCqLObK4oe-Y7huBVTsB1UmSl8EGqxUu6w',
    );
    firebaseAppId = const String.fromEnvironment(
      'FIREBASE_APP_ID',
      defaultValue: '',
    );
    firebaseWebAppId = const String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '1:794049298844:web:e2d18b28cd68232fb68859',
    );
    firebaseAndroidAppId = const String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:794049298844:android:6763c9ecfb6b7a3ab68859',
    );
    firebaseMessagingSenderId = const String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '794049298844',
    );
    firebaseProjectId = const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'open-space-parking',
    );
    firebaseAuthDomain = const String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'open-space-parking.firebaseapp.com',
    );
    firebaseStorageBucket = const String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'open-space-parking.firebasestorage.app',
    );

    googleWebClientId = const String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '514956128372-a1aac5qlpe4s0i4ej0tqr6251m1uvb4k.apps.googleusercontent.com',
    );

    // Web client ID used as serverClientId on Android/iOS so ID tokens are issued.
    googleServerClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue:
          '514956128372-a1aac5qlpe4s0i4ej0tqr6251m1uvb4k.apps.googleusercontent.com',
    );
  }

  static late String _configuredApiUrl;
  static late String _hostLanIp;

  /// Retry API discovery (USB reverse or LAN) after a failed request.
  static Future<String> refreshReachableApiUrl() async {
    if (kIsWeb) return baseApiUrl;
    baseApiUrl = await resolveReachableApiUrl(
      configured: _configuredApiUrl,
      lanIp: _hostLanIp,
    );
    return baseApiUrl;
  }

  /// Picks a host the current device can actually reach (USB reverse, emulator, or LAN).
  static Future<String> resolveReachableApiUrl({
    required String configured,
    required String lanIp,
  }) async {
    final candidates = <String>[];

    void add(String url) {
      final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
      if (normalized.isEmpty || candidates.contains(normalized)) return;
      candidates.add(normalized);
    }

    add('http://127.0.0.1:3000');
    add('http://localhost:3000');
    // USB reverse makes 127.0.0.1 on the phone reach this PC. Try that first.
    // Keep the explicit configured value early as well in case the launch config
    // points to a custom backend host/port.
    add(configured);
    add('http://10.0.2.2:3000');
    // LAN IP is a fallback when the cable is unplugged (must be the PC's current IP).
    if (lanIp.trim().isNotEmpty) {
      final value = lanIp.trim();
      add(value.startsWith('http') ? value : 'http://$value:3000');
    }

    final client = http.Client();
    try {
      final found = await _firstHealthy(client, candidates);
      if (found != null) {
        debugPrint('API reachable at $found');
        return found;
      }
    } finally {
      client.close();
    }

    debugPrint('API discovery failed. Tried: ${candidates.join(', ')}');
    // If nothing answered yet, keep the explicitly configured base URL instead of
    // forcing a possibly stale LAN IP. A later retry can still switch to LAN once
    // the backend is reachable.
    return configured;
  }

  static const String phoneUnreachableMessage =
      'Cannot reach the server from this phone. '
      'Keep the USB cable connected, keep the backend running '
      '(cd backend && npm start), then run: adb reverse tcp:3000 tcp:3000';

  static Future<String?> _firstHealthy(
    http.Client client,
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return null;
    final completer = Completer<String?>();
    var pending = candidates.length;

    for (final base in candidates) {
      () async {
        try {
          final response = await client
              .get(Uri.parse('$base/api/health'))
              .timeout(const Duration(milliseconds: 3000));
          if (response.statusCode == 200 && !completer.isCompleted) {
            completer.complete(base);
          }
        } catch (_) {
        } finally {
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }();
    }

    return completer.future;
  }

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static bool get canDeleteFromCloudinary =>
      cloudinaryApiKey.isNotEmpty && cloudinaryApiSecret.isNotEmpty;

  static late final String firebaseApiKey;
  static late final String firebaseAppId;
  static late final String firebaseWebAppId;
  static late final String firebaseAndroidAppId;
  static late final String firebaseMessagingSenderId;
  static late final String firebaseProjectId;
  static late final String firebaseAuthDomain;
  static late final String firebaseStorageBucket;

  static String get _platformFirebaseAppId {
    if (kIsWeb) {
      if (firebaseWebAppId.isNotEmpty) return firebaseWebAppId;
    } else if (firebaseAndroidAppId.isNotEmpty) {
      return firebaseAndroidAppId;
    }
    return firebaseAppId;
  }

  static bool get hasFirebaseOptions =>
      firebaseApiKey.isNotEmpty &&
      _platformFirebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static FirebaseOptions? get firebaseOptions {
    if (!hasFirebaseOptions) return null;
    return FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: _platformFirebaseAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
      storageBucket:
          firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    );
  }

  /// Phone OTP needs a Firebase app. Set options via dart-define, or
  /// `ENABLE_FIREBASE=true` after `flutterfire configure`.
  static bool get isFirebaseAuthConfigured =>
      hasFirebaseOptions ||
      const bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false);

  /// When false, FCM initializes in a no-op mode (local notifications still work).
  static bool get isFirebaseConfigured =>
      const bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false);

  static late final String googleWebClientId;
  static late final String googleServerClientId;

  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;
}
