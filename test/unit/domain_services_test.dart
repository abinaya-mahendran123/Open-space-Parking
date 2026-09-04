import 'package:flutter_test/flutter_test.dart';
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
        municipalityCertificatePath: 'https://cdn.example.com/municipality.pdf',
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
        municipalityCertificatePath: 'e',
      );

      final restored = LandOwnerDocuments.fromJson(docs.toJson());
      expect(restored, equals(docs));
    });
  });
}
