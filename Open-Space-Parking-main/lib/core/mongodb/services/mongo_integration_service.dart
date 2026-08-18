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

  /// Connect to MongoDB and ensure all collection indexes.
  Future<void> initialize({bool ensureIndexes = true}) async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }

    if (ensureIndexes) {
      await _indexService.ensureAllIndexes();
    }

    if (!kIsWeb) {
      await DefaultAdminSeedService(collectionService: _collectionService)
          .ensureDefaultAdmin();
    }

    _initialized = true;
  }

  Future<void> disconnect() => _databaseService.disconnect();
}
