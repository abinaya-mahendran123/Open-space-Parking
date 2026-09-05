import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/auth_token_provider.dart';

/// Local API file storage for dev/web when Cloudinary is unavailable.
class BackendUploadService {
  BackendUploadService({
    http.Client? httpClient,
    AuthTokenProvider? authTokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _authTokenProvider = authTokenProvider ?? AuthTokenProvider();

  final http.Client _httpClient;
  final AuthTokenProvider _authTokenProvider;

  /// Backend upload is the default for local/dev. Cloudinary is opt-in only.
  static bool get shouldUseBackendUpload {
    const useCloudinary = bool.fromEnvironment(
      'USE_CLOUDINARY',
      defaultValue: false,
    );
    return !(useCloudinary && EnvironmentConfig.isCloudinaryConfigured);
  }

  static bool isBackendUploadUrl(String url) {
    final base = EnvironmentConfig.baseApiUrl.replaceAll(RegExp(r'/+$'), '');
    return url.startsWith('$base/uploads/');
  }

  static String? publicIdFromUrl(String url) {
    if (!isBackendUploadUrl(url)) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    return Uri.decodeComponent(uri.pathSegments.last);
  }

  Map<String, String> _authHeaders() {
    final token = _authTokenProvider.token;
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<CloudinaryAsset> upload({
    required List<int> fileBytes,
    required String fileName,
    required CloudinaryFileCategory category,
  }) async {
    final uri = Uri.parse('${EnvironmentConfig.baseApiUrl}/api/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders())
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

    final streamed = await _httpClient.send(request);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw AppException(_parseError(body) ?? 'File upload failed.');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return CloudinaryAsset(
      url: json['url'] as String? ?? '',
      publicId: json['publicId'] as String? ?? '',
      resourceType: json['resourceType'] as String? ?? 'raw',
      format: json['format'] as String? ?? '',
      fileName: json['fileName'] as String? ?? fileName,
      bytes: (json['bytes'] as num?)?.toInt() ?? fileBytes.length,
      category: category,
    );
  }

  Future<void> deleteByPublicId(String publicId) async {
    if (publicId.isEmpty) return;
    final encoded = Uri.encodeComponent(publicId);
    final uri = Uri.parse('${EnvironmentConfig.baseApiUrl}/api/uploads/$encoded');
    final response = await _httpClient.delete(
      uri,
      headers: _authHeaders(),
    );
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_parseError(response.body) ?? 'File delete failed.');
    }
  }

  String? _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error']?.toString();
    } catch (_) {
      return null;
    }
  }
}
