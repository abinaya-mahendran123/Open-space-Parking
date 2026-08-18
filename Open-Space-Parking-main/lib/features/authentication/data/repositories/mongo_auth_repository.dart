import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_database_service.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/domain/repositories/auth_repository.dart';

class MongoAuthRepository implements AuthRepository {
  MongoAuthRepository({
    required MongoDatabaseService mongoDatabaseService,
    required MongoCollectionService mongoCollectionService,
  })  : _databaseService = mongoDatabaseService,
        _collectionService = mongoCollectionService;

  final MongoDatabaseService _databaseService;
  final MongoCollectionService _collectionService;

  @override
  Future<AuthSession> loginAppUser({
    required String email,
    required String password,
  }) async {
    final session = await _loginWithRoleCheck(
      email: email,
      password: password,
      allowAdmin: true,
    );

    if (session.role == UserRole.employee) {
      throw const AppException('Employee must use employee portal login.');
    }
    return session;
  }

  @override
  Future<AuthSession> loginAdmin({
    required String email,
    required String password,
  }) async {
    final session = await _loginWithRoleCheck(
      email: email,
      password: password,
      allowAdmin: true,
    );

    if (session.role != UserRole.admin) {
      throw const AppException('Only admins can login to admin portal.');
    }
    return session;
  }

  @override
  Future<AuthSession> loginEmployee({
    required String email,
    required String password,
  }) async {
    await _ensureConnected();

    final normalizedEmail = email.trim().toLowerCase();
    final employee = await _collectionService.findOne(
      collectionName: AppConstants.employeesCollection,
      selector: where.eq('email', normalizedEmail),
    );

    if (employee == null) {
      throw const AppException('Invalid credentials.');
    }
    if (employee['isActive'] != true) {
      throw const AppException('Employee account is inactive.');
    }

    final salt = employee['passwordSalt'] as String?;
    final hash = employee['passwordHash'] as String?;
    if (salt == null || hash == null) {
      throw const AppException(
        'Employee login is not configured. Ask admin to set a password.',
      );
    }

    final computedHash = sha256.convert(utf8.encode('$password::$salt')).toString();
    if (computedHash != hash) {
      throw const AppException('Invalid credentials.');
    }

    final rawId = employee['_id'];
    final userId = rawId is ObjectId ? rawId.toHexString() : rawId.toString();

    return _buildSession(
      userId: userId,
      email: normalizedEmail,
      displayName: employee['fullName'] as String? ?? '',
      role: UserRole.employee,
      issuedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    if (role == UserRole.admin || role == UserRole.employee) {
      throw const AppException('This role cannot be self-registered.');
    }

    await _ensureConnected();

    final normalizedEmail = email.trim().toLowerCase();
    final existing = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', normalizedEmail),
    );

    if (existing != null) {
      throw const AppException('An account with this email already exists.');
    }

    final salt = _generateSalt();
    final hash = sha256.convert(utf8.encode('$password::$salt')).toString();
    final userId = ObjectId();
    final now = DateTime.now().toUtc();

    await _collectionService.insertOne(
      collectionName: AppConstants.usersCollection,
      document: {
        '_id': userId,
        'email': normalizedEmail,
        'displayName': displayName.trim(),
        'role': role.value,
        'passwordHash': hash,
        'passwordSalt': salt,
        'createdAt': now.toIso8601String(),
      },
    );

    await _seedProfileForRole(
      userId: userId.toHexString(),
      displayName: displayName.trim(),
      email: normalizedEmail,
      role: role,
      now: now,
    );

    return _buildSession(
      userId: userId.toHexString(),
      email: normalizedEmail,
      displayName: displayName.trim(),
      role: role,
      issuedAt: now,
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _ensureConnected();
    final normalizedEmail = email.trim().toLowerCase();
    await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', normalizedEmail),
    );
  }

  @override
  Future<AuthSession> loginWithPhone({required String phone}) async {
    await _ensureConnected();
    final normalizedPhone = PhoneUtils.normalizeIndianMobile(phone);
    final user = await _findUserByPhone(normalizedPhone);
    if (user == null) {
      throw const AppException(
        'No account found for this mobile number. Sign up first.',
      );
    }
    return _sessionFromUser(user);
  }

  @override
  Future<AuthSession> registerWithPhone({
    required String phone,
    required String displayName,
    required UserRole role,
  }) async {
    _assertSelfRegisterRole(role);
    await _ensureConnected();

    final normalizedPhone = PhoneUtils.normalizeIndianMobile(phone);
    if (await _findUserByPhone(normalizedPhone) != null) {
      throw const AppException('An account with this mobile number already exists.');
    }

    final syntheticEmail = _phoneEmail(normalizedPhone);
    final existingEmail = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', syntheticEmail),
    );
    if (existingEmail != null) {
      throw const AppException('An account with this mobile number already exists.');
    }

