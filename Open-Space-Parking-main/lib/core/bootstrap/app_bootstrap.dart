import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_integration_service.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/data/services/notification_service.dart';

/// Initializes external services with graceful degradation for production.
class AppBootstrap {
  AppBootstrap._();

  static bool mongoReady = false;
  static bool notificationsReady = false;

  static Future<void> initialize() async {
    await _initializeMongo();
    await _initializeNotifications();
  }

  static Future<void> _initializeMongo() async {
    try {
      await sl<MongoIntegrationService>().initialize();
      mongoReady = true;
      AppLogger.i('MongoDB connected and indexes ensured');
    } catch (e, stack) {
      mongoReady = false;
      AppLogger.w('MongoDB initialization failed — app runs in offline mode: $e');
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
