import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/features/authentication/data/repositories/mongo_auth_repository.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';

import '../helpers/auth_fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockMongoDatabaseService databaseService;
  late MockMongoCollectionService collectionService;
  late MongoAuthRepository repository;

  setUpAll(() async {
    await initTestEnvironment();
    registerFallbackValues();
  });

  setUp(() {
    databaseService = MockMongoDatabaseService();
    collectionService = MockMongoCollectionService();
    repository = MongoAuthRepository(
      mongoDatabaseService: databaseService,
      mongoCollectionService: collectionService,
    );

    when(() => databaseService.isConnected).thenReturn(true);
  });

  group('MongoAuthRepository', () {
    group('loginAppUser', () {
      test('returns session for valid vehicle owner credentials', () async {
        final user = AuthFixtures.userDocument(role: UserRole.vehicleOwner);
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => user);

        final session = await repository.loginAppUser(
          email: AuthFixtures.testEmail,
          password: AuthFixtures.testPassword,
        );

        expect(session.email, AuthFixtures.testEmail.toLowerCase());
        expect(session.role, UserRole.vehicleOwner);
        expect(session.jwtToken, isNotEmpty);
      });

      test('throws when credentials invalid', () async {
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => null);

        expect(
          () => repository.loginAppUser(
            email: AuthFixtures.testEmail,
            password: AuthFixtures.testPassword,
          ),
          throwsA(isA<AppException>()),
        );
      });

      test('returns session for valid admin credentials', () async {
        final user = AuthFixtures.userDocument(role: UserRole.admin);
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => user);

        final session = await repository.loginAppUser(
          email: AuthFixtures.testEmail,
          password: AuthFixtures.testPassword,
        );

        expect(session.role, UserRole.admin);
      });
    });

    group('loginAdmin', () {
      test('returns session for valid admin credentials', () async {
        final user = AuthFixtures.userDocument(role: UserRole.admin);
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => user);

        final session = await repository.loginAdmin(
          email: AuthFixtures.testEmail,
          password: AuthFixtures.testPassword,
        );

        expect(session.role, UserRole.admin);
      });

      test('throws when non-admin tries admin login', () async {
        final user = AuthFixtures.userDocument(role: UserRole.landOwner);
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => user);

        expect(
          () => repository.loginAdmin(
            email: AuthFixtures.testEmail,
            password: AuthFixtures.testPassword,
          ),
          throwsA(
            predicate<AppException>(
              (e) => e.message.contains('Only admins can login'),
            ),
          ),
        );
      });
    });

    group('loginEmployee', () {
      test('returns session for active employee', () async {
        final employee = AuthFixtures.employeeDocument();
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.employeesCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => employee);

        final session = await repository.loginEmployee(
          phone: '9876543210',
          password: AuthFixtures.testPassword,
        );

        expect(session.role, UserRole.employee);
      });

      test('throws when employee inactive', () async {
        final employee = AuthFixtures.employeeDocument(isActive: false);
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.employeesCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => employee);

        expect(
          () => repository.loginEmployee(
            phone: '9876543210',
            password: AuthFixtures.testPassword,
          ),
          throwsA(
            predicate<AppException>(
              (e) => e.message.contains('inactive'),
            ),
          ),
        );
      });
    });

    group('register', () {
      test('creates user and returns session', () async {
        when(
          () => collectionService.findOne(
            collectionName: any(named: 'collectionName'),
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => collectionService.insertOne(
            collectionName: any(named: 'collectionName'),
            document: any(named: 'document'),
          ),
        ).thenAnswer((_) async => FakeWriteResult());

        final session = await repository.register(
          email: 'newuser@test.com',
          password: AuthFixtures.testPassword,
          displayName: 'New User',
          role: UserRole.landOwner,
        );

        expect(session.email, 'newuser@test.com');
        expect(session.role, UserRole.landOwner);
        verify(
          () => collectionService.insertOne(
            collectionName: AppConstants.usersCollection,
            document: any(named: 'document'),
          ),
        ).called(1);
        verify(
          () => collectionService.insertOne(
            collectionName: AppConstants.landOwnerProfilesCollection,
            document: any(named: 'document'),
          ),
        ).called(1);
      });

      test('throws when email already exists', () async {
        when(
          () => collectionService.findOne(
            collectionName: AppConstants.usersCollection,
            selector: any(named: 'selector'),
          ),
        ).thenAnswer((_) async => AuthFixtures.userDocument());

        expect(
          () => repository.register(
            email: AuthFixtures.testEmail,
            password: AuthFixtures.testPassword,
            displayName: 'Dup',
            role: UserRole.vehicleOwner,
          ),
          throwsA(
            predicate<AppException>(
              (e) => e.message.contains('already exists'),
            ),
          ),
        );
      });

      test('throws when registering admin role', () async {
        expect(
          () => repository.register(
            email: 'x@test.com',
            password: AuthFixtures.testPassword,
            displayName: 'Admin',
            role: UserRole.admin,
          ),
          throwsA(isA<AppException>()),
        );
      });
    });
  });
}
