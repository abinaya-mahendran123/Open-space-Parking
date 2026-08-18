import 'package:open_space_parking/core/mongodb/models/mongo_document.dart';
import 'package:open_space_parking/core/mongodb/mongo_collections.dart';
import 'package:open_space_parking/core/mongodb/utils/mongo_serializer.dart';

class BookingDocument extends MongoDocument {
  const BookingDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.bookingRef,
    required this.vehicleOwnerId,
    required this.parkingListingId,
    required this.status,
    required this.totalPrice,
    required this.startDateTime,
    required this.endDateTime,
    this.payload = const {},
  });

  final String bookingRef;
  final String vehicleOwnerId;
  final String parkingListingId;
  final String status;
  final double totalPrice;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingRef': bookingRef,
        'vehicleOwnerId': vehicleOwnerId,
        'parkingListingId': parkingListingId,
        'status': status,
        'totalPrice': totalPrice,
        'startDateTime': MongoSerializer.isoDate(startDateTime),
        'endDateTime': MongoSerializer.isoDate(endDateTime),
        ...payload,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory BookingDocument.fromJson(Map<String, dynamic> json) {
    return BookingDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      bookingRef: json['bookingRef'] as String? ?? '',
      vehicleOwnerId: json['vehicleOwnerId'] as String? ?? '',
      parkingListingId: json['parkingListingId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      startDateTime: MongoSerializer.parseDate(json['startDateTime']),
      endDateTime: MongoSerializer.parseDate(json['endDateTime']),
      payload: Map<String, dynamic>.from(json),
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, bookingRef, vehicleOwnerId, parkingListingId, status];
}

class NotificationDocument extends MongoDocument {
  const NotificationDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.recipientId,
    required this.recipientType,
    required this.title,
    required this.message,
    this.isRead = false,
    this.referenceId,
  });

  final String recipientId;
  final String recipientType;
  final String title;
  final String message;
  final bool isRead;
  final String? referenceId;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientId': recipientId,
        'recipientType': recipientType,
        'title': title,
        'message': message,
        'isRead': isRead,
        if (referenceId != null) 'referenceId': referenceId,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory NotificationDocument.fromJson(Map<String, dynamic> json) {
    return NotificationDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      recipientId: json['recipientId'] as String? ??
          json['vehicleOwnerId'] as String? ??
          json['ownerId'] as String? ??
          '',
      recipientType: json['recipientType'] as String? ?? 'vehicle_owner',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId'] as String? ?? json['bookingRef'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, recipientId, recipientType, title, isRead];
}

class PaymentDocument extends MongoDocument {
  const PaymentDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.method,
    this.transactionRef,
  });

  final String bookingId;
  final double amount;
  final String currency;
  final String status;
  final String method;
  final String? transactionRef;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'method': method,
        if (transactionRef != null) 'transactionRef': transactionRef,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory PaymentDocument.fromJson(Map<String, dynamic> json) {
    return PaymentDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      bookingId: json['bookingId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'pending',
      method: json['method'] as String? ?? 'upi',
      transactionRef: json['transactionRef'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, bookingId, amount, currency, status, method];
}

class ReviewDocument extends MongoDocument {
  const ReviewDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.parkingListingId,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    this.reviewerName,
  });

  final String parkingListingId;
  final String reviewerId;
  final int rating;
  final String comment;
  final String? reviewerName;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'parkingListingId': parkingListingId,
        'reviewerId': reviewerId,
        'vehicleOwnerId': reviewerId,
        'rating': rating,
        'comment': comment,
        if (reviewerName != null) 'reviewerName': reviewerName,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory ReviewDocument.fromJson(Map<String, dynamic> json) {
    return ReviewDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      parkingListingId: json['parkingListingId'] as String? ?? '',
      reviewerId: json['reviewerId'] as String? ??
          json['vehicleOwnerId'] as String? ??
          '',
      rating: json['rating'] as int? ?? 5,
      comment: json['comment'] as String? ?? '',
      reviewerName: json['reviewerName'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, parkingListingId, reviewerId, rating, comment];
}

class StoredFileDocument extends MongoDocument {
  const StoredFileDocument({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.ownerId,
    required this.ownerType,
    required this.fileName,
    required this.fileType,
    required this.url,
    this.publicId = '',
    this.resourceType = 'auto',
    this.referenceId,
  });

  final String ownerId;
  final String ownerType;
  final String fileName;
  final String fileType;
  final String url;
  final String publicId;
  final String resourceType;
  final String? referenceId;

  /// Legacy alias — stores the Cloudinary URL only.
  String get storagePath => url;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'ownerType': ownerType,
        'fileName': fileName,
        'fileType': fileType,
        'url': url,
        'publicId': publicId,
        'resourceType': resourceType,
        if (referenceId != null) 'referenceId': referenceId,
        MongoFields.createdAt: MongoSerializer.isoDate(createdAt),
        MongoFields.updatedAt: MongoSerializer.isoDate(updatedAt),
        if (deletedAt != null) MongoFields.deletedAt: MongoSerializer.isoDate(deletedAt!),
        MongoFields.isDeleted: isDeleted,
      };

  factory StoredFileDocument.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String? ??
        json['storagePath'] as String? ??
        '';
    return StoredFileDocument(
      id: MongoSerializer.idFrom(json[MongoFields.id] ?? json['id']),
      createdAt: MongoSerializer.parseDate(json[MongoFields.createdAt]),
      updatedAt: MongoSerializer.parseDate(json[MongoFields.updatedAt]),
      deletedAt: json[MongoFields.deletedAt] != null
          ? MongoSerializer.parseDate(json[MongoFields.deletedAt])
          : null,
      ownerId: json['ownerId'] as String? ?? '',
      ownerType: json['ownerType'] as String? ?? 'land_owner',
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? '',
      url: url,
      publicId: json['publicId'] as String? ?? '',
      resourceType: json['resourceType'] as String? ?? 'auto',
      referenceId: json['referenceId'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [...super.props, ownerId, ownerType, fileName, fileType, url, publicId];
}
