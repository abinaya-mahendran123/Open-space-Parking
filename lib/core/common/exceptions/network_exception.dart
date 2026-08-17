import 'package:open_space_parking/core/common/exceptions/app_exception.dart';

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}
