/// Splits a parking bill: 10% platform (media) account, 90% land owner.
class ParkingPaymentSplit {
  ParkingPaymentSplit._();

  static const int platformCommissionPercent = 10;
  static const String platformAccountName = 'E Star';
  static const String landOwnerShareLabel = 'Land owner';

  static int _paise(double total) => (total * 100).round();

  static double platformAmount(double total) {
    if (total <= 0) return 0;
    final commissionPaise =
        (_paise(total) * platformCommissionPercent / 100).round();
    return commissionPaise / 100;
  }

  static double landOwnerAmount(double total) {
    if (total <= 0) return 0;
    return (_paise(total) / 100) - platformAmount(total);
  }

  /// Whole-rupee split that always sums to [total.round()].
  static int platformWholeRupees(double total) {
    if (total <= 0) return 0;
    return (total.round() * platformCommissionPercent / 100).round();
  }

  static int landOwnerWholeRupees(double total) {
    if (total <= 0) return 0;
    return total.round() - platformWholeRupees(total);
  }

  static String formatWholeRupees(int amount) => '₹$amount';
}
