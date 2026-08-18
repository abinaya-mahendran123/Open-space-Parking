import 'dart:convert';

import 'package:crypto/crypto.dart';

class CloudinarySignature {
  CloudinarySignature._();

  static String generate({
    required Map<String, String> params,
    required String apiSecret,
  }) {
    final sortedKeys = params.keys.toList()..sort();
    final payload = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    return sha1.convert(utf8.encode('$payload$apiSecret')).toString();
  }
}
