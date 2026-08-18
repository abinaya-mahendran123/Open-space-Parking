import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/api/mongo_http_codec.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();
  final http.Client _httpClient;

  String get _baseUrl => EnvironmentConfig.baseApiUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<void> checkHealth() async {
    final response = await _httpClient
        .get(_uri('/api/health'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw NetworkException(
        'API server unavailable (HTTP ${response.statusCode}). '
        'Start it with: cd backend && npm install && npm start',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _httpClient
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(MongoHttpCodec.encode(body)),
        )
        .timeout(AppConstants.requestTimeout);

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
        MongoHttpCodec.decode(jsonDecode(response.body)) as Map,
      );
    } catch (_) {
      throw NetworkException(
        'Invalid API response (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode >= 400) {
      throw NetworkException(
        payload['error']?.toString() ??
            'API request failed (HTTP ${response.statusCode}).',
      );
    }

    return payload;
  }
}
