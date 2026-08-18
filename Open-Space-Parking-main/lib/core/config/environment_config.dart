import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';

class EnvironmentConfig {
  EnvironmentConfig._();
  static late final String appFlavor;
  static late final String baseApiUrl;
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

    baseApiUrl = const String.fromEnvironment(
      'BASE_API_URL',
      defaultValue: 'http://localhost:3000',
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
