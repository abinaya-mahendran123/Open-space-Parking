import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/services/logger_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/services/secure_storage_service.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/core/services/snackbar_service.dart';

final loggerProvider = Provider<LoggerService>((ref) => sl<LoggerService>());

final snackbarServiceProvider = Provider<SnackbarService>(
  (ref) => sl<SnackbarService>(),
);

final mongoDatabaseServiceProvider = Provider<MongoDatabaseService>(
  (ref) => sl<MongoDatabaseService>(),
);

final mongoCollectionServiceProvider = Provider<MongoCollectionService>(
  (ref) => sl<MongoCollectionService>(),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => sl<SecureStorageService>(),
);

final sessionServiceProvider = Provider<SessionService>(
  (ref) => sl<SessionService>(),
);
