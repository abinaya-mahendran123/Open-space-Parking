import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

enum NotificationSource { fcm, local, database }

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.recipientType,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.referenceId,
    this.source = NotificationSource.database,
  });

  final String id;
  final String recipientId;
  final NotificationRecipientType recipientType;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? referenceId;
  final NotificationSource source;

  AppNotification copyWith({bool? isRead, NotificationSource? source}) {
    return AppNotification(
      id: id,
      recipientId: recipientId,
      recipientType: recipientType,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
      source: source ?? this.source,
    );
  }

  @override
  List<Object?> get props => [
        id,
        recipientId,
        recipientType,
        title,
        message,
        createdAt,
        isRead,
        referenceId,
        source,
      ];
}
