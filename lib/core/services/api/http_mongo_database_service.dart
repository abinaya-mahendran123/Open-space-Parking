import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';

/// Web implementation — connects to the local REST API instead of MongoDB TCP.
class HttpMongoDatabaseService implements MongoDatabaseService {
  HttpMongoDatabaseService(this._apiClient);

  final ApiClient _apiClient;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    if (_connected) return;
    try {
      await _apiClient.checkHealth();
      _connected = true;
    } catch (e) {
      _connected = false;
      if (e is NetworkException) rethrow;
      throw NetworkException(
        'Unable to connect to API server: $e. '
        'Run: cd backend && npm install && npm start',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  DbCollection collection(String name) {
    throw UnsupportedError(
      'Direct collection access is unavailable on web. Use HttpMongoCollectionService.',
    );
  }
}
