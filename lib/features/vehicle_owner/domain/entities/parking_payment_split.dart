/// Splits a parking bill: 10% platform (media) account, 90% land owner.
class ParkingPaymentSplit {
  ParkingPaymentSplit._();

  static const int platformCommissionPercent = 10;
  static const String platformAccountName = 'Media account (Open Space Parking)';
  static const String landOwnerShareLabel = 'Land owner';

  static int _paise(double total) => (total * 100).round();

  static double platformAmount(double total) {
    if (total <= 0) return 0;
    return (_paise(total) * platformCommissionPercent / 100).round() / 100;
  }

  static double landOwnerAmount(double total) {
    if (total <= 0) return 0;
    return (_paise(total) / 100) - platformAmount(total);
  }
}
