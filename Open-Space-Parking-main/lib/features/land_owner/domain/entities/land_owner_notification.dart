import 'package:equatable/equatable.dart';

class LandOwnerNotification extends Equatable {
  const LandOwnerNotification({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.ticketId,
  });

  final String id;
  final String ownerId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? ticketId;

  @override
  List<Object?> get props => [id, ownerId, title, message, createdAt, isRead, ticketId];
}
