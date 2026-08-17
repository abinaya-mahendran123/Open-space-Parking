import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/mongodb/models/mongo_document.dart';
import 'package:open_space_parking/core/mongodb/models/paginated_result.dart';
import 'package:open_space_parking/core/mongodb/models/search_query.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';

typedef FromJson<T extends MongoDocument> = T Function(Map<String, dynamic> json);

/// Generic CRUD repository with pagination, search, and soft delete.
abstract class BaseMongoRepository<T extends MongoDocument> {
  BaseMongoRepository(this._dataService);

  final MongoDataService _dataService;

  String get canonicalCollection;
  FromJson<T> get fromJson;
  List<String> get searchFields;

  String get collectionName => MongoCollections.physical(canonicalCollection);

  Future<T> create(T entity) async {
    final doc = await _dataService.insertOne(
      collectionName: collectionName,
      document: MongoSerializer.withObjectId(entity.toJson()),
    );
    return fromJson(doc);
  }

  Future<T?> findById(String id, {bool includeDeleted = false}) async {
    final doc = await _dataService.findById(
      collectionName: collectionName,
      id: id,
      includeDeleted: includeDeleted,
    );
    return doc != null ? fromJson(doc) : null;
  }

  Future<PaginatedResult<T>> findPaginated(SearchQuery query) async {
    final result = await _dataService.findPaginated(
      collectionName: collectionName,
      query: query.copyWith(searchFields: searchFields),
    );
    return PaginatedResult(
      items: result.items.map(fromJson).toList(),
      page: result.page,
      pageSize: result.pageSize,
      totalItems: result.totalItems,
    );
  }

  Future<List<T>> search(SearchQuery query) async {
    final result = await findPaginated(query);
    return result.items;
  }

  Future<List<T>> findAll({
    Map<String, dynamic> filters = const {},
    bool includeDeleted = false,
  }) async {
    final result = await findPaginated(
      SearchQuery(
        filters: filters,
        pageSize: 1000,
        includeDeleted: includeDeleted,
      ),
    );
    return result.items;
  }

  Future<bool> update(String id, T entity) async {
    return _dataService.updateById(
      collectionName: collectionName,
      id: id,
      updates: MongoSerializer.stripIdForInsert(entity.toJson()),
    );
  }

  Future<bool> softDelete(String id) {
    return _dataService.softDelete(collectionName: collectionName, id: id);
  }

  Future<bool> restore(String id) {
    return _dataService.restore(collectionName: collectionName, id: id);
  }

  Future<bool> hardDelete(String id) {
    return _dataService.hardDelete(collectionName: collectionName, id: id);
  }

  Future<int> count({Map<String, dynamic> filters = const {}}) {
    SelectorBuilder selector = where;
    for (final entry in filters.entries) {
      selector = selector.and(where.eq(entry.key, entry.value));
    }
    return _dataService.count(collectionName: collectionName, selector: selector);
  }
}
