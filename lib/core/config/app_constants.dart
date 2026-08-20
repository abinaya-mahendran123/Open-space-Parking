class AppConstants {
  AppConstants._();

  static const String appName = 'Open Space Parking';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  static const String usersCollection = 'users';
  static const String landOwnerRequestsCollection = 'land_owner_requests';
  static const String landOwnerProfilesCollection = 'land_owner_profiles';
  static const String landOwnerNotificationsCollection = 'land_owner_notifications';
  static const String employeesCollection = 'employees';
  static const String quotationsCollection = 'quotations';
  static const String constructionProgressCollection = 'construction_progress';
  static const String employeeNotificationsCollection = 'employee_notifications';
  static const String bookingsCollection = 'bookings';
  static const String vehicleOwnerProfilesCollection = 'vehicle_owner_profiles';
  static const String vehicleOwnerNotificationsCollection =
      'vehicle_owner_notifications';
  static const String vehicleOwnerFavoritesCollection = 'vehicle_owner_favorites';
  static const String parkingReviewsCollection = 'parking_reviews';

  // Canonical names — see MongoCollections for full registry + legacy mapping
  static const String parkingSpacesCollection = 'parking_spaces';
  static const String paymentsCollection = 'payments';
  static const String documentsCollection = 'documents';
  static const String notificationsCollection = 'notifications';

  /// Driver pays the full bill; 10% stays on the platform (company) Razorpay
  /// account and 90% is settled to the land owner payout account.
  /// The company account ID is configured via RAZORPAY_COMPANY_ACCOUNT_ID
  /// in backend/.env (not hardcoded here).
  static const int platformCommissionPercent = 10;
  static const String platformPayoutAccountName =
      'Media account (Open Space Parking)';

  /// Default admin portal credentials (local demo only).
  /// Override in production with backend `.env` values — never commit real passwords.
  static const String defaultAdminEmail = 'admin@openspace.local';
  static const String defaultAdminPassword = 'Admin@1234';
  static const String defaultAdminDisplayName = 'Admin';

  /// Default gate security login (dev/local).
  /// Password is always the last 4 digits of [defaultSecurityPhone].
  static const String defaultSecurityEmail = 'security@openspace.local';
  static const String defaultSecurityDisplayName = 'Gate Security';

  /// Security sign-in phone. Password = last 4 digits (`9999`).
  static const String defaultSecurityPhone = '9999999999';
}
