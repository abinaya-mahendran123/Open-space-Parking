import 'package:equatable/equatable.dart';

class LandDetails extends Equatable {
  const LandDetails({
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.areaSqFt,
    required this.roadAccess,
    required this.drainage,
    required this.flood,
    required this.boundary,
    required this.cctv,
    this.landAddress,
  });

  final double gpsLatitude;
  final double gpsLongitude;
  final double areaSqFt;
  final bool roadAccess;
  final bool drainage;
  final bool flood;
  final bool boundary;
  final bool cctv;
  final String? landAddress;

  Map<String, dynamic> toJson() => {
        'gpsLatitude': gpsLatitude,
        'gpsLongitude': gpsLongitude,
        'areaSqFt': areaSqFt,
        'roadAccess': roadAccess,
        'drainage': drainage,
        'flood': flood,
        'boundary': boundary,
        'cctv': cctv,
        'landAddress': landAddress,
      };

  factory LandDetails.fromJson(Map<String, dynamic> json) {
    double parseCoord(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      return value == true || value == 1 || value == 'true' || value == '1';
    }

    return LandDetails(
      gpsLatitude: parseCoord(json['gpsLatitude']),
      gpsLongitude: parseCoord(json['gpsLongitude']),
      areaSqFt: parseCoord(json['areaSqFt']),
      roadAccess: parseBool(json['roadAccess']),
      drainage: parseBool(json['drainage']),
      flood: parseBool(json['flood']),
      boundary: parseBool(json['boundary']),
      cctv: parseBool(json['cctv']),
      landAddress: json['landAddress'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        gpsLatitude,
        gpsLongitude,
        areaSqFt,
        roadAccess,
        drainage,
        flood,
        boundary,
        cctv,
        landAddress,
      ];
}
