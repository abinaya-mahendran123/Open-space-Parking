import 'package:flutter/foundation.dart';

import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/mongodb/services/default_admin_seed_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_index_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';

/// Orchestrates MongoDB connection, index bootstrapping, and health checks.
class MongoIntegrationService {
  MongoIntegrationService({
    required MongoDatabaseService databaseService,
    required MongoDataService dataService,
    required MongoIndexService indexService,
    required MongoCollectionService collectionService,
  })  : _databaseService = databaseService,
        _dataService = dataService,
        _indexService = indexService,
        _collectionService = collectionService;

  final MongoDatabaseService _databaseService;
  final MongoDataService _dataService;
  final MongoIndexService _indexService;
  final MongoCollectionService _collectionService;

  bool _initialized = false;

  bool get isConnected => _databaseService.isConnected;
  bool get isInitialized => _initialized;

  MongoDataService get dataService => _dataService;

  /// Direct Mongo (desktop). Phones/web use the HTTP API instead.
  bool get _isDirectMongoClient {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => false,
      _ => true,
    };
  }

  /// Connect to MongoDB and ensure all collection indexes.
  Future<void> initialize({bool ensureIndexes = true}) async {
    if (_initialized && _databaseService.isConnected) return;

    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }

    // Indexes + local seed only for direct Mongo. On Android/iOS the hosted
    // API already owns seeding; doing it here can fail and mark the app offline.
    if (_isDirectMongoClient) {
      if (ensureIndexes) {
        await _indexService.ensureAllIndexes();
      }
      await DefaultAdminSeedService(collectionService: _collectionService)
          .ensureDefaultAdmin();
      await DefaultAdminSeedService(collectionService: _collectionService)
          .ensureDefaultSecurity();
    }

    _initialized = true;
  }

  Future<void> disconnect() => _databaseService.disconnect();
}
