import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_file_category.dart';
import 'package:open_space_parking/core/cloudinary/data/services/cloudinary_validation_service.dart';
import 'package:open_space_parking/core/services/session_service.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

import '../helpers/auth_fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  group('SessionService', () {
    late MockSecureStorageService storage;
    late SessionService sessionService;

    setUp(() {
      storage = MockSecureStorageService();
      sessionService = SessionService(storage);
    });

    test('saveSession writes JSON to secure storage', () async {
      final session = AuthFixtures.session(role: UserRole.landOwner);

      when(() => storage.write(any(), any())).thenAnswer((_) async {});

      await sessionService.saveSession(session);

      verify(
        () => storage.write(
          'auth_session',
          jsonEncode(session.toJson()),
        ),
      ).called(1);
    });

    test('readSession returns null when storage empty', () async {
      when(() => storage.read(any())).thenAnswer((_) async => null);

      final result = await sessionService.readSession();

      expect(result, isNull);
    });

    test('readSession deserializes stored session', () async {
      final session = AuthFixtures.session();
      when(() => storage.read('auth_session')).thenAnswer(
        (_) async => jsonEncode(session.toJson()),
      );

      final result = await sessionService.readSession();

      expect(result, equals(session));
    });

    test('clearSession deletes storage key', () async {
      when(() => storage.delete(any())).thenAnswer((_) async {});

      await sessionService.clearSession();

      verify(() => storage.delete('auth_session')).called(1);
    });
  });

  group('CloudinaryValidationService', () {
    late CloudinaryValidationService validationService;
    late Directory tempDir;

    setUp(() async {
      validationService = CloudinaryValidationService();
      tempDir = await Directory.systemTemp.createTemp('osp_cloudinary_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<String> writeTempFile(String name, List<int> bytes) async {
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);
      return file.path;
    }

    test('returns invalid when file missing', () async {
      final result = await validationService.validate(
        localPath: '${tempDir.path}/missing.jpg',
        category: CloudinaryFileCategory.image,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, 'File not found.');
    });

    test('returns invalid for disallowed extension', () async {
      final path = await writeTempFile('doc.exe', [1, 2, 3]);
      final result = await validationService.validate(
        localPath: path,
        category: CloudinaryFileCategory.image,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Invalid file type'));
    });

    test('returns valid for small png image bytes', () async {
      final result = await validationService.validateBytes(
        fileBytes: [1, 2, 3, 4],
        fileName: 'photo.png',
        category: CloudinaryFileCategory.image,
      );

      expect(result.isValid, isTrue);
      expect(result.extension, 'png');
      expect(result.mimeType, 'image/png');
    });
  });
}
