import 'package:open_space_parking/core/services/logger_service.dart';

class AppLogger {
  AppLogger._();

  static late LoggerService _logger;

  static void attach(LoggerService logger) {
    _logger = logger;
  }

  static void d(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.debug(message, error, stackTrace);
  }

  static void i(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.info(message, error, stackTrace);
  }

  static void w(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.warning(message, error, stackTrace);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.error(message, error, stackTrace);
  }
}
