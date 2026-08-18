class TicketSmsDeliveryResult {
  const TicketSmsDeliveryResult({
    required this.delivered,
    required this.phone,
    this.simulated = false,
    this.messageId,
  });

  final bool delivered;
  final String phone;
  final bool simulated;
  final String? messageId;
}
