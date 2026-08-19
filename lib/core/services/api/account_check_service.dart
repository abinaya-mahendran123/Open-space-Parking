import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

enum PhoneAccountType { employee, user }

/// Resolves whether a phone number belongs to an employee or a normal user.
class AccountCheckService {
  AccountCheckService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PhoneAccountType> checkAccount(String phone) async {
    final normalized = PhoneUtils.normalizeIndianMobile(phone);
    if (normalized.isEmpty || !PhoneUtils.isValidIndianMobile(phone)) {
      throw const AppException('Please enter a valid mobile number.');
    }

    try {
      final response = await _apiClient.post('/api/auth/check-account', {
        'phone': normalized,
      });
      final accountType = response['accountType'] as String? ?? 'user';
      return accountType == 'employee'
          ? PhoneAccountType.employee
          : PhoneAccountType.user;
    } on NetworkException catch (error) {
      throw AppException(
        error.message.contains('internet') || error.message.contains('reach')
            ? 'Unable to connect. Please check your internet connection and try again.'
            : error.message,
      );
    }
  }
}
