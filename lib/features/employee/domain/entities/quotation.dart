import 'package:equatable/equatable.dart';

class Quotation extends Equatable {
  const Quotation({
    required this.id,
    required this.ticketId,
    required this.requestId,
    required this.employeeId,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.materialsCost = 0,
    this.laborCost = 0,
    this.timelineDays = 0,
  });

  final String id;
  final String ticketId;
  final String requestId;
  final String employeeId;
  final double amount;
  final String description;
  final DateTime createdAt;
  final double materialsCost;
  final double laborCost;
  final int timelineDays;

  @override
  List<Object?> get props => [
        id,
        ticketId,
        requestId,
        employeeId,
        amount,
        description,
        createdAt,
        materialsCost,
        laborCost,
        timelineDays,
      ];
}