    final userId = ObjectId();
    final now = DateTime.now().toUtc();
    await _collectionService.insertOne(
      collectionName: AppConstants.usersCollection,
      document: {
        '_id': userId,
        'email': syntheticEmail,
        'phone': normalizedPhone,
        'displayName': displayName.trim(),
        'role': role.value,
        'authProvider': 'phone',
        'createdAt': now.toIso8601String(),
      },
    );

    await _seedProfileForRole(
      userId: userId.toHexString(),
      displayName: displayName.trim(),
      email: syntheticEmail,
      phone: normalizedPhone,
      role: role,
      now: now,
    );

    return _buildSession(
      userId: userId.toHexString(),
      email: syntheticEmail,
      displayName: displayName.trim(),
      role: role,
      issuedAt: now,
    );
  }

  @override
  Future<AuthSession> loginWithGoogle({
    required String email,
    required String googleId,
    required String displayName,
  }) async {
    await _ensureConnected();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedGoogleId = googleId.trim();
    if (normalizedEmail.isEmpty || trimmedGoogleId.isEmpty) {
      throw const AppException('Google account identity is incomplete.');
    }

    final user = await _findUserByGoogle(normalizedEmail, trimmedGoogleId);
    if (user == null) {
      throw const AppException(
        'No account found for this Google email. Sign up first.',
      );
    }

    await _linkGoogleIdIfNeeded(user: user, googleId: trimmedGoogleId);
    return _sessionFromUser(user, displayNameOverride: displayName);
  }

  @override
  Future<AuthSession> registerWithGoogle({
    required String email,
    required String googleId,
    required String displayName,
    required UserRole role,
  }) async {
    _assertSelfRegisterRole(role);
    await _ensureConnected();

    final normalizedEmail = email.trim().toLowerCase();
    final trimmedGoogleId = googleId.trim();
    final trimmedName = displayName.trim().isEmpty
        ? normalizedEmail.split('@').first
        : displayName.trim();

    if (normalizedEmail.isEmpty || trimmedGoogleId.isEmpty) {
      throw const AppException('Google account identity is incomplete.');
    }

    final existing = await _findUserByGoogle(normalizedEmail, trimmedGoogleId);
    if (existing != null) {
      final existingRole = UserRoleX.fromValue(existing['role'] as String);
      if (existingRole == UserRole.admin || existingRole == UserRole.employee) {
        // Never rewrite privileged roles via public Google registration.
        if (existingRole == UserRole.employee) {
          throw const AppException('Employee must use employee portal login.');
        }
        await _linkGoogleIdIfNeeded(user: existing, googleId: trimmedGoogleId);
        return _sessionFromUser(existing, displayNameOverride: trimmedName);
      }
      await _linkGoogleIdIfNeeded(user: existing, googleId: trimmedGoogleId);
      return _sessionFromUser(existing, displayNameOverride: trimmedName);
    }

    final userId = ObjectId();
    final now = DateTime.now().toUtc();
    await _collectionService.insertOne(
      collectionName: AppConstants.usersCollection,
      document: {
        '_id': userId,
        'email': normalizedEmail,
        'googleId': trimmedGoogleId,
        'displayName': trimmedName,
        'role': role.value,
        'authProvider': 'google',
        'createdAt': now.toIso8601String(),
      },
    );

    await _seedProfileForRole(
      userId: userId.toHexString(),
      displayName: trimmedName,
      email: normalizedEmail,
      role: role,
      now: now,
    );

    return _buildSession(
      userId: userId.toHexString(),
      email: normalizedEmail,
      displayName: trimmedName,
      role: role,
      issuedAt: now,
    );
  }

  Future<void> _linkGoogleIdIfNeeded({
    required Map<String, dynamic> user,
    required String googleId,
  }) async {
    final existingGoogleId = user['googleId'] as String?;
    if (existingGoogleId != null && existingGoogleId.trim().isNotEmpty) {
      return;
    }

    final rawId = user['_id'];
    if (rawId is! ObjectId) return;

    await _collectionService.updateOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('_id', rawId),
      modifier: modify
          .set('googleId', googleId)
          .set('authProvider', 'google'),
    );
    user['googleId'] = googleId;
    user['authProvider'] = 'google';
  }

  Future<Map<String, dynamic>?> _findUserByPhone(String phone) async {
    return _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('phone', phone),
    );
  }

  Future<Map<String, dynamic>?> _findUserByGoogle(
    String email,
    String googleId,
  ) async {
    final byGoogle = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('googleId', googleId),
    );
    if (byGoogle != null) return byGoogle;

    return _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', email),
    );
  }

  AuthSession _sessionFromUser(
    Map<String, dynamic> user, {
    String? displayNameOverride,
  }) {
    final role = UserRoleX.fromValue(user['role'] as String);
    if (role == UserRole.employee) {
      throw const AppException('Employee must use employee portal login.');
    }

    final rawId = user['_id'];
    final userId = rawId is ObjectId ? rawId.toHexString() : rawId.toString();
    final storedName = user['displayName'] as String? ?? '';
    final displayName = (displayNameOverride != null &&
            displayNameOverride.trim().isNotEmpty)
        ? displayNameOverride.trim()
        : storedName;

    return _buildSession(
      userId: userId,
      email: user['email'] as String? ?? '',
      displayName: displayName,
      role: role,
      issuedAt: DateTime.now().toUtc(),
    );
  }

  String _phoneEmail(String normalizedPhone) {
    final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return 'phone.$digits@openspace.local';
  }

  void _assertSelfRegisterRole(UserRole role) {
    if (role == UserRole.admin || role == UserRole.employee) {
      throw const AppException('This role cannot be self-registered.');
    }
  }

  Future<AuthSession> _loginWithRoleCheck({
    required String email,
    required String password,
    required bool allowAdmin,
  }) async {
    await _ensureConnected();

    final normalizedEmail = email.trim().toLowerCase();
    final user = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', normalizedEmail),
    );
    if (user == null) throw const AppException('Invalid credentials.');

    final salt = user['passwordSalt'] as String?;
    final hash = user['passwordHash'] as String?;
    final roleValue = user['role'] as String?;
    if (salt == null || hash == null || roleValue == null) {
      throw const AppException('Corrupted account data.');
    }

    final computedHash = sha256.convert(utf8.encode('$password::$salt')).toString();
    if (computedHash != hash) throw const AppException('Invalid credentials.');

    final role = UserRoleX.fromValue(roleValue);
    if (!allowAdmin && role == UserRole.admin) {
      throw const AppException('Admin must use admin portal login.');
    }
    if (role == UserRole.employee) {
      throw const AppException('Employee must use employee portal login.');
    }

    return _buildSession(
      userId: (user['_id'] as ObjectId).toHexString(),
      email: normalizedEmail,
      displayName: user['displayName'] as String? ?? '',
      role: role,
      issuedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _ensureConnected() async {
    if (!_databaseService.isConnected) {
      await _databaseService.connect();
    }
  }

  AuthSession _buildSession({
    required String userId,
    required String email,
    required String displayName,
    required UserRole role,
    required DateTime issuedAt,
  }) {
    final expiresAt = issuedAt.add(const Duration(days: 7));
    final payload = {
      'sub': userId,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'iat': issuedAt.millisecondsSinceEpoch,
      'exp': expiresAt.millisecondsSinceEpoch,
    };
    final jwtToken = _buildJwt(payload);

    return AuthSession(
      userId: userId,
      email: email,
      displayName: displayName,
      role: role,
      jwtToken: jwtToken,
      expiresAt: expiresAt,
    );
  }

  Future<void> _seedProfileForRole({
    required String userId,
    required String displayName,
    required String email,
    required UserRole role,
    required DateTime now,
    String phone = '',
  }) async {
    final timestamp = now.toIso8601String();

    if (role == UserRole.landOwner) {
      final existing = await _collectionService.findOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        selector: where.eq('ownerId', userId),
      );
      if (existing != null) return;

      await _collectionService.insertOne(
        collectionName: AppConstants.landOwnerProfilesCollection,
        document: {
          'ownerId': userId,
          'ownerDetails': {
            'fullName': displayName,
            'phone': phone,
            'email': email,
            'address': '',
          },
          'createdAt': timestamp,
          'updatedAt': timestamp,
        },
      );
      return;
    }

    if (role == UserRole.vehicleOwner) {
      final existing = await _collectionService.findOne(
        collectionName: AppConstants.vehicleOwnerProfilesCollection,
        selector: where.eq('vehicleOwnerId', userId),
      );
      if (existing != null) return;

      await _collectionService.insertOne(
        collectionName: AppConstants.vehicleOwnerProfilesCollection,
        document: {
          'vehicleOwnerId': userId,
          'profile': {
            'fullName': displayName,
            'phone': phone,
            'email': email,
          },
          'createdAt': timestamp,
          'updatedAt': timestamp,
        },
      );
    }
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _buildJwt(Map<String, dynamic> payload) {
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final encodedHeader = _encodeJwtPart(header);
    final encodedPayload = _encodeJwtPart(payload);
    final signatureRaw = '$encodedHeader.$encodedPayload';

    const secret = 'open_space_parking_internal_secret';
    final digest = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(signatureRaw))
        .bytes;

    final encodedSignature = base64Url.encode(digest).replaceAll('=', '');
    return '$encodedHeader.$encodedPayload.$encodedSignature';
  }

  String _encodeJwtPart(Map<String, dynamic> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }
}
