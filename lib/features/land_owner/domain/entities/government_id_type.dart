enum GovernmentIdType {
  aadhaar,
  pan,
  drivingLicense,
  voterId;

  String get label => switch (this) {
        GovernmentIdType.aadhaar => 'Aadhaar',
        GovernmentIdType.pan => 'PAN',
        GovernmentIdType.drivingLicense => 'Driving License',
        GovernmentIdType.voterId => 'Voter ID',
      };

  String get apiValue => switch (this) {
        GovernmentIdType.aadhaar => 'aadhaar',
        GovernmentIdType.pan => 'pan',
        GovernmentIdType.drivingLicense => 'driving_license',
        GovernmentIdType.voterId => 'voter_id',
      };

  static GovernmentIdType? fromApiValue(String? value) {
    if (value == null || value.isEmpty) return null;
    return switch (value) {
      'aadhaar' => GovernmentIdType.aadhaar,
      'pan' => GovernmentIdType.pan,
      'driving_license' => GovernmentIdType.drivingLicense,
      'voter_id' => GovernmentIdType.voterId,
      _ => null,
    };
  }
}
