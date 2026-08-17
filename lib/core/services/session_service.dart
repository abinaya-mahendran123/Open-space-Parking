import 'dart:convert';

import 'package:open_space_parking/core/services/secure_storage_service.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';

class SessionService {
  SessionService(this._storageService);

  static const String _sessionKey = 'auth_session';
  final SecureStorageService _storageService;

  Future<void> saveSession(AuthSession session) async {
    await _storageService.write(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<AuthSession?> readSession() async {
    final raw = await _storageService.read(_sessionKey);
    if (raw == null) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSession.fromJson(decoded);
  }

  Future<void> clearSession() => _storageService.delete(_sessionKey);
}
