import 'package:open_space_parking/core/di/mongo_service_registration.dart';
import 'package:open_space_parking/core/services/api/http_mongo_database_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/mongodb/services/default_admin_seed_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_index_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';

/// Orchestrates data-layer connection. Production uses HTTP → Node → Supabase.
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

  bool get _isHttpApi =>
      useBackendApiDataLayer || _databaseService is HttpMongoDatabaseService;

  /// Connect to the backend API (or direct Mongo when USE_DIRECT_MONGO=true).
  Future<void> initialize({bool ensureIndexes = true}) async {
    if (_initialized && _databaseService.isConnected) return;

    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }

    // Never seed from the phone/web HTTP client — Render/Node owns that.
    // Direct Mongo is desktop-only (`USE_DIRECT_MONGO=true`).
    final httpApi = _isHttpApi || _databaseService is HttpMongoDatabaseService;
    if (!httpApi) {
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
