/// Canonical MongoDB collection names for Open Space Parking.
///
/// Legacy collection names used by existing feature modules are preserved
/// via [legacy] getters so existing data continues to work without migration.
class MongoCollections {
  MongoCollections._();

  // Canonical collection names
  static const String users = 'users';
  static const String employees = 'employees';
  static const String vehicleOwners = 'vehicle_owners';
  static const String landOwners = 'land_owners';
  static const String parkingSpaces = 'parking_spaces';
  static const String constructionRequests = 'construction_requests';
  static const String bookings = 'bookings';
  static const String notifications = 'notifications';
  static const String payments = 'payments';
  static const String reviews = 'reviews';
  static const String documents = 'documents';
  static const String tickets = 'tickets';

  /// All canonical collections for index bootstrapping.
  static const List<String> all = [
    users,
    employees,
    vehicleOwners,
    landOwners,
    parkingSpaces,
    constructionRequests,
    bookings,
    notifications,
    payments,
    reviews,
    documents,
    tickets,
  ];

  // Legacy physical collection names (existing feature modules)
  static const String legacyUsers = 'users';
  static const String legacyEmployees = 'employees';
  static const String legacyVehicleOwnerProfiles = 'vehicle_owner_profiles';
  static const String legacyLandOwnerProfiles = 'land_owner_profiles';
  static const String legacyLandOwnerRequests = 'land_owner_requests';
  static const String legacyBookings = 'bookings';
  static const String legacyVehicleOwnerNotifications = 'vehicle_owner_notifications';
  static const String legacyLandOwnerNotifications = 'land_owner_notifications';
  static const String legacyEmployeeNotifications = 'employee_notifications';
  static const String legacyParkingReviews = 'parking_reviews';
  static const String legacyVehicleOwnerFavorites = 'vehicle_owner_favorites';
  static const String legacyQuotations = 'quotations';
  static const String legacyConstructionProgress = 'construction_progress';

  /// Resolves the physical collection name (prefers legacy where data exists).
  static String physical(String canonical) {
    switch (canonical) {
      case vehicleOwners:
        return legacyVehicleOwnerProfiles;
      case landOwners:
        return legacyLandOwnerProfiles;
      case constructionRequests:
      case tickets:
        return legacyLandOwnerRequests;
      case bookings:
        return legacyBookings;
      case reviews:
        return legacyParkingReviews;
      case users:
        return legacyUsers;
      case employees:
        return legacyEmployees;
      default:
        return canonical;
    }
  }
}

/// Soft-delete and audit field keys used across all documents.
class MongoFields {
  MongoFields._();

  static const String id = '_id';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String deletedAt = 'deletedAt';
  static const String isDeleted = 'isDeleted';
}
