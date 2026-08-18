enum LandOwnerRequestType {
  buildParking,
  existingParking,
}

extension LandOwnerRequestTypeX on LandOwnerRequestType {
  String get label {
    switch (this) {
      case LandOwnerRequestType.buildParking:
        return 'I Want to Build Parking';
      case LandOwnerRequestType.existingParking:
        return 'Already Have Parking';
    }
  }

  String get value {
    switch (this) {
      case LandOwnerRequestType.buildParking:
        return 'build_parking';
      case LandOwnerRequestType.existingParking:
        return 'existing_parking';
    }
  }

  static LandOwnerRequestType fromValue(String value) {
    return LandOwnerRequestType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LandOwnerRequestType.buildParking,
    );
  }
}
