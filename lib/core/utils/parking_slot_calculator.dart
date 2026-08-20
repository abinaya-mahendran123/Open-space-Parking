/// Resolves how many parking slots a land/parking listing should expose.
///
/// - Build / construction requests → fixed high capacity (mechanical systems).
/// - Existing / open land → estimate from plot area using a basic car stall size.
class ParkingSlotCalculator {
  ParkingSlotCalculator._();

  /// Slots shown when the owner builds a constructed/mechanical parking system.
  static const int constructedParkingSlots = 100;

  /// Basic stall footprint including drive-aisle share (ft × ft).
  /// Typical bay ~8.5×18, plus shared aisle ≈ 150 sq ft per car.
  static const double sqFtPerCar = 150;

  static int slotsForConstruction() => constructedParkingSlots;

  static int slotsFromLandArea(double areaSqFt) {
    if (!areaSqFt.isFinite || areaSqFt <= 0) return 1;
    final slots = (areaSqFt / sqFtPerCar).floor();
    return slots < 1 ? 1 : slots;
  }

  /// [requestType] is `build_parking` or `existing_parking` (or null).
  static int resolveCapacity({
    required String? requestType,
    required double areaSqFt,
    int? storedNumberOfCars,
  }) {
    final type = requestType?.trim().toLowerCase() ?? '';
    if (type == 'build_parking') {
      return constructedParkingSlots;
    }

    // Existing / open land: always derive from sq ft when area is known.
    if (areaSqFt > 0) {
      return slotsFromLandArea(areaSqFt);
    }

    if (storedNumberOfCars != null && storedNumberOfCars > 0) {
      return storedNumberOfCars;
    }
    return 1;
  }
}
