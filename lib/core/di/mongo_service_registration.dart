import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';
import 'package:open_space_parking/core/services/api/http_mongo_collection_service.dart';
import 'package:open_space_parking/core/services/api/http_mongo_data_service.dart';
import 'package:open_space_parking/core/services/api/http_mongo_database_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';

/// Production path: all platforms talk to the Node API (Supabase-backed).
///
/// Escape hatch for rare local desktop debugging against a real Mongo daemon:
/// `--dart-define=USE_DIRECT_MONGO=true` (never enable in production builds).
bool get useBackendApiDataLayer {
  const forceDirectMongo = bool.fromEnvironment(
    'USE_DIRECT_MONGO',
    defaultValue: false,
  );
  if (forceDirectMongo) {
    assert(() {
      debugPrint(
        'USE_DIRECT_MONGO=true: connecting to MongoDB directly. '
        'Not supported for production.',
      );
      return true;
    }());
    return false;
  }
  return true;
}

void registerMongoServices(GetIt sl) {
  if (sl.isRegistered<MongoDatabaseService>()) return;

  if (!sl.isRegistered<AuthTokenProvider>()) {
    sl.registerLazySingleton<AuthTokenProvider>(AuthTokenProvider.new);
  }

  if (useBackendApiDataLayer) {
    sl.registerLazySingleton<ApiClient>(
      () => ApiClient(sl<AuthTokenProvider>()),
    );
    sl.registerLazySingleton<MongoDatabaseService>(
      () => HttpMongoDatabaseService(sl<ApiClient>()),
    );
    sl.registerLazySingleton<HttpMongoCollectionService>(
      () => HttpMongoCollectionService(sl<ApiClient>()),
    );
    sl.registerLazySingleton<MongoCollectionService>(
      () => MongoCollectionService(
        sl<MongoDatabaseService>(),
        httpService: sl<HttpMongoCollectionService>(),
      ),
    );
    sl.registerLazySingleton<MongoDataService>(
      () => MongoDataService(
        sl<MongoDatabaseService>(),
        httpService: HttpMongoDataService(
          sl<MongoDatabaseService>(),
          sl<ApiClient>(),
        ),
      ),
    );
    return;
  }

  sl.registerLazySingleton<MongoDatabaseService>(MongoDatabaseServiceImpl.new);
  sl.registerLazySingleton<MongoCollectionService>(
    () => MongoCollectionService(sl<MongoDatabaseService>()),
  );
  sl.registerLazySingleton<MongoDataService>(
    () => MongoDataService(sl<MongoDatabaseService>()),
  );
}
