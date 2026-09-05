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

    // Prefer local API in development so Chrome (random port) uses this PC's backend.
    const configuredApiUrl = String.fromEnvironment(
      'BASE_API_URL',
      defaultValue: 'http://127.0.0.1:3000',
    );
    const hostLanIp = String.fromEnvironment(
      'HOST_LAN_IP',
      defaultValue: '192.168.88.3',
    );

    _configuredApiUrl = configuredApiUrl;
    _hostLanIp = hostLanIp;

    // Prefer configured URL immediately so startup is never blocked on health
    // probes. Resolve a reachable host in the background and hot-swap.
    baseApiUrl = configuredApiUrl;
    if (!(kIsWeb && kReleaseMode)) {
      unawaited(() async {
        final resolved = await resolveReachableApiUrl(
          configured: configuredApiUrl,
          lanIp: hostLanIp,
        );
        if (resolved != baseApiUrl) {
          baseApiUrl = resolved;
        }
      }());
    }

    // Unused for Supabase-only production (Flutter → Node API → Postgres).
    // Only needed with --dart-define=USE_DIRECT_MONGO=true for local debugging.
    mongoConnectionString = const String.fromEnvironment(
      'MONGO_CONNECTION_STRING',
      defaultValue: '',
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
      defaultValue: '1:794049298844:android:6763c9ecf56b7a3ab68859',
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
          '794049298844-v8f8okbjfb4memdcjugcpqfd58tk71j0.apps.googleusercontent.com',
    );

    // Web client ID used as serverClientId on Android/iOS so ID tokens are issued.
    googleServerClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue:
          '794049298844-v8f8okbjfb4memdcjugcpqfd58tk71j0.apps.googleusercontent.com',
    );
  }

  static late String _configuredApiUrl;
  static late String _hostLanIp;

  /// Retry API discovery (USB reverse or LAN) after a failed request.
  static Future<String> refreshReachableApiUrl() async {
    if (kIsWeb && kReleaseMode) return baseApiUrl;
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

    final configuredTrimmed = configured.trim().replaceAll(RegExp(r'/+$'), '');
    // In debug, always try local first so unfinished backend work is visible.
    // Hosted-only preference is for release / production traffic.
    final preferHostedOnly =
        configuredTrimmed.startsWith('https://') && kReleaseMode;

    if (preferHostedOnly) {
      add(configuredTrimmed);
      add('https://open-space-parking.onrender.com');
    } else {
      add('http://127.0.0.1:3000');
      add('http://localhost:3000');
      add(configuredTrimmed);
      add('https://open-space-parking.onrender.com');
      add('http://10.0.2.2:3000');
      if (lanIp.trim().isNotEmpty) {
        final value = lanIp.trim();
        add(value.startsWith('http') ? value : 'http://$value:3000');
      }
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
    return configuredTrimmed.isNotEmpty ? configuredTrimmed : configured;
  }

  static const String phoneUnreachableMessage =
      'Cannot reach the server. The hosted API may still be starting '
      '(Render can take 1–2 minutes after a deploy). Wait until the service '
      'shows Live, then tap Re-scan.';

  static Duration _healthTimeoutFor(String base) {
    return base.startsWith('https://')
        ? const Duration(seconds: 45)
        : const Duration(seconds: 3);
  }

  static Future<String?> _firstHealthy(
    http.Client client,
    List<String> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    // Prefer local hosts sequentially so a warm Render never wins the race.
    final local = <String>[];
    final remote = <String>[];
    for (final base in candidates) {
      if (base.contains('127.0.0.1') ||
          base.contains('localhost') ||
          base.contains('10.0.2.2')) {
        local.add(base);
      } else {
        remote.add(base);
      }
    }

    for (final base in local) {
      try {
        final response = await client
            .get(Uri.parse('$base/api/health'))
            .timeout(_healthTimeoutFor(base));
        if (response.statusCode == 200) return base;
      } catch (_) {}
    }

    if (remote.isEmpty) return null;

    final completer = Completer<String?>();
    var pending = remote.length;

    for (final base in remote) {
      () async {
        try {
          final response = await client
              .get(Uri.parse('$base/api/health'))
              .timeout(_healthTimeoutFor(base));
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

  /// True when a direct Mongo URI was provided (dev escape hatch only).
  static bool get hasMongoConnectionString =>
      mongoConnectionString.trim().isNotEmpty;

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
