import 'package:flutter/foundation.dart';

/// Platform capabilities for this app's MongoDB architecture.
abstract final class PlatformSupport {
  /// Browsers use the REST API instead of raw MongoDB TCP connections.
  static bool get supportsDirectMongoConnection => !kIsWeb;

  static const String webApiUnavailableMessage =
      'Cannot reach the API server. Start it with: cd backend && npm install && npm start';
}
