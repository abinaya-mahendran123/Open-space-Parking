import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

enum PhoneAccountType { employee, security, user }

/// Resolves whether a phone number belongs to an employee, security, or user.
class AccountCheckService {
  AccountCheckService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PhoneAccountType> checkAccount(String phone) async {
    final normalized = PhoneUtils.normalizeIndianMobile(phone);
    if (normalized.isEmpty || !PhoneUtils.isValidIndianMobile(phone)) {
      throw const AppException('Please enter a valid mobile number.');
    }

    // Local fallback when backend is old / unreachable for this check.
    if (PhoneUtils.isGateSecurityPhone(phone)) {
      return PhoneAccountType.security;
    }

    try {
      final response = await _apiClient.post(
        '/api/auth/check-account',
        {
          'phone': normalized,
        },
        authenticated: false,
      );
      final accountType = response['accountType'] as String? ?? 'user';
      return switch (accountType) {
        'employee' => PhoneAccountType.employee,
        'security' => PhoneAccountType.security,
        _ => PhoneAccountType.user,
      };
    } on NetworkException catch (error) {
      if (PhoneUtils.isGateSecurityPhone(phone)) {
        return PhoneAccountType.security;
      }
      throw AppException(
        error.message.contains('internet') || error.message.contains('reach')
            ? 'Unable to connect. Please check your internet connection and try again.'
            : error.message,
      );
    }
  }
}
