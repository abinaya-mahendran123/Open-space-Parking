import 'package:equatable/equatable.dart';

/// Land owner bank / UPI account used for the 90% parking payout.
///
/// [razorpayLinkedAccountId] is created automatically by the backend via
/// Razorpay Route when bank + PAN details are saved — land owners never
/// enter `acc_...` manually.
class PayoutAccount extends Equatable {
  const PayoutAccount({
    this.accountHolderName,
    this.upiId,
    this.bankAccountNumber,
    this.ifscCode,
    this.pan,
    this.city,
    this.state,
    this.postalCode,
    this.razorpayLinkedAccountId,
    this.razorpayProductId,
    this.razorpayActivationStatus,
    this.razorpayStatusMessage,
  });

  final String? accountHolderName;
  final String? upiId;
  final String? bankAccountNumber;
  final String? ifscCode;

  /// PAN required by Razorpay Route to create a linked account.
  final String? pan;
  final String? city;
  final String? state;
  final String? postalCode;

  /// Razorpay Route linked account (`acc_...`) for automatic 90% transfer.
  final String? razorpayLinkedAccountId;
  final String? razorpayProductId;

  /// pending | activated | failed | needs_clarification | not_configured
  final String? razorpayActivationStatus;
  final String? razorpayStatusMessage;

  bool get hasUpi {
    final value = upiId?.trim() ?? '';
    return value.contains('@');
  }

  bool get hasBank {
    final account = bankAccountNumber?.trim() ?? '';
    final ifsc = ifscCode?.trim() ?? '';
    return account.length >= 8 && ifsc.length == 11;
  }

  bool get hasRazorpayLinkedAccount {
    final id = razorpayLinkedAccountId?.trim() ?? '';
    return RegExp(r'^acc_[A-Za-z0-9]+$').hasMatch(id);
  }

  bool get isActivated =>
      (razorpayActivationStatus ?? '').toLowerCase() == 'activated';

  /// Ready for automatic 90% payout when linked account is activated.
  bool get isReady => hasRazorpayLinkedAccount && isActivated;

  String get statusLabel {
    switch ((razorpayActivationStatus ?? '').toLowerCase()) {
      case 'activated':
        return 'Active — 90% auto payout enabled';
      case 'pending':
      case 'needs_clarification':
        return 'Pending verification';
      case 'failed':
        return 'Setup failed — check details and save again';
      case 'not_configured':
        return 'Saved — Razorpay keys / Route not configured yet';
      default:
        return hasRazorpayLinkedAccount
            ? 'Linked account created'
            : 'Not set up yet';
    }
  }

  Map<String, dynamic> toJson() => {
        'accountHolderName': accountHolderName?.trim(),
        'upiId': upiId?.trim(),
        'bankAccountNumber': bankAccountNumber?.trim(),
        'ifscCode': ifscCode?.trim().toUpperCase(),
        'pan': pan?.trim().toUpperCase(),
        'city': city?.trim(),
        'state': state?.trim(),
        'postalCode': postalCode?.trim(),
        'razorpayLinkedAccountId': razorpayLinkedAccountId?.trim(),
        'razorpayProductId': razorpayProductId?.trim(),
        'razorpayActivationStatus': razorpayActivationStatus?.trim(),
        'razorpayStatusMessage': razorpayStatusMessage?.trim(),
      };

  factory PayoutAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PayoutAccount();
    return PayoutAccount(
      accountHolderName: json['accountHolderName'] as String?,
      upiId: json['upiId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      ifscCode: json['ifscCode'] as String?,
      pan: json['pan'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String? ?? json['pinCode'] as String?,
      razorpayLinkedAccountId: json['razorpayLinkedAccountId'] as String?,
      razorpayProductId: json['razorpayProductId'] as String?,
      razorpayActivationStatus: json['razorpayActivationStatus'] as String?,
      razorpayStatusMessage: json['razorpayStatusMessage'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        accountHolderName,
        upiId,
        bankAccountNumber,
        ifscCode,
        pan,
        city,
        state,
        postalCode,
        razorpayLinkedAccountId,
        razorpayProductId,
        razorpayActivationStatus,
        razorpayStatusMessage,
      ];
}
