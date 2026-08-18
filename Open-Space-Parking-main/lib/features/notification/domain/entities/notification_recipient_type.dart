enum NotificationRecipientType {
  vehicleOwner('vehicle_owner'),
  landOwner('land_owner'),
  employee('employee'),
  admin('admin');

  const NotificationRecipientType(this.value);

  final String value;

  static NotificationRecipientType fromValue(String value) {
    return NotificationRecipientType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationRecipientType.vehicleOwner,
    );
  }
}
