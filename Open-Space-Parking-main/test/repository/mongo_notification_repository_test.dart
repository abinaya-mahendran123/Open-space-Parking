import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/mongodb/models/transaction_documents.dart';
import 'package:open_space_parking/features/notification/data/repositories/mongo_notification_repository.dart';
import 'package:open_space_parking/features/notification/domain/entities/app_notification.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';

import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockNotificationMongoRepository notificationMongoRepository;
  late MockMongoDatabaseService databaseService;
  late MockMongoCollectionService collectionService;
  late MongoNotificationRepository repository;

  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  setUp(() {
    notificationMongoRepository = MockNotificationMongoRepository();
    databaseService = MockMongoDatabaseService();
    collectionService = MockMongoCollectionService();
    repository = MongoNotificationRepository(
      notificationMongoRepository: notificationMongoRepository,
      mongoDatabaseService: databaseService,
      mongoCollectionService: collectionService,
    );

    when(() => databaseService.isConnected).thenReturn(true);
  });

  NotificationDocument sampleDocument({bool isRead = false, String id = 'notif-1'}) {
    final now = DateTime.utc(2026, 8, 7, 12);
    return NotificationDocument(
      id: id,
      createdAt: now,
      updatedAt: now,
      recipientId: 'owner-1',
      recipientType: NotificationRecipientType.landOwner.value,
      title: 'Update',
      message: 'Your request was reviewed.',
      isRead: isRead,
    );
  }

  group('MongoNotificationRepository', () {
    test('getHistory merges canonical and legacy notifications', () async {
      when(
        () => notificationMongoRepository.findAll(
          filters: any(named: 'filters'),
        ),
      ).thenAnswer((_) async => [sampleDocument()]);

      when(
        () => collectionService.findMany(
          collectionName: AppConstants.landOwnerNotificationsCollection,
          selector: any(named: 'selector'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            '_id': 'legacy-1',
            'ownerId': 'owner-1',
            'title': 'Legacy',
            'message': 'Legacy message',
            'createdAt': DateTime.utc(2026, 8, 6).toIso8601String(),
            'isRead': true,
          },
        ],
      );

      final history = await repository.getHistory(
        recipientId: 'owner-1',
        recipientType: NotificationRecipientType.landOwner,
      );

      expect(history.length, 2);
      expect(history.first.title, 'Update');
    });

    test('getUnreadCount counts unread notifications', () async {
      when(
        () => notificationMongoRepository.findAll(
          filters: any(named: 'filters'),
        ),
      ).thenAnswer(
        (_) async => [
          sampleDocument(isRead: false, id: 'notif-1'),
          sampleDocument(isRead: true, id: 'notif-2'),
        ],
      );

      when(
        () => collectionService.findMany(
          collectionName: any(named: 'collectionName'),
          selector: any(named: 'selector'),
        ),
      ).thenAnswer((_) async => []);

      final count = await repository.getUnreadCount(
        recipientId: 'owner-1',
        recipientType: NotificationRecipientType.landOwner,
      );

      expect(count, 1);
    });

    test('save persists notification via mongo repository', () async {
      final input = AppNotification(
        id: '',
        recipientId: 'owner-1',
        recipientType: NotificationRecipientType.landOwner,
        title: 'Saved',
        message: 'Hello',
        createdAt: DateTime.utc(2026, 8, 7),
      );

      when(() => notificationMongoRepository.create(any())).thenAnswer(
        (_) async => NotificationDocument(
          id: 'saved-1',
          createdAt: DateTime.utc(2026, 8, 7),
          updatedAt: DateTime.utc(2026, 8, 7),
          recipientId: 'owner-1',
          recipientType: NotificationRecipientType.landOwner.value,
          title: 'Saved',
          message: 'Hello',
          isRead: false,
        ),
      );

      final saved = await repository.save(input);

      expect(saved.title, 'Saved');
      verify(() => notificationMongoRepository.create(any())).called(1);
    });
  });
}
