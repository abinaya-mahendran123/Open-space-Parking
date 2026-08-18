import 'package:equatable/equatable.dart';

class OwnerDetails extends Equatable {
  const OwnerDetails({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.address,
    this.aadhaarNumber,
  });

  final String fullName;
  final String phone;
  final String email;
  final String address;
  final String? aadhaarNumber;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'address': address,
        'aadhaarNumber': aadhaarNumber,
      };

  factory OwnerDetails.fromJson(Map<String, dynamic> json) {
    return OwnerDetails(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      aadhaarNumber: json['aadhaarNumber'] as String?,
    );
  }

  @override
  List<Object?> get props => [fullName, phone, email, address, aadhaarNumber];
}
