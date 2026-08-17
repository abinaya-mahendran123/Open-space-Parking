/// Helpers for Mongo/HTTP JSON, where types are often looser than Dart models.
class MongoJson {
  MongoJson._();

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, nested) => MapEntry(key.toString(), nested));
    }
    return null;
  }

  static double? asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool asBool(dynamic value) {
    if (value == true || value == 1 || value == 'true' || value == '1') {
      return true;
    }
    return false;
  }

  static String objectIdHex(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) {
      final match = RegExp(r'[a-fA-F0-9]{24}').firstMatch(raw);
      return match?.group(0) ?? raw;
    }
    try {
      final hex = (raw as dynamic).oid;
      if (hex is String && hex.isNotEmpty) return hex;
    } catch (_) {}
    if (raw is Map) {
      final oid = raw['\$oid'] ?? raw['oid'] ?? raw['\$id'];
      if (oid != null) return objectIdHex(oid);
    }
    final match = RegExp(r'[a-fA-F0-9]{24}').firstMatch(raw.toString());
    return match?.group(0) ?? raw.toString();
  }
}
