import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/mongodb/mongo_collections.dart';

/// Shared serialization helpers for MongoDB documents.
class MongoSerializer {
  MongoSerializer._();

  static String idFrom(dynamic rawId) {
    if (rawId == null) return '';
    if (rawId is ObjectId) return rawId.oid;
    return rawId.toString();
  }

  static ObjectId objectIdFrom(String id) => ObjectId.parse(id);

  static ObjectId? tryObjectIdFrom(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return ObjectId.parse(id);
    } catch (_) {
      return null;
    }
  }

  static DateTime parseDate(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now().toUtc();
    if (value is DateTime) return value.toUtc();
    return DateTime.parse(value.toString()).toUtc();
  }

  static String isoDate(DateTime dateTime) => dateTime.toUtc().toIso8601String();

  static Map<String, dynamic> auditFields({
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    final now = DateTime.now().toUtc();
    return {
      MongoFields.createdAt: isoDate(createdAt ?? now),
      MongoFields.updatedAt: isoDate(updatedAt ?? now),
      if (deletedAt != null) MongoFields.deletedAt: isoDate(deletedAt),
      MongoFields.isDeleted: deletedAt != null,
    };
  }

  static bool isSoftDeleted(Map<String, dynamic> doc) {
    return doc[MongoFields.isDeleted] == true ||
        doc[MongoFields.deletedAt] != null;
  }

  static Map<String, dynamic> stripIdForInsert(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    copy.remove(MongoFields.id);
    copy.remove('id');
    return copy;
  }

  static Map<String, dynamic> withObjectId(
    Map<String, dynamic> json, {
    String? id,
  }) {
    final copy = Map<String, dynamic>.from(json);
    copy.remove('id');
    if (id != null && id.isNotEmpty) {
      copy[MongoFields.id] = objectIdFrom(id);
    } else if (copy[MongoFields.id] == null) {
      copy[MongoFields.id] = ObjectId();
    }
    return copy;
  }
}
