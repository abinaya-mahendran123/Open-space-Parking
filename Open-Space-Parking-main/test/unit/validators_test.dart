import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns error when empty', () {
        expect(Validators.email(null), 'Email is required');
        expect(Validators.email(''), 'Email is required');
        expect(Validators.email('   '), 'Email is required');
      });

      test('returns error for invalid format', () {
        expect(Validators.email('not-an-email'), 'Enter a valid email address');
        expect(Validators.email('missing@domain'), 'Enter a valid email address');
      });

      test('returns null for valid email', () {
        expect(Validators.email('user@example.com'), isNull);
        expect(Validators.email('  user@test.co  '), isNull);
      });
    });

    group('minLength', () {
      test('returns error when too short', () {
        expect(Validators.minLength('abc', 8), isNotNull);
        expect(Validators.minLength(null, 8), isNotNull);
      });

      test('returns null when long enough', () {
        expect(Validators.minLength('12345678', 8), isNull);
      });
    });

    group('requiredField', () {
      test('returns error when empty', () {
        expect(Validators.requiredField(null), isNotNull);
        expect(Validators.requiredField('  '), isNotNull);
      });

      test('returns null when present', () {
        expect(Validators.requiredField('value'), isNull);
      });
    });
  });
}
