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

  /// Default admin portal credentials (dev/local).
  static const String defaultAdminEmail = 'harisiv09@gmail.com';
  static const String defaultAdminPassword = 'Hari@2006';
  static const String defaultAdminDisplayName = 'Admin';
}
