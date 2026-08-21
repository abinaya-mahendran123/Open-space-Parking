import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';

abstract interface class MongoDatabaseService {
  Future<void> connect();
  Future<void> disconnect();
  DbCollection collection(String name);
  bool get isConnected;
}

class MongoDatabaseServiceImpl implements MongoDatabaseService {
  Db? _db;

  @override
  bool get isConnected => _db?.isConnected ?? false;

  @override
  Future<void> connect() async {
    if (isConnected) return;

    try {
      _db = await Db.create(
        EnvironmentConfig.hasMongoConnectionString
            ? EnvironmentConfig.mongoConnectionString
            : 'mongodb://127.0.0.1:27017/open_space_parking',
      );
      await _db!.open().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw const NetworkException('MongoDB connection timed out.');
        },
      );
    } catch (e) {
      _db = null;
      throw NetworkException('Unable to connect to MongoDB: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    if (!isConnected) return;
    await _db!.close();
    _db = null;
  }

  @override
  DbCollection collection(String name) {
    final database = _db;
    if (database == null || !database.isConnected) {
      throw const NetworkException('MongoDB is not connected.');
    }
    return database.collection(name);
  }
}
