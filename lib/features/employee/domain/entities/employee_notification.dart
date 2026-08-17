import 'package:equatable/equatable.dart';

class EmployeeNotification extends Equatable {
  const EmployeeNotification({
    required this.id,
    required this.employeeId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.ticketId,
  });

  final String id;
  final String employeeId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? ticketId;

  @override
  List<Object?> get props =>
      [id, employeeId, title, message, createdAt, isRead, ticketId];
}
