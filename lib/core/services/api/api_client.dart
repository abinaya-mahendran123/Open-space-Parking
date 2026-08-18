import 'dart:async';
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
    Future<bool> ping() async {
      try {
        final response = await _httpClient
            .get(_uri('/api/health'))
            .timeout(const Duration(milliseconds: 3000));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    if (await ping()) return;
    await EnvironmentConfig.refreshReachableApiUrl();
    if (await ping()) return;

    throw NetworkException(EnvironmentConfig.phoneUnreachableMessage);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    Future<http.Response> send() {
      return _httpClient
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(MongoHttpCodec.encode(body)),
          )
          .timeout(AppConstants.requestTimeout);
    }

    http.Response response;
    try {
      response = await send();
    } catch (error) {
      if (!_isTransportFailure(error)) rethrow;
      await EnvironmentConfig.refreshReachableApiUrl();
      try {
        response = await send();
      } catch (_) {
        throw NetworkException(EnvironmentConfig.phoneUnreachableMessage);
      }
    }

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

  bool _isTransportFailure(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('connection refused') ||
        text.contains('connection failed') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('timed out');
  }
}
