import 'package:open_space_parking/core/mongodb/models/parking_documents.dart';
import 'package:open_space_parking/core/mongodb/models/search_query.dart';
import 'package:open_space_parking/core/mongodb/models/transaction_documents.dart';
import 'package:open_space_parking/core/mongodb/models/user_documents.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/repositories/base_mongo_repository.dart';

class UserMongoRepository extends BaseMongoRepository<UserDocument> {
  UserMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.users;

  @override
  FromJson<UserDocument> get fromJson => UserDocument.fromJson;

  @override
  List<String> get searchFields => ['email', 'displayName', 'role'];

  Future<UserDocument?> findByEmail(String email) async {
    final results = await search(
      SearchQuery(
        filters: {'email': email.trim().toLowerCase()},
        pageSize: 1,
      ),
    );
    return results.isEmpty ? null : results.first;
  }
}

class EmployeeMongoRepository extends BaseMongoRepository<EmployeeDocument> {
  EmployeeMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.employees;

  @override
  FromJson<EmployeeDocument> get fromJson => EmployeeDocument.fromJson;

  @override
  List<String> get searchFields => ['email', 'fullName', 'phone'];
}

class VehicleOwnerMongoRepository extends BaseMongoRepository<VehicleOwnerDocument> {
  VehicleOwnerMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.vehicleOwners;

  @override
  FromJson<VehicleOwnerDocument> get fromJson => VehicleOwnerDocument.fromJson;

  @override
  List<String> get searchFields => ['vehicleOwnerId'];

  Future<VehicleOwnerDocument?> findByUserId(String userId) async {
    final results = await search(
      SearchQuery(filters: {'vehicleOwnerId': userId}, pageSize: 1),
    );
    return results.isEmpty ? null : results.first;
  }
}

class LandOwnerMongoRepository extends BaseMongoRepository<LandOwnerDocument> {
  LandOwnerMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.landOwners;

  @override
  FromJson<LandOwnerDocument> get fromJson => LandOwnerDocument.fromJson;

  @override
  List<String> get searchFields => ['ownerId'];

  Future<LandOwnerDocument?> findByOwnerId(String ownerId) async {
    final results = await search(
      SearchQuery(filters: {'ownerId': ownerId}, pageSize: 1),
    );
    return results.isEmpty ? null : results.first;
  }
}

class ParkingSpaceMongoRepository extends BaseMongoRepository<ParkingSpaceDocument> {
  ParkingSpaceMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.parkingSpaces;

  @override
  FromJson<ParkingSpaceDocument> get fromJson => ParkingSpaceDocument.fromJson;

  @override
  List<String> get searchFields => ['address', 'parkingType', 'status'];
}

class ConstructionRequestMongoRepository
    extends BaseMongoRepository<ConstructionRequestDocument> {
  ConstructionRequestMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.constructionRequests;

  @override
  FromJson<ConstructionRequestDocument> get fromJson =>
      ConstructionRequestDocument.fromJson;

  @override
  List<String> get searchFields => ['ticketId', 'status', 'ownerId'];

  Future<ConstructionRequestDocument?> findByTicketId(String ticketId) async {
    final results = await search(
      SearchQuery(filters: {'ticketId': ticketId}, pageSize: 1),
    );
    return results.isEmpty ? null : results.first;
  }
}

class BookingMongoRepository extends BaseMongoRepository<BookingDocument> {
  BookingMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.bookings;

  @override
  FromJson<BookingDocument> get fromJson => BookingDocument.fromJson;

  @override
  List<String> get searchFields => ['bookingRef', 'vehicleOwnerId', 'status'];
}

class NotificationMongoRepository extends BaseMongoRepository<NotificationDocument> {
  NotificationMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.notifications;

  @override
  FromJson<NotificationDocument> get fromJson => NotificationDocument.fromJson;

  @override
  List<String> get searchFields => ['title', 'message', 'recipientId'];
}

class PaymentMongoRepository extends BaseMongoRepository<PaymentDocument> {
  PaymentMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.payments;

  @override
  FromJson<PaymentDocument> get fromJson => PaymentDocument.fromJson;

  @override
  List<String> get searchFields => ['bookingId', 'transactionRef', 'status'];
}

class ReviewMongoRepository extends BaseMongoRepository<ReviewDocument> {
  ReviewMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.reviews;

  @override
  FromJson<ReviewDocument> get fromJson => ReviewDocument.fromJson;

  @override
  List<String> get searchFields => ['comment', 'parkingListingId', 'reviewerId'];
}

class DocumentMongoRepository extends BaseMongoRepository<StoredFileDocument> {
  DocumentMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.documents;

  @override
  FromJson<StoredFileDocument> get fromJson => StoredFileDocument.fromJson;

  @override
  List<String> get searchFields => ['fileName', 'fileType', 'ownerId'];
}

class TicketMongoRepository extends BaseMongoRepository<TicketDocument> {
  TicketMongoRepository(super.dataService);

  @override
  String get canonicalCollection => MongoCollections.tickets;

  @override
  FromJson<TicketDocument> get fromJson => TicketDocument.fromJson;

  @override
  List<String> get searchFields => ['ticketId', 'status', 'type'];

  Future<TicketDocument?> findByTicketId(String ticketId) async {
    final results = await search(
      SearchQuery(filters: {'ticketId': ticketId}, pageSize: 1),
    );
    return results.isEmpty ? null : results.first;
  }
}
