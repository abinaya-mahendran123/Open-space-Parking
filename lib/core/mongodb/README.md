# MongoDB Integration Layer

Unified MongoDB infrastructure for Open Space Parking with models, repositories, services, CRUD, indexes, pagination, search, soft delete, and serialization.

## Collections

| Canonical | Physical Collection | Model |
|-----------|---------------------|-------|
| `users` | `users` | `UserDocument` |
| `employees` | `employees` | `EmployeeDocument` |
| `vehicle_owners` | `vehicle_owner_profiles` | `VehicleOwnerDocument` |
| `land_owners` | `land_owner_profiles` | `LandOwnerDocument` |
| `parking_spaces` | `parking_spaces` | `ParkingSpaceDocument` |
| `construction_requests` | `land_owner_requests` | `ConstructionRequestDocument` |
| `bookings` | `bookings` | `BookingDocument` |
| `notifications` | `notifications` | `NotificationDocument` |
| `payments` | `payments` | `PaymentDocument` |
| `reviews` | `parking_reviews` | `ReviewDocument` |
| `documents` | `documents` | `StoredFileDocument` |
| `tickets` | `land_owner_requests` | `TicketDocument` |

Legacy physical names preserve existing feature-module data without migration.

## Architecture

```
core/mongodb/
├── mongo_collections.dart       Collection registry + legacy mapping
├── utils/mongo_serializer.dart  ObjectId, dates, audit fields
├── models/                      Document models (serialization)
├── repositories/
│   ├── base_mongo_repository.dart  Generic CRUD + pagination + search
│   └── mongo_repositories.dart     12 collection repositories
├── services/
│   ├── mongo_data_service.dart        Extended CRUD operations
│   ├── mongo_index_service.dart       Index bootstrapping
│   └── mongo_integration_service.dart Connect + indexes on startup
└── providers/mongo_providers.dart     Riverpod providers
```

## Features

| Feature | API |
|---------|-----|
| **CRUD** | `create`, `findById`, `update`, `softDelete`, `hardDelete`, `restore` |
| **Pagination** | `findPaginated(SearchQuery)` → `PaginatedResult<T>` |
| **Search** | `SearchQuery.textQuery` + `searchFields` regex OR filters |
| **Soft Delete** | `isDeleted` + `deletedAt` fields, excluded by default |
| **Serialization** | `MongoDocument.toJson()` / `fromJson()` + `MongoSerializer` |
| **Indexes** | Auto-created on app startup via `MongoIndexService` |

## Usage

### Riverpod
```dart
final users = ref.watch(userMongoRepositoryProvider);
final page = await users.findPaginated(
  SearchQuery(textQuery: 'john', page: 1, pageSize: 20),
);
```

### GetIt
```dart
final bookings = sl<BookingMongoRepository>();
await bookings.softDelete(bookingId);
```

### SearchQuery
```dart
SearchQuery(
  filters: {'status': 'confirmed'},
  textQuery: 'OSP-2026',
  searchFields: ['ticketId', 'ownerId'],
  page: 1,
  pageSize: 20,
  sortField: 'createdAt',
  sortDescending: true,
)
```

## Startup

`main.dart` calls `MongoIntegrationService.initialize()` which:
1. Connects to MongoDB
2. Ensures indexes on all collections

## Audit Fields

All documents support:
- `createdAt`, `updatedAt`
- `isDeleted`, `deletedAt` (soft delete)
