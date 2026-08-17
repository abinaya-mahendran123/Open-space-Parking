# Notification Module

Push and local notifications with MongoDB history, Riverpod state, and Material 3 UI.

## Features

| Feature | Implementation |
|---------|----------------|
| **Firebase Cloud Messaging** | `FcmService` — foreground, background, tap handling |
| **Local Notifications** | `LocalNotificationService` — in-app alerts + FCM foreground display |
| **Notification History** | `MongoNotificationRepository` — canonical + legacy MongoDB collections |
| **Notification Service** | `NotificationService` — orchestrates FCM, local, and persistence |
| **Riverpod** | `notification_providers.dart` |
| **Material 3** | `NotificationTile`, `NotificationHistoryView`, `NotificationBadge` |

## Setup

### 1. Firebase project

1. Create a Firebase project and add Android/iOS apps.
2. Run `flutterfire configure` (requires platform folders: `flutter create .`).
3. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

### 2. Android (AndroidManifest.xml)

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="open_space_parking_alerts" />
```

### 3. Run

```bash
flutter run --dart-define=ENABLE_FIREBASE=true
```

Set `ENABLE_FIREBASE=false` to disable FCM (local notifications still work).

## Architecture

```
lib/features/notification/
├── data/
│   ├── repositories/mongo_notification_repository.dart
│   └── services/
│       ├── fcm_service.dart
│       ├── local_notification_service.dart
│       └── notification_service.dart
├── domain/
│   ├── entities/
│   └── repositories/notification_repository.dart
├── firebase/firebase_messaging_background.dart
└── presentation/
    ├── providers/notification_providers.dart
    └── widgets/
```

## Usage

```dart
NotificationHistoryView(
  recipientId: userId,
  recipientType: NotificationRecipientType.landOwner,
)

NotificationBadge(
  recipientId: userId,
  recipientType: NotificationRecipientType.vehicleOwner,
  child: IconButton(
    icon: Icon(Icons.notifications_outlined),
    onPressed: () => context.push('/vehicle-owner/notifications'),
  ),
)
```

## MongoDB

Canonical collection: `notifications`

Legacy collections merged into history:
- `land_owner_notifications`
- `vehicle_owner_notifications`
- `employee_notifications`

FCM device tokens stored on user documents: `fcmToken`, `fcmTokenUpdatedAt`.

## FCM payload format

```json
{
  "title": "Booking confirmed",
  "body": "Your parking at Downtown is confirmed.",
  "route": "/vehicle-owner/history",
  "referenceId": "OSP-20260807-1234",
  "recipientId": "user_id",
  "recipientType": "vehicle_owner"
}
```
