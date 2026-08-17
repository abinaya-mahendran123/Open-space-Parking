import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:open_space_parking/features/notification/data/services/local_notification_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_payload.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final payload = NotificationPayload.fromFcmData({
    ...message.data,
    if (message.notification?.title != null)
      'title': message.notification!.title,
    if (message.notification?.body != null) 'body': message.notification!.body,
  });

  final localService = LocalNotificationService();
  await localService.initialize();
  await localService.show(payload);
}
