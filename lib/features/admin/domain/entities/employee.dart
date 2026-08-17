import 'package:equatable/equatable.dart';

class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleTitle,
    required this.isActive,
    required this.createdAt,
    this.assignedTicketCount = 0,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String roleTitle;
  final bool isActive;
  final DateTime createdAt;
  final int assignedTicketCount;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'roleTitle': roleTitle,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'assignedTicketCount': assignedTicketCount,
      };

  factory Employee.fromMap(Map<String, dynamic> map, {required String id}) {
    return Employee(
      id: id,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      roleTitle: map['roleTitle'] as String? ?? 'Field Employee',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      ),
      assignedTicketCount: map['assignedTicketCount'] as int? ?? 0,
    );
  }

  Employee copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? roleTitle,
    bool? isActive,
    int? assignedTicketCount,
  }) {
    return Employee(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roleTitle: roleTitle ?? this.roleTitle,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      assignedTicketCount: assignedTicketCount ?? this.assignedTicketCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        roleTitle,
        isActive,
        createdAt,
        assignedTicketCount,
      ];
}
