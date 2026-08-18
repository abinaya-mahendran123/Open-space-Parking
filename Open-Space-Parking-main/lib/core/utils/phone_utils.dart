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
}
