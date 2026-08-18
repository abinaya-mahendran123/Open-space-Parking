import 'package:open_space_parking/core/mongodb/models/mongo_document.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';

class ParkingSpaceDocument extends MongoDocument {
  const ParkingSpaceDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.landOwnerId,
    required this.parkingType,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.hourlyRate,
    required this.status,
    this.address,
    this.constructionRequestId,
  });

  final String landOwnerId;
  final String parkingType;
  final double latitude;
  final double longitude;
  final int capacity;
  final double hourlyRate;
  final String status;
  final String? address;
  final String? constructionRequestId;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
        'landOwnerId': landOwnerId,
        'parkingType': parkingType,
        'latitude': latitude,
        'longitude': longitude,
        'capacity': capacity,
        'hourlyRate': hourlyRate,
        'status': status,
        if (address != null) 'address': address,
        if (constructionRequestId != null)
          'constructionRequestId': constructionRequestId,
      };

  factory ParkingSpaceDocument.fromJson(Map<String, dynamic> json) {
    return ParkingSpaceDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      landOwnerId: json['landOwnerId'] as String? ?? '',
      parkingType: json['parkingType'] as String? ?? 'tower_parking',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      capacity: json['capacity'] as int? ?? 1,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'available',
      address: json['address'] as String?,
      constructionRequestId: json['constructionRequestId'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, landOwnerId, parkingType, latitude, longitude, status];
}

class ConstructionRequestDocument extends MongoDocument {
  const ConstructionRequestDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ticketId,
    required this.ownerId,
    required this.requestType,
    required this.status,
    required this.payload,
  });

  final String ticketId;
  final String ownerId;
  final String requestType;
  final String status;
  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'ownerId': ownerId,
        'requestType': requestType,
        'status': status,
        ...payload,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory ConstructionRequestDocument.fromJson(Map<String, dynamic> json) {
    final payload = Map<String, dynamic>.from(json)
      ..remove(MongoFields.id)
      ..remove('id')
      ..remove(MongoFields.createdAt)
      ..remove(MongoFields.updatedAt)
      ..remove(MongoFields.deletedAt)
      ..remove(MongoFields.isDeleted);

    return ConstructionRequestDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(
        json[MongoFields.createdAt] ?? json['submittedAt'],
      ),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      ticketId: json['ticketId'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      requestType: json['requestType'] as String? ?? '',
      status: json['status'] as String? ?? 'submitted',
      payload: payload,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, ticketId, ownerId, requestType, status];
}

class TicketDocument extends MongoDocument {
  const TicketDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ticketId,
    required this.type,
    required this.status,
    required this.referenceId,
    this.assignedTo,
  });

  final String ticketId;
  final String type;
  final String status;
  final String referenceId;
  final String? assignedTo;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'type': type,
        'status': status,
        'referenceId': referenceId,
        if (assignedTo != null) 'assignedTo': assignedTo,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory TicketDocument.fromJson(Map<String, dynamic> json) {
    return TicketDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(
        json[MongoFields.createdAt] ?? json['submittedAt'],
      ),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      ticketId: json['ticketId'] as String? ?? '',
      type: json['type'] as String? ?? json['requestType'] as String? ?? '',
      status: json['status'] as String? ?? '',
      referenceId: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      assignedTo: json['assignedEmployeeId'] as String? ?? json['assignedTo'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, ticketId, type, status, referenceId, assignedTo];
}
