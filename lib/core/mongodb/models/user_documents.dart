import 'package:open_space_parking/core/mongodb/models/mongo_document.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';

class UserDocument extends MongoDocument {
  const UserDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.email,
    required this.displayName,
    required this.role,
    this.passwordHash,
    this.passwordSalt,
  });

  final String email;
  final String displayName;
  final String role;
  final String? passwordHash;
  final String? passwordSalt;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
        'email': email,
        'displayName': displayName,
        'role': role,
        if (passwordHash != null) 'passwordHash': passwordHash,
        if (passwordSalt != null) 'passwordSalt': passwordSalt,
      };

  factory UserDocument.fromJson(Map<String, dynamic> json) {
    return UserDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'vehicle_owner',
      passwordHash: json['passwordHash'] as String?,
      passwordSalt: json['passwordSalt'] as String?,
    );
  }

  @override
  List<Object?> get props => [...super.props, email, displayName, role];
}

class EmployeeDocument extends MongoDocument {
  const EmployeeDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.email,
    required this.fullName,
    required this.isActive,
    this.phone,
    this.passwordHash,
    this.passwordSalt,
  });

  final String email;
  final String fullName;
  final bool isActive;
  final String? phone;
  final String? passwordHash;
  final String? passwordSalt;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
        'email': email,
        'fullName': fullName,
        'isActive': isActive,
        if (phone != null) 'phone': phone,
        if (passwordHash != null) 'passwordHash': passwordHash,
        if (passwordSalt != null) 'passwordSalt': passwordSalt,
      };

  factory EmployeeDocument.fromJson(Map<String, dynamic> json) {
    return EmployeeDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      phone: json['phone'] as String?,
      passwordHash: json['passwordHash'] as String?,
      passwordSalt: json['passwordSalt'] as String?,
    );
  }

  @override
  List<Object?> get props => [...super.props, email, fullName, isActive];
}

class VehicleOwnerDocument extends MongoDocument {
  const VehicleOwnerDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.userId,
    required this.profile,
  });

  final String userId;
  final Map<String, dynamic> profile;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleOwnerId': userId,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
        'profile': profile,
      };

  factory VehicleOwnerDocument.fromJson(Map<String, dynamic> json) {
    return VehicleOwnerDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      userId: json['vehicleOwnerId'] as String? ?? '',
      profile: json['profile'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [...super.props, userId, profile];
}

class LandOwnerDocument extends MongoDocument {
  const LandOwnerDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ownerId,
    required this.ownerDetails,
  });

  final String ownerId;
  final Map<String, dynamic> ownerDetails;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
        'ownerDetails': ownerDetails,
      };

  factory LandOwnerDocument.fromJson(Map<String, dynamic> json) {
    return LandOwnerDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      ownerId: json['ownerId'] as String? ?? '',
      ownerDetails: json['ownerDetails'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [...super.props, ownerId, ownerDetails];
}
