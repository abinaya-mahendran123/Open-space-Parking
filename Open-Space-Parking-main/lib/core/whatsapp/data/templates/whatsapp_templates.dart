import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';

class WhatsAppTemplateDefinition {
  const WhatsAppTemplateDefinition({
    required this.id,
    required this.name,
    required this.body,
    required this.variableKeys,
  });

  final WhatsAppTemplateId id;
  final String name;
  final String body;
  final List<String> variableKeys;

  String render(Map<String, String> variables) {
    var rendered = body;
    for (final key in variableKeys) {
      rendered = rendered.replaceAll('{{$key}}', variables[key] ?? '');
    }
    return rendered;
  }
}

/// Reusable WhatsApp message templates with {{variable}} placeholders.
class WhatsAppTemplates {
  WhatsAppTemplates._();

  static const employeeAssignment = WhatsAppTemplateDefinition(
    id: WhatsAppTemplateId.employeeAssignment,
    name: 'Employee Assignment',
    body:
        'Hello {{employeeName}}, you have been assigned to ticket {{ticketId}} '
        'for Open Space Parking. Location: {{location}}. '
        'Please review the project in your employee portal.',
    variableKeys: ['employeeName', 'ticketId', 'location'],
  );

  static const ownerAssignment = WhatsAppTemplateDefinition(
    id: WhatsAppTemplateId.ownerAssignment,
    name: 'Owner Assignment Update',
    body:
        'Hello {{ownerName}}, your parking request {{ticketId}} has been assigned '
        'to our field employee {{employeeName}}. '
        'We will contact you shortly regarding the next steps.',
    variableKeys: ['ownerName', 'ticketId', 'employeeName'],
  );

  static const bookingConfirmation = WhatsAppTemplateDefinition(
    id: WhatsAppTemplateId.bookingConfirmation,
    name: 'Booking Confirmation',
    body:
        'Hi {{customerName}}, your parking booking {{bookingRef}} is confirmed '
        'from {{startTime}} to {{endTime}}. Total: {{amount}}.',
    variableKeys: ['customerName', 'bookingRef', 'startTime', 'endTime', 'amount'],
  );

  static const requestStatusUpdate = WhatsAppTemplateDefinition(
    id: WhatsAppTemplateId.requestStatusUpdate,
    name: 'Request Status Update',
    body:
        'Hello {{recipientName}}, your request {{ticketId}} status is now: '
        '{{status}}. Open Space Parking.',
    variableKeys: ['recipientName', 'ticketId', 'status'],
  );

  static WhatsAppTemplateDefinition resolve(WhatsAppTemplateId id) {
    return switch (id) {
      WhatsAppTemplateId.employeeAssignment => employeeAssignment,
      WhatsAppTemplateId.ownerAssignment => ownerAssignment,
      WhatsAppTemplateId.bookingConfirmation => bookingConfirmation,
      WhatsAppTemplateId.requestStatusUpdate => requestStatusUpdate,
    };
  }

  static List<WhatsAppTemplateDefinition> get all => [
        employeeAssignment,
        ownerAssignment,
        bookingConfirmation,
        requestStatusUpdate,
      ];
}
