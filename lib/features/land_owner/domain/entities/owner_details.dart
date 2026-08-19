import 'package:equatable/equatable.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/government_id_type.dart';

class OwnerDetails extends Equatable {
  const OwnerDetails({
    required this.fullName,
    required this.phone,
    required this.email,
    required this.address,
    this.aadhaarNumber,
    this.governmentIdType,
    this.governmentIdNumber,
    this.governmentIdFrontPath,
    this.governmentIdBackPath,
  });

  static const _unset = Object();

  final String fullName;
  final String phone;
  final String email;
  final String address;
  final String? aadhaarNumber;
  final GovernmentIdType? governmentIdType;
  final String? governmentIdNumber;
  final String? governmentIdFrontPath;
  final String? governmentIdBackPath;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'address': address,
        'aadhaarNumber': aadhaarNumber,
        'governmentIdType': governmentIdType?.apiValue,
        'governmentIdNumber': governmentIdNumber,
        'governmentIdFrontPath': governmentIdFrontPath,
        'governmentIdBackPath': governmentIdBackPath,
      };

  factory OwnerDetails.fromJson(Map<String, dynamic> json) {
    final idType = GovernmentIdType.fromApiValue(json['governmentIdType'] as String?);
    final idNumber = json['governmentIdNumber'] as String? ??
        json['aadhaarNumber'] as String?;

    return OwnerDetails(
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      aadhaarNumber: json['aadhaarNumber'] as String?,
      governmentIdType: idType ??
          (json['aadhaarNumber'] != null ? GovernmentIdType.aadhaar : null),
      governmentIdNumber: idNumber,
      governmentIdFrontPath: json['governmentIdFrontPath'] as String?,
      governmentIdBackPath: json['governmentIdBackPath'] as String?,
    );
  }

  OwnerDetails copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? address,
    Object? aadhaarNumber = _unset,
    Object? governmentIdType = _unset,
    Object? governmentIdNumber = _unset,
    Object? governmentIdFrontPath = _unset,
    Object? governmentIdBackPath = _unset,
  }) {
    return OwnerDetails(
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      aadhaarNumber:
          identical(aadhaarNumber, _unset) ? this.aadhaarNumber : aadhaarNumber as String?,
      governmentIdType: identical(governmentIdType, _unset)
          ? this.governmentIdType
          : governmentIdType as GovernmentIdType?,
      governmentIdNumber: identical(governmentIdNumber, _unset)
          ? this.governmentIdNumber
          : governmentIdNumber as String?,
      governmentIdFrontPath: identical(governmentIdFrontPath, _unset)
          ? this.governmentIdFrontPath
          : governmentIdFrontPath as String?,
      governmentIdBackPath: identical(governmentIdBackPath, _unset)
          ? this.governmentIdBackPath
          : governmentIdBackPath as String?,
    );
  }

  @override
  List<Object?> get props => [
        fullName,
        phone,
        email,
        address,
        aadhaarNumber,
        governmentIdType,
        governmentIdNumber,
        governmentIdFrontPath,
        governmentIdBackPath,
      ];
}
