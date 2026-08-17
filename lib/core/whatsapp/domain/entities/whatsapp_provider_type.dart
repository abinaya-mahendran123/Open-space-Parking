enum WhatsAppProviderType {
  none('none'),
  meta('meta'),
  twilio('twilio');

  const WhatsAppProviderType(this.value);

  final String value;

  static WhatsAppProviderType fromValue(String value) {
    return WhatsAppProviderType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => WhatsAppProviderType.none,
    );
  }
}
