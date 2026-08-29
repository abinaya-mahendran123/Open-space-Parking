import 'package:equatable/equatable.dart';

/// Land owner bank / UPI account used for the 90% parking payout.
class PayoutAccount extends Equatable {
  const PayoutAccount({
    this.accountHolderName,
    this.upiId,
    this.bankAccountNumber,
    this.ifscCode,
    this.razorpayLinkedAccountId,
  });

  final String? accountHolderName;
  final String? upiId;
  final String? bankAccountNumber;
  final String? ifscCode;

  /// Razorpay Route linked account (`acc_...`) for automatic 90% transfer.
  final String? razorpayLinkedAccountId;

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

  /// Ready for automatic 90% payout when a Razorpay linked account is set.
  bool get isReady => hasRazorpayLinkedAccount;

  Map<String, dynamic> toJson() => {
        'accountHolderName': accountHolderName?.trim(),
        'upiId': upiId?.trim(),
        'bankAccountNumber': bankAccountNumber?.trim(),
        'ifscCode': ifscCode?.trim().toUpperCase(),
        'razorpayLinkedAccountId': razorpayLinkedAccountId?.trim(),
      };

  factory PayoutAccount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PayoutAccount();
    return PayoutAccount(
      accountHolderName: json['accountHolderName'] as String?,
      upiId: json['upiId'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      ifscCode: json['ifscCode'] as String?,
      razorpayLinkedAccountId: json['razorpayLinkedAccountId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        accountHolderName,
        upiId,
        bankAccountNumber,
        ifscCode,
        razorpayLinkedAccountId,
      ];
}
