import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/whatsapp/data/templates/whatsapp_templates.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_documents.dart';

void main() {
  group('LandOwnerDocuments', () {
    test('isComplete is false when any document missing', () {
      const docs = LandOwnerDocuments(
        governmentIdPath: 'https://cdn.example.com/id.pdf',
        propertyDocumentPath: 'https://cdn.example.com/prop.pdf',
      );

      expect(docs.isComplete, isFalse);
    });

    test('isComplete is true when all URLs present', () {
      const docs = LandOwnerDocuments(
        governmentIdPath: 'https://cdn.example.com/id.pdf',
        propertyDocumentPath: 'https://cdn.example.com/prop.pdf',
        pattaPath: 'https://cdn.example.com/patta.pdf',
        propertyTaxPath: 'https://cdn.example.com/tax.pdf',
      );

      expect(docs.isComplete, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const docs = LandOwnerDocuments(governmentIdPath: 'url-a');
      final updated = docs.copyWith(pattaPath: 'url-b');

      expect(updated.governmentIdPath, 'url-a');
      expect(updated.pattaPath, 'url-b');
    });

    test('copyWith clears a document path when set to null', () {
      const docs = LandOwnerDocuments(
        governmentIdPath: 'url-a',
        propertyDocumentPath: 'url-b',
      );

      final updated = docs.copyWith(governmentIdPath: null);

      expect(updated.governmentIdPath, isNull);
      expect(updated.propertyDocumentPath, 'url-b');
    });

    test('toJson and fromJson round-trip', () {
      const docs = LandOwnerDocuments(
        governmentIdPath: 'a',
        propertyDocumentPath: 'b',
        pattaPath: 'c',
        propertyTaxPath: 'd',
      );

      final restored = LandOwnerDocuments.fromJson(docs.toJson());
      expect(restored, equals(docs));
    });
  });

  group('WhatsAppTemplates', () {
    test('employeeAssignment renders variables', () {
      final message = WhatsAppTemplates.employeeAssignment.render({
        'employeeName': 'Alex',
        'ticketId': 'OSP-001',
        'location': 'Chennai',
      });

      expect(message, contains('Alex'));
      expect(message, contains('OSP-001'));
      expect(message, contains('Chennai'));
      expect(message, isNot(contains('{{')));
    });

    test('ownerAssignment renders variables', () {
      final message = WhatsAppTemplates.ownerAssignment.render({
        'ownerName': 'Priya',
        'ticketId': 'OSP-002',
        'employeeName': 'Field Team',
      });

      expect(message, contains('Priya'));
      expect(message, contains('Field Team'));
    });

    test('resolve returns template for each id', () {
      for (final id in WhatsAppTemplateId.values) {
        final template = WhatsAppTemplates.resolve(id);
        expect(template.id, id);
        expect(template.body, isNotEmpty);
      }
    });

    test('all exposes every template', () {
      expect(WhatsAppTemplates.all.length, WhatsAppTemplateId.values.length);
    });
  });
}
