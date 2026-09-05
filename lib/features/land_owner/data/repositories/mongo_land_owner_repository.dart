import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/common/exceptions/network_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/integration/notification_helper.dart';
import 'package:open_space_parking/core/utils/mongo_json.dart';
import 'package:open_space_parking/core/utils/parking_slot_calculator.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/core/services/api/api_client.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_notification.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_payout_terms.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/payout_account.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';
import 'package:open_space_parking/features/land_owner/domain/repositories/land_owner_repository.dart';

class MongoLandOwnerRepository implements LandOwnerRepository {
  MongoLandOwnerRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
    required NotificationHelper notificationHelper,
    ApiClient? apiClient,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService,
        _notificationHelper = notificationHelper,
        _apiClient = apiClient ?? ApiClient();

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;
  final NotificationHelper _notificationHelper;
  final ApiClient _apiClient;

  @override
  Future<LandOwnerRequest> submitBuildParkingRequest({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
    required ParkingPreferences parkingPreferences,
  }) {
    return _submitRequest(
      ownerId: ownerId,
      requestType: LandOwnerRequestType.buildParking,
      ownerDetails: ownerDetails,
      documents: documents,
      landDetails: landDetails,
      parkingPreferences: parkingPreferences,
    );
  }

  @override
  Future<LandOwnerRequest> submitExistingParkingRequest({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
    double? hourlyRate,
  }) {
    final slotCount = ParkingSlotCalculator.slotsFromLandArea(landDetails.areaSqFt);
    return _submitRequest(
      ownerId: ownerId,
      requestType: LandOwnerRequestType.existingParking,
      ownerDetails: ownerDetails,
      documents: documents,
      landDetails: landDetails,
      parkingPreferences: ParkingPreferences(
        priority: RequestPriority.notImmediate,
        parkingType: ParkingType.towerParking,
        numberOfCars: slotCount,
        hourlyRate: hourlyRate,
      ),
    );
  }

