import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/domain/repositories/cloudinary_repository.dart';
import 'package:open_space_parking/core/cloudinary/utils/cloudinary_signature.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';

class CloudinaryApiService {
  CloudinaryApiService();

  String get _cloudName => EnvironmentConfig.cloudinaryCloudName;
  String get _uploadPreset => EnvironmentConfig.cloudinaryUploadPreset;
  String get _apiKey => EnvironmentConfig.cloudinaryApiKey;
  String get _apiSecret => EnvironmentConfig.cloudinaryApiSecret;

  void _ensureConfigured() {
    if (!EnvironmentConfig.isCloudinaryConfigured) {
      throw const AppException(
        'Cloudinary is not configured. Set CLOUDINARY_CLOUD_NAME and '
        'CLOUDINARY_UPLOAD_PRESET.',
      );
    }
  }

  Future<CloudinaryAsset> upload({
    required List<int> fileBytes,
    required CloudinaryFileCategory category,
    required String fileName,
    UploadProgressCallback? onProgress,
  }) async {
    _ensureConfigured();

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    onProgress?.call(0);

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw AppException(
        _parseErrorMessage(body) ?? 'Cloudinary upload failed.',
        code: '${streamedResponse.statusCode}',
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    onProgress?.call(1);

    return CloudinaryAsset.fromUploadResponse(
      json,
      category: category,
      fileName: fileName,
    );
  }

  Future<void> destroy({
    required String publicId,
    required String resourceType,
  }) async {
    if (!EnvironmentConfig.canDeleteFromCloudinary) {
      throw const AppException(
        'Cloudinary delete requires CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final params = {
      'public_id': publicId,
      'timestamp': '$timestamp',
    };

    final signature = CloudinarySignature.generate(
      params: params,
      apiSecret: _apiSecret,
    );

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/destroy',
    );

    final response = await http.post(
      uri,
      body: {
        ...params,
        'api_key': _apiKey,
        'signature': signature,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final json = _tryParseJson(response.body);
      final result = json?['result'] as String?;
      if (result == 'not found') return;
      throw AppException(
        _parseErrorMessage(response.body) ?? 'Cloudinary delete failed.',
        code: '${response.statusCode}',
      );
    }
  }

  String? _parseErrorMessage(String body) {
    final json = _tryParseJson(body);
    if (json == null) return null;
    return json['error']?['message'] as String? ??
        json['message'] as String?;
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
