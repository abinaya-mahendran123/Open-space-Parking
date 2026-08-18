import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/features/employee/domain/entities/construction_progress_entry.dart';
import 'package:open_space_parking/features/employee/domain/entities/employee_notification.dart';
import 'package:open_space_parking/features/employee/domain/entities/quotation.dart';
import 'package:open_space_parking/features/employee/domain/repositories/employee_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

class MongoEmployeeRepository implements EmployeeRepository {
  MongoEmployeeRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;

  @override
  Future<List<LandOwnerRequest>> getAssignedProjects(String employeeId) async {
    await _ensureConnected();
    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('assignedEmployeeId', employeeId),
    );

    final projects = results
        .map(_mapRequest)
        .where((r) => r.status != RequestStatus.completed)
        .toList();
    projects.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return projects;
  }

  @override
  Future<List<LandOwnerRequest>> getCompletedProjects(String employeeId) async {
    await _ensureConnected();
    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where
          .eq('assignedEmployeeId', employeeId)
          .eq('status', RequestStatus.completed.value),
    );

    final projects = results.map(_mapRequest).toList();
    projects.sort((a, b) {
      final aDate = a.completedAt ?? a.submittedAt;
      final bDate = b.completedAt ?? b.submittedAt;
      return bDate.compareTo(aDate);
    });
    return projects;
  }

  @override
  Future<LandOwnerRequest?> getTicketById({
    required String ticketId,
    required String employeeId,
  }) async {
    await _ensureConnected();
    final map = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('ticketId', ticketId).eq('assignedEmployeeId', employeeId),
    );
    if (map == null) return null;
    return _mapRequest(map);
  }

  @override
  Future<Quotation> submitQuotation({
    required String employeeId,
    required String requestId,
    required String ticketId,
    required double amount,
    required double materialsCost,
    required double laborCost,
    required int timelineDays,
    required String description,
  }) async {
    await _ensureConnected();
    await _assertAssigned(requestId: requestId, employeeId: employeeId);

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.quotationsCollection,
      selector: where.eq('ticketId', ticketId),
    );
    if (existing != null) {
      throw const AppException('Quotation already submitted for this ticket.');
    }

    final id = ObjectId();
    final now = DateTime.now().toUtc();
    final document = {
      '_id': id,
      'ticketId': ticketId,
      'requestId': requestId,
      'employeeId': employeeId,
      'amount': amount,
      'materialsCost': materialsCost,
      'laborCost': laborCost,
      'timelineDays': timelineDays,
      'description': description.trim(),
      'createdAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.quotationsCollection,
      document: document,
    );

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('status', RequestStatus.inProgress.value)
          .set('updatedAt', now.toIso8601String()),
    );

    return _mapQuotation(document);
  }

  @override
  Future<Quotation?> getQuotation(String ticketId) async {
    await _ensureConnected();
    final map = await _collectionService.findOne(
      collectionName: AppConstants.quotationsCollection,
      selector: where.eq('ticketId', ticketId),
    );
    if (map == null) return null;
    return _mapQuotation(map);
  }

  @override
  Future<void> updateNavigationNotes({
    required String requestId,
    required String employeeId,
    required String notes,
  }) async {
    await _ensureConnected();
    await _assertAssigned(requestId: requestId, employeeId: employeeId);

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('navigationNotes', notes.trim())
          .set('updatedAt', DateTime.now().toUtc().toIso8601String()),
    );
  }

  @override
  Future<ConstructionProgressEntry> updateConstructionProgress({
    required String employeeId,
    required String requestId,
    required String ticketId,
    required int progressPercent,
    required String notes,
  }) async {
    await _ensureConnected();
    await _assertAssigned(requestId: requestId, employeeId: employeeId);

    if (progressPercent < 0 || progressPercent > 100) {
      throw const AppException('Progress must be between 0 and 100.');
    }

    final id = ObjectId();
    final now = DateTime.now().toUtc();
    final document = {
      '_id': id,
      'ticketId': ticketId,
      'requestId': requestId,
      'employeeId': employeeId,
      'progressPercent': progressPercent,
      'notes': notes.trim(),
      'createdAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.constructionProgressCollection,
      document: document,
    );

    final status = progressPercent >= 100
        ? RequestStatus.completed
        : RequestStatus.inProgress;

    var modifier = modify
        .set('constructionProgress', progressPercent)
        .set('status', status.value)
        .set('updatedAt', now.toIso8601String());

    if (progressPercent >= 100) {
      modifier = modifier.set('completedAt', now.toIso8601String());
    }

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modifier,
    );

    return _mapProgress(document);
  }

  @override
  Future<List<ConstructionProgressEntry>> getProgressHistory(String ticketId) async {
    await _ensureConnected();
    final results = await _collectionService.findMany(
      collectionName: AppConstants.constructionProgressCollection,
      selector: where.eq('ticketId', ticketId),
    );
    final entries = results.map(_mapProgress).toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  @override
  Future<void> markProjectCompleted({
    required String requestId,
    required String employeeId,
  }) async {
    await _ensureConnected();
    final request = await _assertAssigned(requestId: requestId, employeeId: employeeId);
    final now = DateTime.now().toUtc();

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('status', RequestStatus.completed.value)
          .set('constructionProgress', 100)
          .set('completedAt', now.toIso8601String())
          .set('updatedAt', now.toIso8601String()),
    );

    await _collectionService.insertOne(
      collectionName: AppConstants.landOwnerNotificationsCollection,
      document: {
        '_id': ObjectId(),
        'ownerId': request.ownerId,
        'title': 'Construction Completed',
        'message': 'Your project ${request.ticketId} has been marked completed.',
        'ticketId': request.ticketId,
        'isRead': false,
        'createdAt': now.toIso8601String(),
      },
    );
  }

  @override
  Future<List<EmployeeNotification>> getNotifications(String employeeId) async {
    await _ensureConnected();
    final results = await _collectionService.findMany(
      collectionName: AppConstants.employeeNotificationsCollection,
      selector: where.eq('employeeId', employeeId),
    );
    final notifications = results.map(_mapNotification).toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _ensureConnected();
    await _collectionService.updateOne(
      collectionName: AppConstants.employeeNotificationsCollection,
      selector: where.eq('_id', ObjectId.parse(notificationId)),
      modifier: modify.set('isRead', true),
    );
  }

  @override
  Future<int> getUnreadCount(String employeeId) async {
    final notifications = await getNotifications(employeeId);
    return notifications.where((n) => !n.isRead).length;
  }

  Future<LandOwnerRequest> _assertAssigned({
    required String requestId,
    required String employeeId,
  }) async {
    final map = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
    );
    if (map == null) throw const AppException('Ticket not found.');
    final request = _mapRequest(map);
    if (request.assignedEmployeeId != employeeId) {
      throw const AppException('This ticket is not assigned to you.');
    }
    return request;
  }

  LandOwnerRequest _mapRequest(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
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

  Quotation _mapQuotation(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
    return Quotation(
      id: id,
      ticketId: map['ticketId'] as String,
      requestId: map['requestId'] as String,
      employeeId: map['employeeId'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      materialsCost: (map['materialsCost'] as num?)?.toDouble() ?? 0,
      laborCost: (map['laborCost'] as num?)?.toDouble() ?? 0,
      timelineDays: map['timelineDays'] as int? ?? 0,
    );
  }

  ConstructionProgressEntry _mapProgress(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
    return ConstructionProgressEntry(
      id: id,
      ticketId: map['ticketId'] as String,
      requestId: map['requestId'] as String,
      employeeId: map['employeeId'] as String,
      progressPercent: map['progressPercent'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  EmployeeNotification _mapNotification(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
    return EmployeeNotification(
      id: id,
      employeeId: map['employeeId'] as String,
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
