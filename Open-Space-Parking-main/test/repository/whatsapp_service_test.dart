import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/whatsapp/data/services/whatsapp_service.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('WhatsAppService', () {
    late WhatsAppService service;

    setUp(() {
      service = WhatsAppService();
    });

    test('sendEmployeeAssignment simulates when provider not configured', () async {
      final result = await service.sendEmployeeAssignment(
        employeePhone: '+919876543210',
        employeeName: 'Alex',
        ticketId: 'OSP-1001',
        location: 'Downtown',
      );

      expect(result.success, isTrue);
      expect(result.simulated, isTrue);
      expect(result.provider, WhatsAppProviderType.meta);
    });

    test('sendOwnerAssignment simulates for land owner phone', () async {
      final result = await service.sendOwnerAssignment(
        ownerPhone: '+919123456789',
        ownerName: 'Priya',
        ticketId: 'OSP-1001',
        employeeName: 'Field Employee',
      );

      expect(result.success, isTrue);
      expect(result.messageId, isNotEmpty);
    });

    test('sendTemplate fails when phone empty', () async {
      final result = await service.sendTemplate(
        templateId: WhatsAppTemplateId.bookingConfirmation,
        toPhone: '   ',
        variables: const {
          'customerName': 'Sam',
          'bookingRef': 'B1',
          'startTime': '10:00',
          'endTime': '12:00',
          'amount': '200',
        },
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('phone number'));
    });
  });
}
