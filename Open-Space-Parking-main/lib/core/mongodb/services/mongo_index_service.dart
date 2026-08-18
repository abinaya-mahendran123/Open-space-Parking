import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/services/mongo_data_service.dart';

/// Creates recommended indexes for all collections on app startup.
class MongoIndexService {
  MongoIndexService(this._dataService);

  final MongoDataService _dataService;

  Future<void> ensureAllIndexes() async {
    await Future.wait([
      _ensureUsersIndexes(),
      _ensureEmployeesIndexes(),
      _ensureVehicleOwnersIndexes(),
      _ensureLandOwnersIndexes(),
      _ensureParkingSpacesIndexes(),
      _ensureConstructionRequestsIndexes(),
      _ensureBookingsIndexes(),
      _ensureNotificationsIndexes(),
      _ensurePaymentsIndexes(),
      _ensureReviewsIndexes(),
      _ensureDocumentsIndexes(),
      _ensureTicketsIndexes(),
    ]);
  }

  Future<void> _ensureUsersIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.users),
        indexes: [
          {'keys': {'email': 1}, 'unique': true, 'name': 'idx_users_email'},
          {'keys': {'role': 1}, 'name': 'idx_users_role'},
          {'keys': {MongoFields.isDeleted: 1}, 'name': 'idx_users_deleted'},
        ],
      );

  Future<void> _ensureEmployeesIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.employees),
        indexes: [
          {'keys': {'email': 1}, 'unique': true, 'name': 'idx_employees_email'},
          {'keys': {'isActive': 1}, 'name': 'idx_employees_active'},
        ],
      );

  Future<void> _ensureVehicleOwnersIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.vehicleOwners),
        indexes: [
          {'keys': {'vehicleOwnerId': 1}, 'name': 'idx_vehicle_owners_user'},
        ],
      );

  Future<void> _ensureLandOwnersIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.landOwners),
        indexes: [
          {'keys': {'ownerId': 1}, 'name': 'idx_land_owners_owner'},
        ],
      );

  Future<void> _ensureParkingSpacesIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.parkingSpaces),
        indexes: [
          {'keys': {'landOwnerId': 1}, 'name': 'idx_parking_land_owner'},
          {'keys': {'status': 1}, 'name': 'idx_parking_status'},
          {'keys': {'latitude': 1, 'longitude': 1}, 'name': 'idx_parking_geo'},
        ],
      );

  Future<void> _ensureConstructionRequestsIndexes() => _dataService.ensureIndexes(
        collectionName:
            MongoCollections.physical(MongoCollections.constructionRequests),
        indexes: [
          {'keys': {'ticketId': 1}, 'unique': true, 'name': 'idx_requests_ticket'},
          {'keys': {'ownerId': 1}, 'name': 'idx_requests_owner'},
          {'keys': {'status': 1}, 'name': 'idx_requests_status'},
          {'keys': {'submittedAt': -1}, 'name': 'idx_requests_submitted'},
        ],
      );

  Future<void> _ensureBookingsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.bookings),
        indexes: [
          {'keys': {'bookingRef': 1}, 'unique': true, 'name': 'idx_bookings_ref'},
          {'keys': {'vehicleOwnerId': 1}, 'name': 'idx_bookings_owner'},
          {'keys': {'parkingListingId': 1}, 'name': 'idx_bookings_listing'},
          {'keys': {'status': 1}, 'name': 'idx_bookings_status'},
        ],
      );

  Future<void> _ensureNotificationsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.notifications),
        indexes: [
          {'keys': {'recipientId': 1, 'createdAt': -1}, 'name': 'idx_notif_recipient'},
          {'keys': {'isRead': 1}, 'name': 'idx_notif_read'},
        ],
      );

  Future<void> _ensurePaymentsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.payments),
        indexes: [
          {'keys': {'bookingId': 1}, 'name': 'idx_payments_booking'},
          {'keys': {'transactionRef': 1}, 'name': 'idx_payments_txn'},
          {'keys': {'status': 1}, 'name': 'idx_payments_status'},
        ],
      );

  Future<void> _ensureReviewsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.reviews),
        indexes: [
          {
            'keys': {'parkingListingId': 1, 'reviewerId': 1},
            'name': 'idx_reviews_listing_reviewer',
          },
          {'keys': {'rating': 1}, 'name': 'idx_reviews_rating'},
        ],
      );

  Future<void> _ensureDocumentsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.documents),
        indexes: [
          {'keys': {'ownerId': 1}, 'name': 'idx_documents_owner'},
          {'keys': {'referenceId': 1}, 'name': 'idx_documents_ref'},
        ],
      );

  Future<void> _ensureTicketsIndexes() => _dataService.ensureIndexes(
        collectionName: MongoCollections.physical(MongoCollections.tickets),
        indexes: [
          {'keys': {'ticketId': 1}, 'unique': true, 'name': 'idx_tickets_ticket'},
          {'keys': {'status': 1}, 'name': 'idx_tickets_status'},
          {'keys': {'assignedEmployeeId': 1}, 'name': 'idx_tickets_assigned'},
        ],
      );
}
