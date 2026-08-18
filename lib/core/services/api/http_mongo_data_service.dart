import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/mongodb/models/paginated_result.dart';
import 'package:open_space_parking/core/mongodb/models/search_query.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/api/mongo_http_codec.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';

/// HTTP-backed MongoDB data service for Flutter web.
class HttpMongoDataService {
  HttpMongoDataService(this._databaseService, this._apiClient);

  final MongoDatabaseService _databaseService;
  final ApiClient _apiClient;

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }

  Future<Map<String, dynamic>?> findById({
    required String collectionName,
    required String id,
    bool includeDeleted = false,
  }) async {
    await _ensureConnected();
    final selector = where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id));
    return findOne(
      collectionName: collectionName,
      selector: selector,
      includeDeleted: includeDeleted,
    );
  }

  Future<Map<String, dynamic>?> findOne({
    required String collectionName,
    required SelectorBuilder selector,
    bool includeDeleted = false,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/find-one', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
      'includeDeleted': includeDeleted,
    });
    final document = response['document'];
    if (document == null) return null;
    return Map<String, dynamic>.from(
      MongoHttpCodec.decode(document) as Map,
    );
  }

  Future<List<Map<String, dynamic>>> findMany({
    required String collectionName,
    required SelectorBuilder selector,
    bool includeDeleted = false,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/find-many', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
      'includeDeleted': includeDeleted,
    });
    final documents = response['documents'] as List<dynamic>? ?? const [];
    return documents
        .map(
          (doc) => Map<String, dynamic>.from(
            MongoHttpCodec.decode(doc) as Map,
          ),
        )
        .toList();
  }

  Future<PaginatedResult<Map<String, dynamic>>> findPaginated({
    required String collectionName,
    required SearchQuery query,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/find-paginated', {
      'collection': collectionName,
      'query': {
        'filters': query.filters,
        'textQuery': query.textQuery,
        'searchFields': query.searchFields,
        'page': query.page,
        'pageSize': query.pageSize,
        'sortField': query.sortField,
        'sortDescending': query.sortDescending,
        'includeDeleted': query.includeDeleted,
      },
    });
    final items = (response['items'] as List<dynamic>? ?? const [])
        .map(
          (doc) => Map<String, dynamic>.from(
            MongoHttpCodec.decode(doc) as Map,
          ),
        )
        .toList();

    return PaginatedResult(
      items: items,
      page: (response['page'] as num?)?.toInt() ?? query.page,
      pageSize: (response['pageSize'] as num?)?.toInt() ?? query.pageSize,
      totalItems: (response['totalItems'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<List<Map<String, dynamic>>> search({
    required String collectionName,
    required SearchQuery query,
  }) async {
    final result = await findPaginated(
      collectionName: collectionName,
      query: query,
    );
    return result.items;
  }

  Future<int> count({
    required String collectionName,
    SelectorBuilder? selector,
    bool includeDeleted = false,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/count', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector ?? where),
      'includeDeleted': includeDeleted,
    });
    return (response['count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> insertOne({
    required String collectionName,
    required Map<String, dynamic> document,
  }) async {
    await _ensureConnected();
    final doc = Map<String, dynamic>.from(document);
    doc.putIfAbsent(MongoFields.id, () => ObjectId());
    doc.putIfAbsent(
      MongoFields.createdAt,
      () => MongoSerializer.isoDate(DateTime.now().toUtc()),
    );
    doc.putIfAbsent(
      MongoFields.updatedAt,
      () => MongoSerializer.isoDate(DateTime.now().toUtc()),
    );
    doc.putIfAbsent(MongoFields.isDeleted, () => false);

    final response = await _apiClient.post('/api/mongo/insert-one', {
      'collection': collectionName,
      'document': doc,
    });
    return Map<String, dynamic>.from(
      MongoHttpCodec.decode(response['document']) as Map,
    );
  }

  Future<bool> updateById({
    required String collectionName,
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/update-by-id', {
      'collection': collectionName,
      'id': id,
      'updates': updates,
    });
    final matched = (response['matched'] as num?)?.toInt() ?? 0;
    final modified = (response['modified'] as num?)?.toInt() ?? 0;
    return modified > 0 || matched > 0;
  }

  Future<bool> softDelete({
    required String collectionName,
    required String id,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/soft-delete', {
      'collection': collectionName,
      'id': id,
    });
    final matched = (response['matched'] as num?)?.toInt() ?? 0;
    final modified = (response['modified'] as num?)?.toInt() ?? 0;
    return modified > 0 || matched > 0;
  }

  Future<bool> restore({
    required String collectionName,
    required String id,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/restore', {
      'collection': collectionName,
      'id': id,
    });
    final matched = (response['matched'] as num?)?.toInt() ?? 0;
    final modified = (response['modified'] as num?)?.toInt() ?? 0;
    return modified > 0 || matched > 0;
  }

  Future<bool> hardDelete({
    required String collectionName,
    required String id,
  }) async {
    await _ensureConnected();
    final response = await _apiClient.post('/api/mongo/hard-delete', {
      'collection': collectionName,
      'id': id,
    });
    return ((response['removed'] as num?)?.toInt() ?? 0) > 0;
  }

  Future<void> ensureIndexes({
    required String collectionName,
    required List<Map<String, dynamic>> indexes,
  }) async {
    await _ensureConnected();
  }
}
