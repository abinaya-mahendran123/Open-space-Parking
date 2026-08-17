import 'dart:convert';

import 'package:open_space_parking/core/services/secure_storage_service.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/saved_coordinate.dart';

class SavedCoordinatesStorageService {
  SavedCoordinatesStorageService(this._secureStorage);

  static const _storageKey = 'saved_map_coordinates';

  final SecureStorageService _secureStorage;

  Future<List<SavedCoordinate>> getAll() async {
    final raw = await _secureStorage.read(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => SavedCoordinate.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  Future<SavedCoordinate> save({
    required String label,
    required MapCoordinate coordinate,
  }) async {
    final existing = await getAll();
    final saved = SavedCoordinate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      coordinate: coordinate,
      savedAt: DateTime.now().toUtc(),
    );

    existing.insert(0, saved);
    await _persist(existing);
    return saved;
  }

  Future<void> delete(String id) async {
    final existing = await getAll();
    existing.removeWhere((item) => item.id == id);
    await _persist(existing);
  }

  Future<SavedCoordinate?> getById(String id) async {
    final all = await getAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _persist(List<SavedCoordinate> coordinates) async {
    final encoded = jsonEncode(coordinates.map((c) => c.toJson()).toList());
    await _secureStorage.write(_storageKey, encoded);
  }
}
