import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static Future<void>? _inFlight;

  static Future<void> ensureInitialized() {
    final existing = _inFlight;
    if (existing != null) return existing;
    return _inFlight = _initialize().whenComplete(() {
      // Allow a later retry if the first attempt failed.
      if (!ready) _inFlight = null;
    });
  }

  static Future<void> _initialize() async {
    try {
      final options = EnvironmentConfig.firebaseOptions;
      if (Firebase.apps.isNotEmpty) {
        final current = Firebase.app();
        if (options == null || current.options.appId == options.appId) {
          ready = true;
          return;
        }
        await current.delete();
      }

      if (options != null) {
        await Firebase.initializeApp(options: options).timeout(
          const Duration(seconds: 20),
        );
      } else if (kIsWeb) {
        AppLogger.w(
          'Firebase web options are missing. Pass FIREBASE_API_KEY, '
          'FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID, '
          'and FIREBASE_AUTH_DOMAIN.',
        );
        return;
      } else {
        await Firebase.initializeApp().timeout(const Duration(seconds: 20));
      }
      ready = true;
      AppLogger.i('Firebase initialized (${Firebase.app().options.appId})');
    } catch (e, stack) {
      ready = false;
      AppLogger.w('Firebase initialization failed: $e');
      AppLogger.w(stack.toString());
    }
  }
}