  @override
  Future<List<LandOwnerRequest>> getRequestHistory(String ownerId) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('ownerId', ownerId),
    );

    results.sort(
      (a, b) => (b['submittedAt'] as String).compareTo(a['submittedAt'] as String),
    );

    return results.map(_mapToEntity).toList();
  }

  @override
  Future<OwnerDetails?> getOwnerProfile(String ownerId) async {
    await _ensureConnected();
    final normalizedId = MongoJson.objectIdHex(ownerId);

    OwnerDetails? saved;
    try {
      final profile = await _collectionService.findOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        selector: where.eq('ownerId', normalizedId),
      );
      final nested = MongoJson.asMap(profile?['ownerDetails']);
      if (nested != null) {
        saved = OwnerDetails.fromJson(nested);
      }
    } catch (_) {
      saved = null;
    }

    OwnerDetails? fromRequest;
    try {
      final requests = await _collectionService.findMany(
        collectionName: AppConstants.landOwnerRequestsCollection,
        selector: where.eq('ownerId', normalizedId),
      );
      if (requests.isNotEmpty) {
        requests.sort((a, b) {
          final aAt = '${a['submittedAt'] ?? a['createdAt'] ?? ''}';
          final bAt = '${b['submittedAt'] ?? b['createdAt'] ?? ''}';
          return bAt.compareTo(aAt);
        });
        final nested = MongoJson.asMap(requests.first['ownerDetails']);
        if (nested != null) {
          fromRequest = OwnerDetails.fromJson(nested);
        }
      }
    } catch (_) {
      fromRequest = null;
    }

    final user = await _findUserAccount(normalizedId);
    return ProfilePrefill.mergeOwnerDetails(
      saved: saved,
      fromRequest: fromRequest,
      accountDisplayName: user?['displayName'] as String?,
      accountEmail: user?['email'] as String?,
    );
  }

  Future<Map<String, dynamic>?> _findUserAccount(String userId) async {
    final hex = MongoJson.objectIdHex(userId);
    try {
      if (hex.length == 24) {
        final byObjectId = await _collectionService.findOne(
          collectionName: AppConstants.usersCollection,
          selector: where.eq('_id', ObjectId.parse(hex)),
        );
        if (byObjectId != null) return byObjectId;
      }
      return await _collectionService.findOne(
        collectionName: AppConstants.usersCollection,
        selector: where.eq('_id', hex),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateOwnerProfile({
    required String ownerId,
    required OwnerDetails ownerDetails,
    PayoutAccount? payoutAccount,
  }) async {
    await _ensureConnected();
    final now = DateTime.now().toUtc();

    final existingProfile = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
    );

    if (existingProfile == null) {
      await _collectionService.insertOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        document: {
          'ownerId': ownerId,
          'ownerDetails': ownerDetails.toJson(),
          if (payoutAccount != null) 'payout': payoutAccount.toJson(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
      return;
    }

    var modifier = modify
        .set('ownerDetails', ownerDetails.toJson())
        .set('updatedAt', now.toIso8601String());
    if (payoutAccount != null) {
      modifier = modifier.set('payout', payoutAccount.toJson());
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
      modifier: modifier,
    );
  }

  @override
  Future<PayoutAccount?> getPayoutAccount(String ownerId) async {
    await _ensureConnected();
    final profile = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
    );
    final nested = MongoJson.asMap(profile?['payout']);
    if (nested == null) return null;
    return PayoutAccount.fromJson(nested);
  }

  @override
  Future<PayoutAccount> onboardRazorpayPayout({
    required String ownerId,
    required OwnerDetails ownerDetails,
    required PayoutAccount payoutAccount,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/land-owners/$ownerId/razorpay/onboard',
        {
          'ownerDetails': ownerDetails.toJson(),
          'payout': payoutAccount.toJson(),
        },
      );
      final nested = MongoJson.asMap(response['payout']);
      if (nested == null) {
        throw const AppException('Payout account was not returned by the server.');
      }
      return PayoutAccount.fromJson(nested);
    } on NetworkException catch (e) {
      throw AppException(e.message);
    }
  }

  @override
  Future<PayoutAccount?> refreshRazorpayPayoutStatus(String ownerId) async {
    try {
      final response = await _apiClient.get(
        '/api/land-owners/$ownerId/razorpay/status',
      );
      final nested = MongoJson.asMap(response['payout']);
      if (nested == null) return null;
      return PayoutAccount.fromJson(nested);
    } on NetworkException catch (e) {
      throw AppException(e.message);
    }
  }

  @override
  Future<bool> hasAcceptedPayoutTerms(String ownerId) async {
    await _ensureConnected();
    final profile = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
    );
    if (profile == null) return false;
    final terms = MongoJson.asMap(profile['payoutTerms']);
    if (terms == null) return false;
    final accepted = terms['accepted'] == true;
    final version = '${terms['version'] ?? ''}';
    return accepted && version == LandOwnerPayoutTerms.version;
  }

  @override
  Future<void> acceptPayoutTerms(String ownerId) async {
    await _ensureConnected();
    final now = DateTime.now().toUtc().toIso8601String();
    final terms = {
      'accepted': true,
      'acceptedAt': now,
      'version': LandOwnerPayoutTerms.version,
    };

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
    );

    if (existing == null) {
      await _collectionService.insertOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        document: {
          'ownerId': ownerId,
          'ownerDetails': {
            'fullName': '',
            'phone': '',
            'email': '',
            'address': '',
          },
          'payoutTerms': terms,
          'createdAt': now,
          'updatedAt': now,
        },
      );
      return;
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
      modifier: modify.set('payoutTerms', terms).set('updatedAt', now),
    );
  }

  Future<LandOwnerRequest> _submitRequest({
    required String ownerId,
    required LandOwnerRequestType requestType,
    required OwnerDetails ownerDetails,
    required LandOwnerDocuments documents,
    required LandDetails landDetails,
    ParkingPreferences? parkingPreferences,
  }) async {
    await _ensureConnected();

    final documentsWithGovId = documents.copyWith(
      governmentIdPath:
          documents.governmentIdPath ?? ownerDetails.governmentIdFrontPath,
    );

    final slotCount = ParkingSlotCalculator.resolveCapacity(
      requestType: requestType.value,
      areaSqFt: landDetails.areaSqFt,
      storedNumberOfCars: parkingPreferences?.numberOfCars,
    );

    final resolvedPreferences = parkingPreferences == null
        ? ParkingPreferences(
            priority: RequestPriority.notImmediate,
            parkingType: ParkingType.towerParking,
            numberOfCars: slotCount,
          )
        : ParkingPreferences(
            priority: parkingPreferences.priority,
            parkingType: parkingPreferences.parkingType,
            numberOfCars: slotCount,
            hourlyRate: parkingPreferences.hourlyRate,
          );

    final requestId = ObjectId();
    final ticketId = _generateTicketId();
    final now = DateTime.now().toUtc();

    final document = {
      '_id': requestId,
      'ticketId': ticketId,
      'ownerId': ownerId,
      'requestType': requestType.value,
      'status': RequestStatus.submitted.value,
      'ownerDetails': ownerDetails.toJson(),
      'documents': documentsWithGovId.toJson(),
      'landDetails': landDetails.toJson(),
      'parkingPreferences': resolvedPreferences.toJson(),
      'capacity': slotCount,
      'numberOfCars': slotCount,
      'submittedAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      document: document,
    );

    final existingProfile = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerProfilesCollection,
      selector: where.eq('ownerId', ownerId),
    );

    if (existingProfile == null) {
      await _collectionService.insertOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        document: {
          'ownerId': ownerId,
          'ownerDetails': ownerDetails.toJson(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );
    } else {
      await _collectionService.updateOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        selector: where.eq('ownerId', ownerId),
        modifier: modify
            .set('ownerDetails', ownerDetails.toJson())
            .set('updatedAt', now.toIso8601String()),
      );
    }

    await _notificationHelper.notifyLandOwner(
      ownerId: ownerId,
      title: 'Request Submitted',
      message: 'Your request $ticketId has been submitted to admin for review.',
      ticketId: ticketId,
    );

    return _mapToEntity(document);
  }

  LandOwnerRequest _mapToEntity(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();

    final parkingPrefs = map['parkingPreferences'] as Map<String, dynamic>?;

    return LandOwnerRequest(
      id: id,
      ticketId: map['ticketId'] as String,
      ownerId: map['ownerId'] as String,
      requestType: LandOwnerRequestTypeX.fromValue(map['requestType'] as String),
      status: RequestStatusX.fromValue(map['status'] as String),
      ownerDetails: OwnerDetails.fromJson(map['ownerDetails'] as Map<String, dynamic>),
      documents: LandOwnerDocuments.fromJson(map['documents'] as Map<String, dynamic>),
      landDetails: LandDetails.fromJson(map['landDetails'] as Map<String, dynamic>),
      parkingPreferences: parkingPrefs != null
          ? ParkingPreferences.fromJson(parkingPrefs)
          : null,
      submittedAt: DateTime.parse(map['submittedAt'] as String),
      assignedEmployeeId: map['assignedEmployeeId'] as String?,
      assignedEmployeeName: map['assignedEmployeeName'] as String?,
      documentsVerified: map['documentsVerified'] as bool? ?? false,
      adminNotes: map['adminNotes'] as String?,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.parse(map['reviewedAt'] as String)
          : null,
      reviewedBy: map['reviewedBy'] as String?,
      constructionProgress: map['constructionProgress'] as int? ?? 0,
      navigationNotes: map['navigationNotes'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }

  String _generateTicketId() {
    final now = DateTime.now().toUtc();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final random = Random().nextInt(9000) + 1000;
    return 'OSP-$datePart-$random';
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}

class MongoLandOwnerNotificationRepository implements LandOwnerNotificationRepository {
  MongoLandOwnerNotificationRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;

  @override
  Future<List<LandOwnerNotification>> getNotifications(String ownerId) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerNotificationsCollection,
      selector: where.eq('ownerId', ownerId),
    );

    results.sort(
      (a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String),
    );

    return results.map(_mapToEntity).toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _ensureConnected();

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerNotificationsCollection,
      selector: where.eq('_id', ObjectId.parse(notificationId)),
      modifier: modify.set('isRead', true),
    );
  }

  @override
  Future<int> getUnreadCount(String ownerId) async {
    final notifications = await getNotifications(ownerId);
    return notifications.where((n) => !n.isRead).length;
  }

  LandOwnerNotification _mapToEntity(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();

    return LandOwnerNotification(
      id: id,
      ownerId: map['ownerId'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
      ticketId: map['ticketId'] as String?,
    );
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}
