import 'package:equatable/equatable.dart';

class ConstructionProgressEntry extends Equatable {
  const ConstructionProgressEntry({
    required this.id,
    required this.ticketId,
    required this.requestId,
    required this.employeeId,
    required this.progressPercent,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String requestId;
  final String employeeId;
  final int progressPercent;
  final String notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        ticketId,
        requestId,
        employeeId,
        progressPercent,
        notes,
        createdAt,
      ];
}
