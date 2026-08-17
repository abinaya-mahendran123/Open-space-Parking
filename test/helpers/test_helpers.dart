import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/logger_service.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';

Future<void> initTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await EnvironmentConfig.initialize();
  AppLogger.attach(LoggerService());
}
