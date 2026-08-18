import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/api/http_mongo_collection_service.dart';
import 'package:open_space_parking/core/services/api/http_mongo_data_service.dart';
import 'package:open_space_parking/core/services/api/http_mongo_database_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';

void registerMongoServices(GetIt sl) {
  if (sl.isRegistered<MongoDatabaseService>()) return;

  if (kIsWeb) {
    sl.registerLazySingleton<ApiClient>(ApiClient.new);
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
