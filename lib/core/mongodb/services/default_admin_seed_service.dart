import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/services/mongodb/mongo_collection_service.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

/// Ensures the default admin account exists for local development.
class DefaultAdminSeedService {
  DefaultAdminSeedService({required MongoCollectionService collectionService})
      : _collectionService = collectionService;

  final MongoCollectionService _collectionService;

  Future<void> ensureDefaultAdmin() async {
    final email = AppConstants.defaultAdminEmail.trim().toLowerCase();
    final existing = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', email),
    );

    if (existing != null) {
      if (existing['role'] == UserRole.admin.value) return;
      return;
    }

    final salt = _generateSalt();
    final hash = sha256
        .convert(utf8.encode('${AppConstants.defaultAdminPassword}::$salt'))
        .toString();
    final now = DateTime.now().toUtc();

    await _collectionService.insertOne(
      collectionName: AppConstants.usersCollection,
      document: {
        '_id': ObjectId(),
        'email': email,
        'displayName': AppConstants.defaultAdminDisplayName,
        'role': UserRole.admin.value,
        'passwordHash': hash,
        'passwordSalt': salt,
        'createdAt': now.toIso8601String(),
      },
    );
  }

  Future<void> ensureDefaultSecurity() async {
    final email = AppConstants.defaultSecurityEmail.trim().toLowerCase();
    final salt = _generateSalt();
    final hash = sha256
        .convert(utf8.encode('${AppConstants.defaultSecurityPassword}::$salt'))
        .toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await _collectionService.findOne(
      collectionName: AppConstants.usersCollection,
      selector: where.eq('email', email),
    );

    if (existing != null) {
      await _collectionService.updateOne(
        collectionName: AppConstants.usersCollection,
        selector: where.eq('email', email),
        modifier: modify
            .set('role', UserRole.security.value)
            .set('passwordHash', hash)
            .set('passwordSalt', salt)
            .set('displayName', AppConstants.defaultSecurityDisplayName)
            .set('isDeleted', false)
            .set('updatedAt', now),
      );
      return;
    }

    await _collectionService.insertOne(
      collectionName: AppConstants.usersCollection,
      document: {
        '_id': ObjectId(),
        'email': email,
        'displayName': AppConstants.defaultSecurityDisplayName,
        'role': UserRole.security.value,
        'passwordHash': hash,
        'passwordSalt': salt,
        'isDeleted': false,
        'createdAt': now,
      },
    );
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
