import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';

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
      defaultValue: '192.168.88.8',
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

    whatsappProvider = WhatsAppProviderType.fromValue(
      const String.fromEnvironment(
        'WHATSAPP_PROVIDER',
        defaultValue: 'none',
      ),
    );

    metaWhatsAppPhoneNumberId = const String.fromEnvironment(
      'META_WHATSAPP_PHONE_NUMBER_ID',
      defaultValue: '',
    );

    metaWhatsAppAccessToken = const String.fromEnvironment(
      'META_WHATSAPP_ACCESS_TOKEN',
      defaultValue: '',
    );

    twilioAccountSid = const String.fromEnvironment(
      'TWILIO_ACCOUNT_SID',
      defaultValue: '',
    );

    twilioAuthToken = const String.fromEnvironment(
      'TWILIO_AUTH_TOKEN',
      defaultValue: '',
    );

    twilioWhatsAppFrom = const String.fromEnvironment(
      'TWILIO_WHATSAPP_FROM',
      defaultValue: '',
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

    // Physical phones cannot use this PC's localhost unless `adb reverse` is set.
    // Try the PC Wi-Fi IP first, then USB reverse, then emulator.
    if (lanIp.trim().isNotEmpty) {
      final value = lanIp.trim();
      add(value.startsWith('http') ? value : 'http://$value:3000');
    }
    add(configured);
    add('http://127.0.0.1:3000');
    add('http://localhost:3000');
    add('http://10.0.2.2:3000');

    final client = http.Client();
    try {
      for (final base in candidates) {
        try {
          final response = await client
              .get(Uri.parse('$base/api/health'))
              .timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) return base;
        } catch (_) {}
      }
    } finally {
      client.close();
    }

    if (lanIp.trim().isNotEmpty) {
      final value = lanIp.trim();
      return value.startsWith('http') ? value : 'http://$value:3000';
    }
    return configured;
  }

  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static bool get canDeleteFromCloudinary =>
      cloudinaryApiKey.isNotEmpty && cloudinaryApiSecret.isNotEmpty;

  /// When false, FCM initializes in a no-op mode (local notifications still work).
  static bool get isFirebaseConfigured =>
      const bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false);

  static late final WhatsAppProviderType whatsappProvider;
  static late final String metaWhatsAppPhoneNumberId;
  static late final String metaWhatsAppAccessToken;
  static late final String twilioAccountSid;
  static late final String twilioAuthToken;
  static late final String twilioWhatsAppFrom;
  static late final String googleWebClientId;
  static late final String googleServerClientId;

  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;

  static bool get isMetaWhatsAppConfigured =>
      metaWhatsAppPhoneNumberId.isNotEmpty &&
      metaWhatsAppAccessToken.isNotEmpty;

  static bool get isTwilioWhatsAppConfigured =>
      twilioAccountSid.isNotEmpty &&
      twilioAuthToken.isNotEmpty &&
      twilioWhatsAppFrom.isNotEmpty;

  static bool get isWhatsAppConfigured {
    return switch (whatsappProvider) {
      WhatsAppProviderType.meta => isMetaWhatsAppConfigured,
      WhatsAppProviderType.twilio => isTwilioWhatsAppConfigured,
      WhatsAppProviderType.none => false,
    };
  }
}
