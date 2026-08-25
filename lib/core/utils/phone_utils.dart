import 'package:open_space_parking/core/config/app_constants.dart';

class PhoneUtils {
  PhoneUtils._();

  static String digitsOnly(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  static String normalizeIndianMobile(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      return '+${digitsOnly(trimmed)}';
    }

    final digits = digitsOnly(trimmed);
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (digits.isNotEmpty) {
      return '+$digits';
    }
    return trimmed;
  }

  static bool isValidIndianMobile(String phone) {
    final digits = digitsOnly(phone);
    return digits.length >= 10;
  }

  /// Last 4 digits of a phone number (security gate password).
  static String lastFourDigits(String phone) {
    final digits = digitsOnly(phone);
    if (digits.length < 4) return '';
    return digits.substring(digits.length - 4);
  }

  /// Last 6 digits of a phone number (employee password).
  static String lastSixDigits(String phone) {
    final digits = digitsOnly(phone);
    if (digits.length < 6) return '';
    return digits.substring(digits.length - 6);
  }

  static bool isGateSecurityPhone(String phone) {
    final digits = digitsOnly(phone);
    final lastTen =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return lastTen == AppConstants.defaultSecurityPhone;
  }
}
