import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/mongodb/models/transaction_documents.dart';
import 'package:open_space_parking/core/mongodb/repositories/mongo_repositories.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/domain/repositories/notification_repository.dart';

String _collectionForRecipient(NotificationRecipientType type) {
  return switch (type) {
    NotificationRecipientType.employee => AppConstants.employeesCollection,
    _ => AppConstants.usersCollection,
  };
}

class MongoNotificationRepository implements NotificationRepository {
  MongoNotificationRepository({
    required NotificationMongoRepository notificationMongoRepository,
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
  })  : _notificationMongoRepository = notificationMongoRepository,
        _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService;

  final NotificationMongoRepository _notificationMongoRepository;
  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;

  @override
  Future<List<AppNotification>> getHistory({
    required String recipientId,
    required NotificationRecipientType recipientType,
  }) async {
    await _ensureConnected();

    final canonical = await _notificationMongoRepository.findAll(
      filters: {
        'recipientId': recipientId,
        'recipientType': recipientType.value,
      },
    );

    final legacy = await _loadLegacyNotifications(
      recipientId: recipientId,
      recipientType: recipientType,
    );

    final merged = <String, AppNotification>{};
    for (final item in [...legacy, ...canonical.map(_fromDocument)]) {
      merged[item.id] = item;
    }

    final results = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<int> getUnreadCount({
    required String recipientId,
    required NotificationRecipientType recipientType,
  }) async {
    final history = await getHistory(
      recipientId: recipientId,
      recipientType: recipientType,
    );
    return history.where((n) => !n.isRead).length;
  }

  @override
  Future<AppNotification> save(AppNotification notification) async {
    final now = DateTime.now().toUtc();
    final doc = NotificationDocument(
      id: notification.id.isEmpty ? '' : notification.id,
      createdAt: notification.createdAt.isBefore(DateTime(2000))
          ? now
          : notification.createdAt,
      updatedAt: now,
      recipientId: notification.recipientId,
      recipientType: notification.recipientType.value,
      title: notification.title,
      message: notification.message,
      isRead: notification.isRead,
      referenceId: notification.referenceId,
    );

    final saved = await _notificationMongoRepository.create(doc);
    return _fromDocument(saved).copyWith(source: notification.source);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _ensureConnected();

    final canonical = await _notificationMongoRepository.findById(notificationId);
    if (canonical != null) {
      await _notificationMongoRepository.update(
        notificationId,
        NotificationDocument(
          id: canonical.id,
          createdAt: canonical.createdAt,
          updatedAt: DateTime.now().toUtc(),
          recipientId: canonical.recipientId,
          recipientType: canonical.recipientType,
          title: canonical.title,
          message: canonical.message,
          isRead: true,
          referenceId: canonical.referenceId,
        ),
      );
      return;
    }

    for (final collection in _legacyCollections) {
      try {
        await _collectionService.updateOne(
          collectionName: collection,
          selector: where.eq('_id', ObjectId.parse(notificationId)),
          modifier: modify.set('isRead', true),
        );
      } catch (_) {
        // Ignore invalid legacy ids.
      }
    }
  }

  @override
  Future<void> markAllAsRead({
    required String recipientId,
    required NotificationRecipientType recipientType,
  }) async {
    final history = await getHistory(
      recipientId: recipientId,
      recipientType: recipientType,
    );

    for (final notification in history.where((n) => !n.isRead)) {
      await markAsRead(notification.id);
    }
  }

  @override
  Future<void> saveDeviceToken({
    required String userId,
    required String token,
    required NotificationRecipientType recipientType,
  }) async {
    await _ensureConnected();

    try {
      await _collectionService.updateOne(
        collectionName: _collectionForRecipient(recipientType),
        selector: where.eq('_id', ObjectId.parse(userId)),
        modifier: modify
            .set('fcmToken', token)
            .set('fcmTokenUpdatedAt', DateTime.now().toUtc().toIso8601String())
            .set('recipientType', recipientType.value),
      );
    } catch (_) {
      // User id may not be a valid ObjectId in dev fixtures.
    }
  }

  Future<List<AppNotification>> _loadLegacyNotifications({
    required String recipientId,
    required NotificationRecipientType recipientType,
  }) async {
    final collection = _legacyCollectionFor(recipientType);
    if (collection == null) return [];

    final field = _legacyRecipientField(recipientType);
    final results = await _collectionService.findMany(
      collectionName: collection,
      selector: where.eq(field, recipientId),
    );

    return results.map((map) => _fromLegacyMap(map, recipientType)).toList();
  }

  String? _legacyCollectionFor(NotificationRecipientType type) {
    return switch (type) {
      NotificationRecipientType.landOwner =>
        AppConstants.landOwnerNotificationsCollection,
      NotificationRecipientType.vehicleOwner =>
        AppConstants.vehicleOwnerNotificationsCollection,
      NotificationRecipientType.employee =>
        AppConstants.employeeNotificationsCollection,
      NotificationRecipientType.admin => null,
    };
  }

  String _legacyRecipientField(NotificationRecipientType type) {
    return switch (type) {
      NotificationRecipientType.landOwner => 'ownerId',
      NotificationRecipientType.vehicleOwner => 'vehicleOwnerId',
      NotificationRecipientType.employee => 'employeeId',
      NotificationRecipientType.admin => 'recipientId',
    };
  }

  AppNotification _fromDocument(NotificationDocument doc) {
    return AppNotification(
      id: doc.id,
      recipientId: doc.recipientId,
      recipientType: NotificationRecipientType.fromValue(doc.recipientType),
      title: doc.title,
      message: doc.message,
      createdAt: doc.createdAt,
      isRead: doc.isRead,
      referenceId: doc.referenceId,
      source: NotificationSource.database,
    );
  }

  AppNotification _fromLegacyMap(
    Map<String, dynamic> map,
    NotificationRecipientType recipientType,
  ) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();

    return AppNotification(
      id: id,
      recipientId: map['ownerId'] as String? ??
          map['vehicleOwnerId'] as String? ??
          map['employeeId'] as String? ??
          '',
      recipientType: recipientType,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
      referenceId: map['ticketId'] as String? ?? map['bookingRef'] as String?,
      source: NotificationSource.database,
    );
  }

  static const _legacyCollections = [
    AppConstants.landOwnerNotificationsCollection,
    AppConstants.vehicleOwnerNotificationsCollection,
    AppConstants.employeeNotificationsCollection,
  ];

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}
