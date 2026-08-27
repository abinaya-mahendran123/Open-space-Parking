import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/integration/notification_helper.dart';
import 'package:open_space_parking/features/admin/domain/entities/admin_statistics.dart';
import 'package:open_space_parking/features/admin/domain/entities/created_employee_result.dart';
import 'package:open_space_parking/features/admin/domain/entities/employee.dart';
import 'package:open_space_parking/features/admin/domain/repositories/admin_repository.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_request.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_status.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_type.dart';

class MongoAdminRepository implements AdminRepository {
  MongoAdminRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
    required NotificationHelper notificationHelper,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService,
        _notificationHelper = notificationHelper;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;
  final NotificationHelper _notificationHelper;

  @override
  Future<List<LandOwnerRequest>> getAllTickets({
    String? searchQuery,
    RequestStatus? statusFilter,
    LandOwnerRequestType? typeFilter,
    bool? unassignedOnly,
  }) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where,
    );

    var tickets = results.map(_mapRequest).toList();
    tickets.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    if (statusFilter != null) {
      tickets = tickets.where((t) => t.status == statusFilter).toList();
    }
    if (typeFilter != null) {
      tickets = tickets.where((t) => t.requestType == typeFilter).toList();
    }
    if (unassignedOnly == true) {
      tickets = tickets
          .where((t) => t.assignedEmployeeId == null || t.assignedEmployeeId!.isEmpty)
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      tickets = tickets.where((t) {
        return t.ticketId.toLowerCase().contains(q) ||
            t.ownerDetails.fullName.toLowerCase().contains(q) ||
            t.ownerDetails.email.toLowerCase().contains(q) ||
            t.ownerDetails.phone.contains(q) ||
            (t.assignedEmployeeName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return tickets;
  }

  @override
  Future<LandOwnerRequest?> getTicketById(String ticketId) async {
    await _ensureConnected();

    final map = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('ticketId', ticketId),
    );
    if (map == null) return null;
    return _mapRequest(map);
  }

  @override
  Future<void> verifyDocuments({
    required String requestId,
    required bool verified,
    required String adminId,
  }) async {
    await _ensureConnected();
    final now = DateTime.now().toUtc().toIso8601String();

    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('documentsVerified', verified)
          .set('status', RequestStatus.underReview.value)
          .set('updatedAt', now)
          .set('reviewedBy', adminId),
    );
  }

  @override
  Future<void> approveTicket({
    required String requestId,
    required String adminId,
    String? notes,
  }) async {
    await _ensureConnected();
    final request = await _getRequestByObjectId(requestId);
    if (request == null) throw const AppException('Ticket not found.');
    if (!request.documentsVerified) {
      throw const AppException('Verify documents before approving.');
    }

    final now = DateTime.now().toUtc();
    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('status', RequestStatus.approved.value)
          .set('adminNotes', notes ?? '')
          .set('reviewedAt', now.toIso8601String())
          .set('reviewedBy', adminId)
          .set('updatedAt', now.toIso8601String()),
    );

    await _notifyOwner(
      ownerId: request.ownerId,
      ticketId: request.ticketId,
      title: 'Request Approved',
      message: 'Your request ${request.ticketId} has been approved.',
    );
  }

  @override
  Future<void> rejectTicket({
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    await _ensureConnected();
    final request = await _getRequestByObjectId(requestId);
    if (request == null) throw const AppException('Ticket not found.');
    if (reason.trim().isEmpty) {
      throw const AppException('Rejection reason is required.');
    }

    final now = DateTime.now().toUtc();
    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('status', RequestStatus.rejected.value)
          .set('adminNotes', reason.trim())
          .set('reviewedAt', now.toIso8601String())
          .set('reviewedBy', adminId)
          .set('updatedAt', now.toIso8601String()),
    );

    await _notifyOwner(
      ownerId: request.ownerId,
      ticketId: request.ticketId,
      title: 'Request Rejected',
      message: 'Your request ${request.ticketId} was rejected. Reason: $reason',
    );
  }

  @override
  Future<String> assignEmployee({
    required String requestId,
    required String employeeId,
    required String employeeName,
    required String adminId,
  }) async {
    await _ensureConnected();

    final employee = await _collectionService.findOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('_id', ObjectId.parse(employeeId)),
    );
    if (employee == null) throw const AppException('Employee not found.');
    if (employee['isActive'] != true) {
      throw const AppException('Cannot assign inactive employee.');
    }

    final requestMap = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
    );
    if (requestMap == null) throw const AppException('Ticket not found.');
    final ticketId = requestMap['ticketId'] as String;

    final now = DateTime.now().toUtc().toIso8601String();
    await _collectionService.updateOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
      modifier: modify
          .set('assignedEmployeeId', employeeId)
          .set('assignedEmployeeName', employeeName)
          .set('status', RequestStatus.underReview.value)
          .set('updatedAt', now)
          .set('reviewedBy', adminId),
    );

    final currentCount = employee['assignedTicketCount'] as int? ?? 0;
    await _collectionService.updateOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('_id', ObjectId.parse(employeeId)),
      modifier: modify.set('assignedTicketCount', currentCount + 1),
    );

    await _collectionService.insertOne(
      collectionName: AppConstants.employeeNotificationsCollection,
      document: {
        '_id': ObjectId(),
        'employeeId': employeeId,
        'title': 'New Project Assigned',
        'message': 'You have been assigned to ticket $ticketId.',
        'ticketId': ticketId,
        'isRead': false,
        'createdAt': now,
      },
    );

    final pushSent = await _notificationHelper.notifyEmployee(
      employeeId: employeeId,
      title: 'New Project Assigned',
      message: 'You have been assigned to ticket $ticketId.',
      ticketId: ticketId,
      route: '/employee/assigned',
    );

    final ownerId = requestMap['ownerId'] as String? ?? '';
    if (ownerId.isNotEmpty) {
      await _notificationHelper.notifyLandOwner(
        ownerId: ownerId,
        title: 'Employee Assigned',
        message: '$employeeName has been assigned to your request $ticketId.',
        ticketId: ticketId,
      );
    }

    if (pushSent) {
      return 'Assigned to $employeeName. Push notification sent to their phone.';
    }
    return 'Assigned to $employeeName. Employee will see it in Assigned when they open the app '
        '(push not sent — employee must log in once with notifications enabled).';
  }

  @override
  Future<List<LandOwnerRequest>> getEmployeeAssignedTickets(
    String employeeId,
  ) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('assignedEmployeeId', employeeId),
    );

    final tickets = results.map(_mapRequest).toList();
    tickets.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return tickets;
  }

  @override
  Future<List<Employee>> getEmployees({bool activeOnly = false}) async {
    await _ensureConnected();

    final results = await _collectionService.findMany(
      collectionName: AppConstants.employeesCollection,
      selector: where,
    );

    var employees = results.map(_mapEmployee).toList();
    employees.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (activeOnly) {
      employees = employees.where((e) => e.isActive).toList();
    }
    return employees;
  }

  @override
  Future<CreatedEmployeeResult> createEmployee({
    required String fullName,
    required String phone,
  }) async {
    await _ensureConnected();

    final trimmedName = fullName.trim();
    final trimmedPhone = phone.trim();
    final phoneDigits = trimmedPhone.replaceAll(RegExp(r'\D'), '');

    if (trimmedName.isEmpty) {
      throw const AppException('Employee name is required.');
    }
    if (phoneDigits.length < 10) {
      throw const AppException('Enter a valid 10-digit mobile number.');
    }

    final existing = await _collectionService.findOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('phone', trimmedPhone),
    );
    if (existing != null) {
      throw const AppException('An employee with this mobile number already exists.');
    }

    const roleTitle = 'Field Employee';
    // Do not invent placeholder emails (e.g. emp.<phone>@openspace.local).
    const normalizedEmail = '';
    // Password rule: last 6 digits of the employee phone number.
    final temporaryPassword = PhoneUtils.lastSixDigits(trimmedPhone);
    if (temporaryPassword.length != 6) {
      throw const AppException('Enter a valid 10-digit mobile number.');
    }

    final id = ObjectId();
    final now = DateTime.now().toUtc();
    final salt = _generateSalt();
    final hash =
        sha256.convert(utf8.encode('$temporaryPassword::$salt')).toString();

    final document = {
      '_id': id,
      'fullName': trimmedName,
      'email': normalizedEmail,
      'phone': trimmedPhone,
      'roleTitle': roleTitle,
      'isActive': true,
      'assignedTicketCount': 0,
      'passwordHash': hash,
      'passwordSalt': salt,
      'createdAt': now.toIso8601String(),
    };

    await _collectionService.insertOne(
      collectionName: AppConstants.employeesCollection,
      document: document,
    );

    return CreatedEmployeeResult(
      employee: _mapEmployee(document),
      loginEmail: normalizedEmail,
      temporaryPassword: temporaryPassword,
    );
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    await _ensureConnected();

    await _collectionService.updateOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('_id', ObjectId.parse(employee.id)),
      modifier: modify
          .set('fullName', employee.fullName)
          .set('email', employee.email.trim().toLowerCase())
          .set('phone', employee.phone)
          .set('roleTitle', employee.roleTitle)
          .set('isActive', employee.isActive),
    );
  }

  @override
  Future<void> setEmployeeActive({
    required String employeeId,
    required bool isActive,
  }) async {
    await _ensureConnected();

    await _collectionService.updateOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('_id', ObjectId.parse(employeeId)),
      modifier: modify.set('isActive', isActive),
    );
  }

  @override
  Future<AdminStatistics> getStatistics() async {
    final tickets = await getAllTickets();
    final employees = await getEmployees(activeOnly: true);

    return AdminStatistics(
      totalTickets: tickets.length,
      submittedCount: tickets.where((t) => t.status == RequestStatus.submitted).length,
      underReviewCount:
          tickets.where((t) => t.status == RequestStatus.underReview).length,
      approvedCount: tickets.where((t) => t.status == RequestStatus.approved).length,
      rejectedCount: tickets.where((t) => t.status == RequestStatus.rejected).length,
      inProgressCount:
          tickets.where((t) => t.status == RequestStatus.inProgress).length,
      completedCount:
          tickets.where((t) => t.status == RequestStatus.completed).length,
      buildParkingCount: tickets
          .where((t) => t.requestType == LandOwnerRequestType.buildParking)
          .length,
      existingParkingCount: tickets
          .where((t) => t.requestType == LandOwnerRequestType.existingParking)
          .length,
      activeEmployees: employees.length,
      unassignedTickets: tickets
          .where((t) => t.assignedEmployeeId == null || t.assignedEmployeeId!.isEmpty)
          .length,
      documentsPendingVerification:
          tickets.where((t) => !t.documentsVerified).length,
    );
  }

  Future<LandOwnerRequest?> _getRequestByObjectId(String requestId) async {
    final map = await _collectionService.findOne(
      collectionName: AppConstants.landOwnerRequestsCollection,
      selector: where.eq('_id', ObjectId.parse(requestId)),
    );
    if (map == null) return null;
    return _mapRequest(map);
  }

  Future<void> _notifyOwner({
    required String ownerId,
    required String ticketId,
    required String title,
    required String message,
  }) async {
    await _notificationHelper.notifyLandOwner(
      ownerId: ownerId,
      title: title,
      message: message,
      ticketId: ticketId,
    );
  }

  LandOwnerRequest _mapRequest(Map<String, dynamic> map) {
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

  Employee _mapEmployee(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final id = rawId is ObjectId ? rawId.oid : rawId.toString();
    final email = ProfilePrefill.realEmail(map['email'] as String?) ?? '';
    return Employee.fromMap({...map, 'email': email}, id: id);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }
}
