import 'package:mongo_dart/mongo_dart.dart';
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/abstract_write_result.dart';

/// Encodes/decodes MongoDB values for JSON transport over HTTP.
class MongoHttpCodec {
  MongoHttpCodec._();

  static dynamic encode(dynamic value) {
    if (value is ObjectId) {
      return {'\$oid': value.oid};
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), encode(nested)),
      );
    }
    if (value is List) {
      return value.map(encode).toList();
    }
    return value;
  }

  static dynamic decode(dynamic value) {
    if (value is Map) {
      if (value.length == 1 && value['\$oid'] is String) {
        return ObjectId.parse(value['\$oid'] as String);
      }
      return value.map(
        (key, nested) => MapEntry(key.toString(), decode(nested)),
      );
    }
    if (value is List) {
      return value.map(decode).toList();
    }
    return value;
  }

  static Map<String, dynamic> encodeSelector(SelectorBuilder selector) {
    return Map<String, dynamic>.from(
      encode(selector.map) as Map<String, dynamic>,
    );
  }

  static Map<String, dynamic> encodeModifier(ModifierBuilder modifier) {
    return Map<String, dynamic>.from(
      encode(modifier.map) as Map<String, dynamic>,
    );
  }
}

WriteResult writeResultInsert({int inserted = 1}) {
  return WriteResult.fromMap(
    WriteCommandType.insert,
    {'n': inserted, 'ok': 1},
  );
}

WriteResult writeResultUpdate({int matched = 0, int modified = 0}) {
  return WriteResult.fromMap(
    WriteCommandType.update,
    {'n': matched, 'nModified': modified, 'ok': 1},
  );
}

WriteResult writeResultDelete({int removed = 0}) {
  return WriteResult.fromMap(
    WriteCommandType.delete,
    {'n': removed, 'ok': 1},
  );
}
