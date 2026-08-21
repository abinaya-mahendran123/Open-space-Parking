import 'package:flutter/foundation.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/di/mongo_service_registration.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_integration_service.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';

enum ApiConnectionStatus { unknown, ready, offline }

/// Initializes external services with graceful degradation for production.
class AppBootstrap {
  AppBootstrap._();

  /// Backend API (and data layer) is reachable.
  static bool mongoReady = false;
  static bool notificationsReady = false;
  static final apiStatus = ValueNotifier<ApiConnectionStatus>(
    ApiConnectionStatus.unknown,
  );

  static Future<void> initialize() async {
    await _initializeDataLayer();
    await _initializeNotifications();
  }

  static Future<bool> retryApi() async {
    try {
      await EnvironmentConfig.refreshReachableApiUrl();
    } catch (_) {}
    await _initializeDataLayer();
    return mongoReady;
  }

  static Future<void> _initializeDataLayer() async {
    try {
      await sl<MongoIntegrationService>().initialize();
      mongoReady = true;
      apiStatus.value = ApiConnectionStatus.ready;
      if (useBackendApiDataLayer) {
        AppLogger.i('Backend API connected (Supabase via Node)');
      } else {
        AppLogger.i('Direct MongoDB connected and indexes ensured');
      }
    } catch (e, stack) {
      mongoReady = false;
      apiStatus.value = ApiConnectionStatus.offline;
      AppLogger.w(
        useBackendApiDataLayer
            ? 'Backend API initialization failed — app runs in offline mode: $e'
            : 'MongoDB initialization failed — app runs in offline mode: $e',
      );
      AppLogger.w(stack.toString());
    }
  }

  static Future<void> _initializeNotifications() async {
    try {
      await sl<NotificationService>().initialize();
      await sl<NotificationService>().requestPermissions();
      notificationsReady = true;
      AppLogger.i('Notification services initialized');
    } catch (e, stack) {
      notificationsReady = false;
      AppLogger.w('Notification initialization failed: $e');
      AppLogger.w(stack.toString());
    }
  }
}
