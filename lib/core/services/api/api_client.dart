import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/api/mongo_http_codec.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';

class ApiClient {
  ApiClient([AuthTokenProvider? authTokenProvider, http.Client? httpClient])
      : _authTokenProvider = authTokenProvider ?? AuthTokenProvider(),
        _httpClient = httpClient ?? http.Client();

  final AuthTokenProvider _authTokenProvider;
  final http.Client _httpClient;

  String get _baseUrl => EnvironmentConfig.baseApiUrl;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _authTokenProvider.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

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

  Future<Map<String, dynamic>> get(String path) async {
    Future<http.Response> send() {
      return _httpClient
          .get(_uri(path), headers: _headers())
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

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    bool authenticated = true,
  }) async {
    final effectiveTimeout = timeout ?? AppConstants.requestTimeout;

    Future<http.Response> send() {
      return _httpClient
          .post(
            _uri(path),
            headers: _headers(jsonBody: true),
            body: jsonEncode(MongoHttpCodec.encode(body)),
          )
          .timeout(effectiveTimeout);
    }

    http.Response response;
    try {
      response = await send();
    } catch (error) {
      if (error is TimeoutException) rethrow;
      if (!_isTransportFailure(error)) rethrow;
      await EnvironmentConfig.refreshReachableApiUrl();
      try {
        response = await send();
      } catch (retryError) {
        if (retryError is TimeoutException) rethrow;
        throw NetworkException(EnvironmentConfig.phoneUnreachableMessage);
      }
    }

    return _decodeResponse(response, authenticated: authenticated);
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    bool authenticated = true,
  }) {
    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(
        MongoHttpCodec.decode(jsonDecode(response.body)) as Map,
      );
    } catch (_) {
      throw NetworkException(_invalidResponseMessage(response));
    }

    if (response.statusCode >= 400) {
      final message = payload['error']?.toString() ??
          'API request failed (HTTP ${response.statusCode}).';
      if (authenticated && response.statusCode == 401) {
        throw NetworkException('Session expired. Please sign in again.');
      }
      throw NetworkException(message);
    }

    return payload;
  }

  String _invalidResponseMessage(http.Response response) {
    final preview = response.body.trim();
    if (preview.startsWith('<') ||
        preview.contains('Cannot POST') ||
        preview.contains('Cannot GET')) {
      return 'The hosted API is missing this endpoint. '
          'Redeploy the latest backend to Render, then try again.';
    }
    return 'Invalid API response (HTTP ${response.statusCode}).';
  }

  bool _isTransportFailure(Object error) {
    if (error is http.ClientException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('connection refused') ||
        text.contains('connection failed') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable');
  }
}
