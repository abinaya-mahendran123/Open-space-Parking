import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/mongodb/models/paginated_result.dart';
import 'package:open_space_parking/core/mongodb/models/search_query.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';
import 'package:open_space_parking/core/services/api/http_mongo_data_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';

/// Extended MongoDB operations: pagination, search, soft delete, CRUD helpers.
class MongoDataService {
  MongoDataService(
    this._databaseService, {
    HttpMongoDataService? httpService,
  }) : _httpService = httpService;

  final MongoDatabaseService _databaseService;
  final HttpMongoDataService? _httpService;

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }

  DbCollection _col(String collectionName) =>
      _databaseService.collection(collectionName);

  Future<Map<String, dynamic>?> findById({
    required String collectionName,
    required String id,
    bool includeDeleted = false,
  }) async {
    if (_httpService case final http?) {
      return http.findById(
        collectionName: collectionName,
        id: id,
        includeDeleted: includeDeleted,
      );
    }
    await _ensureConnected();
    final selector = where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id));
    if (!includeDeleted) {
      selector.and(where.ne(MongoFields.isDeleted, true));
    }
    return _col(collectionName).findOne(selector);
  }

  Future<Map<String, dynamic>?> findOne({
    required String collectionName,
    required SelectorBuilder selector,
    bool includeDeleted = false,
  }) async {
    if (_httpService case final http?) {
      return http.findOne(
        collectionName: collectionName,
        selector: selector,
        includeDeleted: includeDeleted,
      );
    }
    await _ensureConnected();
    var query = selector;
    if (!includeDeleted) {
      query = query.and(where.ne(MongoFields.isDeleted, true));
    }
    return _col(collectionName).findOne(query);
  }

  Future<List<Map<String, dynamic>>> findMany({
    required String collectionName,
    required SelectorBuilder selector,
    bool includeDeleted = false,
  }) async {
    if (_httpService case final http?) {
      return http.findMany(
        collectionName: collectionName,
        selector: selector,
        includeDeleted: includeDeleted,
      );
    }
    await _ensureConnected();
    var query = selector;
    if (!includeDeleted) {
      query = query.and(where.ne(MongoFields.isDeleted, true));
    }
    return _col(collectionName).find(query).toList();
  }

  Future<PaginatedResult<Map<String, dynamic>>> findPaginated({
    required String collectionName,
    required SearchQuery query,
  }) async {
    if (_httpService case final http?) {
      return http.findPaginated(
        collectionName: collectionName,
        query: query,
      );
    }
    await _ensureConnected();
    final selector = _buildSelector(query);
    final collection = _col(collectionName);

    final totalItems = await collection.count(selector);
    final sortOrder = query.sortDescending ? -1 : 1;

    final items = await collection
        .modernFind(
          selector: selector,
          sort: {query.sortField: sortOrder},
          skip: query.skip,
          limit: query.pageSize,
        )
        .toList();

    return PaginatedResult(
      items: items,
      page: query.page,
      pageSize: query.pageSize,
      totalItems: totalItems,
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
    if (_httpService case final http?) {
      return http.count(
        collectionName: collectionName,
        selector: selector,
        includeDeleted: includeDeleted,
      );
    }
    await _ensureConnected();
    var query = selector ?? where;
    if (!includeDeleted) {
      query = query.and(where.ne(MongoFields.isDeleted, true));
    }
    return _col(collectionName).count(query);
  }

  Future<Map<String, dynamic>> insertOne({
    required String collectionName,
    required Map<String, dynamic> document,
  }) async {
    if (_httpService case final http?) {
      return http.insertOne(
        collectionName: collectionName,
        document: document,
      );
    }
    await _ensureConnected();
    final now = DateTime.now().toUtc();
    final doc = Map<String, dynamic>.from(document);
    doc.putIfAbsent(MongoFields.id, () => ObjectId());
    doc.putIfAbsent(MongoFields.createdAt, () => MongoSerializer.isoDate(now));
    doc.putIfAbsent(MongoFields.updatedAt, () => MongoSerializer.isoDate(now));
    doc.putIfAbsent(MongoFields.isDeleted, () => false);

    await _col(collectionName).insertOne(doc);
    return doc;
  }

  Future<bool> updateById({
    required String collectionName,
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    if (_httpService case final http?) {
      return http.updateById(
        collectionName: collectionName,
        id: id,
        updates: updates,
      );
    }
    await _ensureConnected();
    final modifier = modify
        .set('updatedAt', MongoSerializer.isoDate(DateTime.now().toUtc()));

    updates.forEach((key, value) {
      if (key != MongoFields.id && key != 'id') {
        modifier.set(key, value);
      }
    });

    final result = await _col(collectionName).updateOne(
      where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id)),
      modifier,
    );
    return result.nModified > 0 || result.nMatched > 0;
  }

  Future<bool> softDelete({
    required String collectionName,
    required String id,
  }) async {
    if (_httpService case final http?) {
      return http.softDelete(
        collectionName: collectionName,
        id: id,
      );
    }
    await _ensureConnected();
    final now = MongoSerializer.isoDate(DateTime.now().toUtc());
    final result = await _col(collectionName).updateOne(
      where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id)),
      modify
          .set(MongoFields.isDeleted, true)
          .set(MongoFields.deletedAt, now)
          .set(MongoFields.updatedAt, now),
    );
    return result.nModified > 0 || result.nMatched > 0;
  }

  Future<bool> restore({
    required String collectionName,
    required String id,
  }) async {
    if (_httpService case final http?) {
      return http.restore(
        collectionName: collectionName,
        id: id,
      );
    }
    await _ensureConnected();
    final now = MongoSerializer.isoDate(DateTime.now().toUtc());
    final result = await _col(collectionName).updateOne(
      where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id)),
      modify
          .set(MongoFields.isDeleted, false)
          .unset(MongoFields.deletedAt)
          .set(MongoFields.updatedAt, now),
    );
    return result.nModified > 0 || result.nMatched > 0;
  }

  Future<bool> hardDelete({
    required String collectionName,
    required String id,
  }) async {
    if (_httpService case final http?) {
      return http.hardDelete(
        collectionName: collectionName,
        id: id,
      );
    }
    await _ensureConnected();
    final result = await _col(collectionName).deleteOne(
      where.eq(MongoFields.id, MongoSerializer.objectIdFrom(id)),
    );
    return result.nRemoved > 0;
  }

  Future<void> ensureIndexes({
    required String collectionName,
    required List<Map<String, dynamic>> indexes,
  }) async {
    if (_httpService case final http?) {
      return http.ensureIndexes(
        collectionName: collectionName,
        indexes: indexes,
      );
    }
    await _ensureConnected();
    final collection = _col(collectionName);

    for (final index in indexes) {
      final keys = index['keys'] as Map<String, dynamic>;
      final options = Map<String, dynamic>.from(index)..remove('keys');

      await collection.createIndex(
        keys: keys,
        unique: options['unique'] as bool?,
        sparse: options['sparse'] as bool?,
        background: options['background'] as bool?,
        name: options['name'] as String?,
      );
    }
  }

  SelectorBuilder _buildSelector(SearchQuery query) {
    SelectorBuilder selector = where;

    if (!query.includeDeleted) {
      selector = selector.and(where.ne(MongoFields.isDeleted, true));
    }

    for (final entry in query.filters.entries) {
      selector = selector.and(where.eq(entry.key, entry.value));
    }

    if (query.textQuery != null &&
        query.textQuery!.trim().isNotEmpty &&
        query.searchFields.isNotEmpty) {
      final regex = RegExp(query.textQuery!.trim(), caseSensitive: false);
      final orSelectors = query.searchFields
          .map((field) => where.match(field, regex.pattern))
          .toList();

      if (orSelectors.length == 1) {
        selector = selector.and(orSelectors.first);
      } else if (orSelectors.isNotEmpty) {
        var orCombined = orSelectors.first;
        for (var i = 1; i < orSelectors.length; i++) {
          orCombined = orCombined.or(orSelectors[i]);
        }
        selector = selector.and(orCombined);
      }
    }

    return selector;
  }
}
