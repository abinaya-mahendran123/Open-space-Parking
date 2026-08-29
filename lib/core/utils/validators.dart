import 'package:flutter/services.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/government_id_type.dart';

class Validators {
  Validators._();

  static String? requiredField(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? minLength(String? value, int min) {
    if (value == null || value.length < min) {
      return 'Minimum length is $min characters';
    }
    return null;
  }

  static String? mobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Indian private vehicle registration, e.g. `TN 09 AB 1234` or `22 BH 1234 AA`.
  static String? vehicleNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Vehicle number is required' : null;
    }

    final compact = value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final standard = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$');
    final bharat = RegExp(r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$');
    if (standard.hasMatch(compact) || bharat.hasMatch(compact)) {
      return null;
    }
    return 'Enter a valid vehicle number (e.g. TN 09 AB 1234)';
  }

  static final List<TextInputFormatter> vehicleNumberFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
    LengthLimitingTextInputFormatter(15),
    TextInputFormatter.withFunction((oldValue, newValue) {
      return TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
    }),
  ];

  static String? aadhaar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Aadhaar number is required';
    }
    final digits = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(digits)) {
      return 'Enter a valid 12-digit Aadhaar number';
    }
    return null;
  }

  static String? governmentIdNumber(String? value, GovernmentIdType type) {
    if (value == null || value.trim().isEmpty) {
      return '${type.label} number is required';
    }

    final compact = value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return switch (type) {
      GovernmentIdType.aadhaar =>
        RegExp(r'^\d{12}$').hasMatch(compact) ? null : 'Enter a valid 12-digit Aadhaar number',
      GovernmentIdType.pan =>
        RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(compact)
            ? null
            : 'Enter a valid PAN (e.g. ABCDE1234F)',
      GovernmentIdType.drivingLicense =>
        compact.length >= 5 && compact.length <= 20
            ? null
            : 'Enter a valid driving license number',
      GovernmentIdType.voterId =>
        RegExp(r'^[A-Z]{3}\d{7}$').hasMatch(compact)
            ? null
            : 'Enter a valid Voter ID (e.g. ABC1234567)',
    };
  }

  static String? optionalUpi(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final upi = value.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9.\-_]{2,}@[a-z]{2,}$').hasMatch(upi)) {
      return 'Enter a valid UPI ID (e.g. name@oksbi)';
    }
    return null;
  }

  static String? optionalIfsc(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid IFSC (e.g. SBIN0001234)';
    }
    return null;
  }

  /// Required Razorpay Route linked account for land-owner 90% payout.
  static String? razorpayLinkedAccount(String? value) {
    final id = value?.trim() ?? '';
    if (id.isEmpty) {
      return 'Razorpay linked account is required';
    }
    if (!RegExp(r'^acc_[A-Za-z0-9]+$').hasMatch(id)) {
      return 'Enter a valid ID (e.g. acc_xxxxxxxxxx)';
    }
    return null;
  }
}
