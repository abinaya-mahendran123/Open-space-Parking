import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:open_space_parking/core/mongodb/models/transaction_documents.dart';
import 'package:open_space_parking/core/mongodb/repositories/mongo_repositories.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/services/secure_storage_service.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/meta_whatsapp_client.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/twilio_whatsapp_client.dart';
import 'package:open_space_parking/features/authentication/domain/repositories/auth_repository.dart';
import 'package:open_space_parking/features/notification/domain/repositories/notification_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationRepository extends Mock implements NotificationRepository {}

class MockMongoDatabaseService extends Mock implements MongoDatabaseService {}

class MockMongoCollectionService extends Mock implements MongoCollectionService {}

class MockNotificationMongoRepository extends Mock
    implements NotificationMongoRepository {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockMetaWhatsAppClient extends Mock implements MetaWhatsAppClient {}

class MockTwilioWhatsAppClient extends Mock implements TwilioWhatsAppClient {}

/// Registers fallback values required by mocktail `any()`.
void registerFallbackValues() {
  registerFallbackValue(Uri.base);
  registerFallbackValue(where);
  registerFallbackValue(
    NotificationDocument(
      id: 'fallback',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      recipientId: 'user-1',
      recipientType: 'land_owner',
      title: 'Fallback',
      message: 'Fallback message',
      isRead: false,
    ),
  );
}

class FakeWriteResult extends Fake implements WriteResult {}
