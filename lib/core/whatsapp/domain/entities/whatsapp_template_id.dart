enum WhatsAppTemplateId {
  employeeAssignment('employee_assignment'),
  ownerAssignment('owner_assignment'),
  bookingConfirmation('booking_confirmation'),
  requestStatusUpdate('request_status_update');

  const WhatsAppTemplateId(this.value);

  final String value;
}
