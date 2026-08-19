import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

/// Sends FCM push notifications through the backend (Firebase Admin SDK).
class PushNotificationService {
  PushNotificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<bool> send({
    required String recipientId,
    required NotificationRecipientType recipientType,
    required String title,
    required String body,
    String? route,
    String? referenceId,
  }) async {
    if (!EnvironmentConfig.isFirebaseConfigured) {
      AppLogger.w('FCM push skipped: ENABLE_FIREBASE is false.');
      return false;
    }

    try {
      final response = await _apiClient.post('/api/notifications/push', {
        'recipientId': recipientId,
        'recipientType': recipientType.value,
        'title': title,
        'body': body,
        if (route != null) 'route': route,
        if (referenceId != null) 'referenceId': referenceId,
      });
      final sent = response['sent'] == true;
      if (!sent) {
        AppLogger.w(
          'FCM push not delivered: ${response['reason'] ?? 'unknown reason'}',
        );
      }
      return sent;
    } catch (error) {
      AppLogger.w('FCM push request failed: $error');
      return false;
    }
  }
}
