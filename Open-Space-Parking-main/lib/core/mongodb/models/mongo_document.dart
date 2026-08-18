import 'package:equatable/equatable.dart';

/// Base contract for MongoDB document models.
abstract class MongoDocument extends Equatable {
  const MongoDocument({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson();

  @override
  List<Object?> get props => [id, createdAt, updatedAt, deletedAt];
}
