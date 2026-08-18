import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';

class GeocodingService {
  GeocodingService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<GeocodingResult> geocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const AppException('Enter a location name.');
    }

    final uri = Uri.parse('${EnvironmentConfig.baseApiUrl}/api/geocode').replace(
      queryParameters: {'q': trimmed},
    );
    final response = await _httpClient.get(uri);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('Could not look up location. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        body['error']?.toString() ?? 'Could not find that location.',
      );
    }

    return GeocodingResult(
      latitude: (body['latitude'] as num).toDouble(),
      longitude: (body['longitude'] as num).toDouble(),
      displayName: body['displayName'] as String? ?? trimmed,
    );
  }

  Future<GeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('${EnvironmentConfig.baseApiUrl}/api/reverse-geocode')
        .replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
      },
    );
    final response = await _httpClient.get(uri);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('Could not resolve map pin. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        body['error']?.toString() ?? 'Could not resolve map pin.',
      );
    }

    return GeocodingResult(
      latitude: (body['latitude'] as num).toDouble(),
      longitude: (body['longitude'] as num).toDouble(),
      displayName: body['displayName'] as String? ??
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    );
  }
}
