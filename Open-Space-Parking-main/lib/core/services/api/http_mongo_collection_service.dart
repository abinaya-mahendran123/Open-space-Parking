import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/api/mongo_http_codec.dart';

/// HTTP-backed MongoDB collection operations for Flutter web.
class HttpMongoCollectionService {
  HttpMongoCollectionService(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>?> findOne({
    required String collectionName,
    required SelectorBuilder selector,
  }) async {
    final response = await _apiClient.post('/api/mongo/find-one', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
    });
    final document = response['document'];
    if (document == null) return null;
    return Map<String, dynamic>.from(document as Map);
  }

  Future<List<Map<String, dynamic>>> findMany({
    required String collectionName,
    required SelectorBuilder selector,
  }) async {
    final response = await _apiClient.post('/api/mongo/find-many', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
    });
    final documents = response['documents'] as List<dynamic>? ?? const [];
    return documents
        .map((doc) => Map<String, dynamic>.from(doc as Map))
        .toList();
  }

  Future<WriteResult> insertOne({
    required String collectionName,
    required Map<String, dynamic> document,
  }) async {
    final response = await _apiClient.post('/api/mongo/insert-one', {
      'collection': collectionName,
      'document': document,
    });
    return writeResultInsert(
      inserted: (response['inserted'] as num?)?.toInt() ?? 1,
    );
  }

  Future<WriteResult> updateOne({
    required String collectionName,
    required SelectorBuilder selector,
    required ModifierBuilder modifier,
  }) async {
    final response = await _apiClient.post('/api/mongo/update-one', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
      'modifier': MongoHttpCodec.encodeModifier(modifier),
    });
    return writeResultUpdate(
      matched: (response['matched'] as num?)?.toInt() ?? 0,
      modified: (response['modified'] as num?)?.toInt() ?? 0,
    );
  }

  Future<WriteResult> deleteOne({
    required String collectionName,
    required SelectorBuilder selector,
  }) async {
    final response = await _apiClient.post('/api/mongo/delete-one', {
      'collection': collectionName,
      'selector': MongoHttpCodec.encodeSelector(selector),
    });
    return writeResultDelete(
      removed: (response['removed'] as num?)?.toInt() ?? 0,
    );
  }
}
